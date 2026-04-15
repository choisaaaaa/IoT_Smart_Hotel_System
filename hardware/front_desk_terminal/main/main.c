#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_system.h"
#include "nvs_flash.h"
#include "sdkconfig.h"
#include "cJSON.h"
#ifndef CONFIG_FRONT_DESK_NET_TEST_MODE
#define CONFIG_FRONT_DESK_NET_TEST_MODE 1
#endif
#if CONFIG_FRONT_DESK_NET_TEST_MODE
#include "esp_timer.h"
#endif

#include "hal_interactive.h"
#include "service_mqtt.h"
#include "service_network.h"
#include "driver_rc522.h"
#include "global_config.h"

static const char *TAG = "FRONT_DESK_MAIN";
static char device_id[32] = "front_desk_01"; // 规范命名 (6.1.1)
static char mqtt_broker_uri[128] = GLOBAL_MQTT_BROKER_URI;
static const TickType_t FRONT_HEARTBEAT_TASK_PERIOD = pdMS_TO_TICKS(60000);
static const TickType_t FRONT_BUTTON_TASK_PERIOD = pdMS_TO_TICKS(50);
static volatile bool s_network_ready = false;
static char target_room_id[16] = "301";
static uint32_t s_command_seq = 1000;
static uint32_t s_call_seq = 1;
static const uint8_t k_default_card_key[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
static char s_last_card_room_id[16] = "";

static void copy_str_safe(char *dst, size_t dst_size, const char *src) {
    if (dst == NULL || dst_size == 0) return;
    if (src == NULL) {
        dst[0] = '\0';
        return;
    }
    strncpy(dst, src, dst_size - 1);
    dst[dst_size - 1] = '\0';
}

static void load_nvs_string_with_fallback(const char *key, char *out, size_t out_size, const char *fallback) {
    if (service_network_read_nvs_string(key, out, out_size) != ESP_OK) {
        copy_str_safe(out, out_size, fallback);
    } else {
        out[out_size - 1] = '\0';
    }
}

static void publish_front_status_payload(cJSON *root) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/front_desk/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    free(json_str);
}

static void publish_front_event(const char *event_type, const char *detail) {
    if (!s_network_ready) {
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "front_desk");
    cJSON_AddStringToObject(root, "event_type", event_type);
    cJSON_AddStringToObject(root, "detail", detail);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(GLOBAL_TOPIC_SECURITY_EVENT, json_str);
    free(json_str);
    cJSON_Delete(root);
}

static void publish_room_command(const char *room_id, const char *command_type) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    char room_device_id[32];
    char timestamp[32];
    snprintf(room_device_id, sizeof(room_device_id), "room_%s", room_id);
    snprintf(topic, sizeof(topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, room_device_id);
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddNumberToObject(root, "command_id", (double)(++s_command_seq));
    cJSON_AddStringToObject(root, "device_id", room_device_id);
    cJSON_AddStringToObject(root, "command_type", command_type);
    cJSON_AddStringToObject(root, "created_by", device_id);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    // 语音控制命令在客房端要求携带会话参数，先在前台端预组包，联调时再与后端统一 call_id 生成规则。
    if (strcmp(command_type, "incoming_call") == 0) {
        char call_id[64];
        snprintf(call_id, sizeof(call_id), "call_%s_%lu", device_id, (unsigned long)(s_call_seq++));
        cJSON_AddStringToObject(root, "call_id", call_id);
        cJSON_AddStringToObject(root, "caller_id", device_id);
    } else if (strcmp(command_type, "hangup_call") == 0) {
        // 为保持命令结构一致，挂断命令也附带 call_id 占位，便于后续联调校准。
        char call_id[64];
        snprintf(call_id, sizeof(call_id), "call_%s_latest", device_id);
        cJSON_AddStringToObject(root, "call_id", call_id);
    }

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    free(json_str);
    cJSON_Delete(root);
}

static void publish_front_command_result(int cmd_id, const char *cmd_type, bool ok, const char *result_msg) {
    if (!s_network_ready) {
        return;
    }
    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *reply = cJSON_CreateObject();
    cJSON_AddStringToObject(reply, "device_id", device_id);
    cJSON_AddNumberToObject(reply, "command_id", cmd_id);
    cJSON_AddStringToObject(reply, "command_type", cmd_type);
    cJSON_AddStringToObject(reply, "status", ok ? "success" : "failed");
    cJSON_AddStringToObject(reply, "result", result_msg);
    cJSON_AddStringToObject(reply, "timestamp", timestamp);

    char *reply_str = cJSON_PrintUnformatted(reply);
    service_mqtt_publish(GLOBAL_TOPIC_DEVICE_COMMAND_RESULT, reply_str);
    free(reply_str);
    cJSON_Delete(reply);
}

static bool parse_room_id_from_card_payload(const char *payload, char *out_room_id, size_t out_size) {
    const char prefix[] = "ROOM:";
    if (payload == NULL || out_room_id == NULL || out_size == 0) {
        return false;
    }
    if (strncmp(payload, prefix, strlen(prefix)) != 0) {
        return false;
    }
    copy_str_safe(out_room_id, out_size, payload + strlen(prefix));
    return (out_room_id[0] != '\0');
}

static bool handle_front_card_command(const char *cmd_type, cJSON *root, const char **out_msg) {
    cJSON *command_value = cJSON_GetObjectItem(root, "command_value");
    if (strcmp(cmd_type, "issue_card") == 0) {
        char payload[32] = {0};
        const char *room_id = target_room_id;
        if (cJSON_IsObject(command_value)) {
            cJSON *room_item = cJSON_GetObjectItem(command_value, "room_id");
            if (cJSON_IsString(room_item)) {
                room_id = room_item->valuestring;
            }
        }

        snprintf(payload, sizeof(payload), "ROOM:%s", room_id);
        esp_err_t err = driver_rc522_write_sector(1, k_default_card_key, (const uint8_t *)payload);
        if (err != ESP_OK) {
            *out_msg = "开卡失败";
            return false;
        }
        // 预开发模式：写卡成功后自动放置一张“当前卡”，方便后续刷卡验卡测试
        driver_rc522_mock_present_card((const uint8_t *)payload, (uint16_t)strlen(payload));
        *out_msg = "开卡成功";
        return true;
    }

    if (strcmp(cmd_type, "verify_card") == 0 || strcmp(cmd_type, "swipe_card") == 0) {
        uint8_t sector_data[16] = {0};
        esp_err_t err = driver_rc522_read_sector(1, k_default_card_key, sector_data);
        if (err != ESP_OK) {
            *out_msg = "未检测到有效房卡";
            return false;
        }

        char room_id[16] = {0};
        if (parse_room_id_from_card_payload((const char *)sector_data, room_id, sizeof(room_id))) {
            copy_str_safe(s_last_card_room_id, sizeof(s_last_card_room_id), room_id);
            *out_msg = "刷卡通过";
            return true;
        }
        *out_msg = "刷卡失败";
        return false;
    }

    return false;
}

static void front_desk_command_callback(const char *topic, const char *data, int data_len) {
    (void)topic;
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        return;
    }

    cJSON *cmd_id_item = cJSON_GetObjectItem(root, "command_id");
    cJSON *cmd_type_item = cJSON_GetObjectItem(root, "command_type");
    if (!cJSON_IsNumber(cmd_id_item) || !cJSON_IsString(cmd_type_item)) {
        cJSON_Delete(root);
        return;
    }

    const char *result_msg = "前台未识别指令";
    const char *cmd_type = cmd_type_item->valuestring;
    bool ok = handle_front_card_command(cmd_type, root, &result_msg);
    publish_front_command_result(cmd_id_item->valueint, cmd_type_item->valuestring, ok, result_msg);

    if (ok && (strcmp(cmd_type, "verify_card") == 0 || strcmp(cmd_type, "swipe_card") == 0) && s_last_card_room_id[0] != '\0') {
        publish_front_event("card_verified", "刷卡验证通过，已自动下发开门指令");
        publish_room_command(s_last_card_room_id, "door_unlock");
        ESP_LOGI(TAG, "刷卡通过，已触发房间开锁: room=%s", s_last_card_room_id);
    }

    if (ok) {
        hal_interactive_beep(1, 90);
    } else {
        hal_interactive_beep(2, 90);
    }
    cJSON_Delete(root);
}

static void front_command_result_callback(const char *topic, const char *data, int data_len) {
    (void)topic;
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        return;
    }

    cJSON *device_item = cJSON_GetObjectItem(root, "device_id");
    cJSON *cmd_item = cJSON_GetObjectItem(root, "command_type");
    cJSON *status_item = cJSON_GetObjectItem(root, "status");

    if (cJSON_IsString(device_item) && cJSON_IsString(cmd_item) && cJSON_IsString(status_item)) {
        ESP_LOGI(TAG, "回执: dev=%s cmd=%s status=%s",
                 device_item->valuestring, cmd_item->valuestring, status_item->valuestring);
    }
    cJSON_Delete(root);
}

// --- 辅助组包函数 ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "front_desk");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddStringToObject(root, "firmware_version", "v1.1.0");
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    publish_front_status_payload(root);
    cJSON_Delete(root);
}

// 发布设备心跳 (规范 6.1.2)
void publish_device_heartbeat() {
    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddNumberToObject(root, "battery_level", 100);
    cJSON_AddNumberToObject(root, "signal_strength", -50);
    cJSON_AddNumberToObject(root, "uptime", xTaskGetTickCount() * portTICK_PERIOD_MS / 1000);
    cJSON_AddNumberToObject(root, "memory_usage", 100 - (esp_get_free_heap_size() * 100 / 327680)); // 估算
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    publish_front_status_payload(root);
    cJSON_Delete(root);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        s_network_ready = true;
        ESP_LOGI(TAG, "网络已连接，IP: %s", ip_address);
        
        // 启动 MQTT
        service_mqtt_start(mqtt_broker_uri, device_id);
        service_mqtt_subscribe(GLOBAL_TOPIC_DEVICE_COMMAND_RESULT, front_command_result_callback);
        char sub_topic[128];
        snprintf(sub_topic, sizeof(sub_topic), "%s/front_desk/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, device_id);
        service_mqtt_subscribe(sub_topic, front_desk_command_callback);
        
        // 延迟一小段以确保 MQTT 连接建立
        vTaskDelay(pdMS_TO_TICKS(1000));
        
        // 发布规范的上线状态
        publish_device_online_status();
        
        // 声光提示：蓝灯常亮，短鸣2声表示上线成功
        hal_interactive_set_led_color(0, 0, 0, 255); 
        hal_interactive_beep(2, 100);
    } else {
        s_network_ready = false;
        ESP_LOGW(TAG, "网络已断开，前台进入离线降级模式");
    }
}

// 心跳任务：只负责周期心跳上报
void task_front_heartbeat(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        vTaskDelay(FRONT_HEARTBEAT_TASK_PERIOD); // 每分钟发一次心跳
        if (!s_network_ready) {
            continue;
        }
        publish_device_heartbeat();
    }
}

// 按键事件任务：前台按钮触发事件与下行控制
void task_front_button_events(void *pvParameters) {
    (void)pvParameters;
    bool prev_clear_pressed = false;
    bool prev_broadcast_pressed = false;

    while (1) {
        bool clear_pressed = hal_interactive_is_button_pressed(BTN_FRONT_CLEAR);
        bool broadcast_pressed = hal_interactive_is_button_pressed(BTN_FRONT_BROADCAST);

        if (clear_pressed && !prev_clear_pressed) {
            publish_front_event("front_clear_pressed", "前台消音/解除按钮触发");
            publish_room_command(target_room_id, "hangup_call");
            hal_interactive_beep(1, 80);
        }

        if (broadcast_pressed && !prev_broadcast_pressed) {
            publish_front_event("front_broadcast_pressed", "前台广播按钮触发");
            publish_room_command(target_room_id, "incoming_call");
            hal_interactive_beep(2, 80);
        }

        prev_clear_pressed = clear_pressed;
        prev_broadcast_pressed = broadcast_pressed;
        vTaskDelay(FRONT_BUTTON_TASK_PERIOD);
    }
}

#if CONFIG_FRONT_DESK_NET_TEST_MODE

static void net_test_mqtt_cb(const char *topic, const char *data, int data_len)
{
    ESP_LOGI(TAG, "[NET-TEST] RX topic=%s len=%d", topic, data_len);
    if (data != NULL && data_len > 0) {
        size_t n = (size_t)data_len < 255u ? (size_t)data_len : 255u;
        char buf[256];
        memcpy(buf, data, n);
        buf[n] = '\0';
        ESP_LOGI(TAG, "[NET-TEST] payload: %s", buf);
    }
}

static void net_test_on_network(bool connected, const char *ip_address)
{
    if (connected) {
        ESP_LOGI(TAG, "[NET-TEST] WiFi OK, IP=%s", ip_address ? ip_address : "?");
        esp_err_t err = service_mqtt_start(mqtt_broker_uri, device_id);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "[NET-TEST] MQTT start failed: %s", esp_err_to_name(err));
            return;
        }
        const char *topic = "hotel/net_test/broadcast";
        err = service_mqtt_subscribe(topic, net_test_mqtt_cb);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "[NET-TEST] subscribe failed: %s", esp_err_to_name(err));
        }
        vTaskDelay(pdMS_TO_TICKS(800));
        char pay[160];
        snprintf(pay, sizeof(pay), "{\"from\":\"%s\",\"msg\":\"online\"}", device_id);
        service_mqtt_publish(topic, pay);
    } else {
        ESP_LOGW(TAG, "[NET-TEST] WiFi disconnected");
    }
}

static void net_test_heartbeat_task(void *pvParameters)
{
    (void)pvParameters;
    const char *topic = "hotel/net_test/broadcast";
    char pay[192];
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(15000));
        int64_t us = esp_timer_get_time();
        snprintf(pay, sizeof(pay), "{\"from\":\"%s\",\"uptime_s\":%lld}",
                 device_id, (long long)(us / 1000000));
        service_mqtt_publish(topic, pay);
        ESP_LOGI(TAG, "[NET-TEST] heartbeat sent");
    }
}

#endif /* CONFIG_FRONT_DESK_NET_TEST_MODE */

// 主入口
void app_main(void) {
#if CONFIG_FRONT_DESK_NET_TEST_MODE
    ESP_LOGW(TAG, "========== NET TEST MODE（无外设：仅配网 + MQTT）==========");
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    char front_id[16] = {0};
    load_nvs_string_with_fallback("FrontDesk_ID", front_id, sizeof(front_id), "01");
    snprintf(device_id, sizeof(device_id), "front_desk_%s", front_id);
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri),
                                  GLOBAL_MQTT_BROKER_URI);

    ESP_LOGI(TAG, "[NET-TEST] client_id=%s", device_id);
    ESP_LOGI(TAG, "[NET-TEST] broker=%s", mqtt_broker_uri);
    ESP_LOGI(TAG, "[NET-TEST] topic: hotel/net_test/broadcast");

    ESP_ERROR_CHECK(service_network_provisioning_start(net_test_on_network));
    xTaskCreate(net_test_heartbeat_task, "net_hb", 4096, NULL, 5, NULL);

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(60000));
        ESP_LOGI(TAG, "[NET-TEST] main alive");
    }
#else
    ESP_LOGI(TAG, "========== 🛎️ 智慧前台管理端 启动 ==========");

    // 1. 初始化系统非易失性存储 (NVS)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    
    // 2. 从 NVS 读取配置（NVS 优先，默认值兜底）
    char front_id[16] = {0};
    load_nvs_string_with_fallback("FrontDesk_ID", front_id, sizeof(front_id), "01");
    snprintf(device_id, sizeof(device_id), "front_desk_%s", front_id);
    load_nvs_string_with_fallback("Room_ID", target_room_id, sizeof(target_room_id), "301");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri), GLOBAL_MQTT_BROKER_URI);

    // 3. 初始化底层硬件驱动
    driver_rc522_init();
    hal_interactive_init();
    
    // 4. 启动网络与配网服务
    service_network_provisioning_start(on_network_status_changed);

    // 5. 创建任务；main 仅保留守护
    xTaskCreate(task_front_heartbeat, "front_heartbeat_task", 4096, NULL, 5, NULL);
    xTaskCreate(task_front_button_events, "front_button_task", 3072, NULL, 4, NULL);
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(60000));
    }
#endif /* CONFIG_FRONT_DESK_NET_TEST_MODE */
}
