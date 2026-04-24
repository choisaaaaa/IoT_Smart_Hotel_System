#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "nvs_flash.h"
#include "sdkconfig.h"
#include "cJSON.h"
#ifndef CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE
#define CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE 0
#endif
#if CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE
#include "esp_timer.h"
#endif

// 引入所需的底层硬件抽象组件库
#include "service_mqtt.h"
#include "hal_actuators.h"
#include "hal_sensors.h"
#include "hal_interactive.h"
#include "service_network.h"
#include "global_config.h"
#include "service_auth.h"

static const char *TAG = "FLOOR_CONTROLLER_MAIN";
#define FLOOR_FIRMWARE_VERSION "v1.1.0"
static char current_floor_id[16] = "UNKNOWN";
static char device_id[32] = "floor_UNKNOWN";
static char mqtt_broker_uri[128] = GLOBAL_MQTT_BROKER_URI;
static const TickType_t FLOOR_SENSOR_TASK_PERIOD = pdMS_TO_TICKS(30000);
static const TickType_t FLOOR_BUTTON_TASK_PERIOD = pdMS_TO_TICKS(80);
static const TickType_t FLOOR_HEALTH_TASK_PERIOD = pdMS_TO_TICKS(600000);
static volatile bool s_network_ready = false;
static bool s_corridor_light_on = false;
static uint32_t s_reconnect_count = 0;

/** 疑似火灾：DHT11 或 走廊 NTC 任一超温 + MQ2 烟雾 ADC 超阈（现场请标定 MQ2 基线） */
static const float k_fire_suspect_temp_c = 40.0f;
static const uint16_t k_fire_suspect_smoke_adc = 400;
static bool s_fire_suspect_episode_reported = false;

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
    if (service_network_read_nvs_string(key, out, out_size) != ESP_OK || out[0] == '\0') {
        copy_str_safe(out, out_size, fallback);
    } else {
        out[out_size - 1] = '\0';
    }
}

static cJSON *parse_command_value_object(cJSON *root, cJSON **out_owned_json)
{
    if (out_owned_json != NULL) {
        *out_owned_json = NULL;
    }
    if (root == NULL) {
        return NULL;
    }

    cJSON *command_value = cJSON_GetObjectItem(root, "command_value");
    if (cJSON_IsObject(command_value)) {
        return command_value;
    }
    if (!cJSON_IsString(command_value) || command_value->valuestring == NULL) {
        return NULL;
    }

    cJSON *parsed = cJSON_Parse(command_value->valuestring);
    if (!cJSON_IsObject(parsed)) {
        if (parsed != NULL) {
            cJSON_Delete(parsed);
        }
        ESP_LOGW(TAG, "command_value 不是合法 JSON 对象字符串");
        return NULL;
    }
    if (out_owned_json != NULL) {
        *out_owned_json = parsed;
    }
    return parsed;
}

static void publish_command_result(int cmd_id, const char *cmd_type, bool exec_success, const char *result_msg) {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过楼控指令回执: %s", cmd_type);
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *reply = cJSON_CreateObject();
    cJSON_AddStringToObject(reply, "device_id", device_id);
    cJSON_AddNumberToObject(reply, "command_id", cmd_id);
    cJSON_AddStringToObject(reply, "command_type", cmd_type);
    cJSON_AddStringToObject(reply, "status", exec_success ? "success" : "failed");
    cJSON_AddStringToObject(reply, "result", result_msg);
    cJSON_AddStringToObject(reply, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(reply, signature) == ESP_OK) {
        cJSON_AddStringToObject(reply, "signature", signature);
    }
    char *reply_str = cJSON_PrintUnformatted(reply);
    service_mqtt_publish(GLOBAL_TOPIC_DEVICE_COMMAND_RESULT, reply_str);
    free(reply_str);
    cJSON_Delete(reply);
}

static void publish_floor_runtime_status(void) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/floor/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "floor");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddBoolToObject(root, "corridor_light_on", s_corridor_light_on);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    free(json_str);
    cJSON_Delete(root);
}

static void publish_floor_event(const char *event_type, const char *detail, const char *level) {
    if (!s_network_ready) {
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "event_type", event_type);
    cJSON_AddStringToObject(root, "detail", detail);
    cJSON_AddStringToObject(root, "level", (level != NULL && level[0] != '\0') ? level : "info");
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(GLOBAL_TOPIC_SECURITY_EVENT, json_str);
    free(json_str);
    cJSON_Delete(root);
}

static void publish_health_report(void) {
    if (!s_network_ready) {
        return;
    }

    wifi_ap_record_t ap_info = {0};
    int rssi = 0;
    if (esp_wifi_sta_get_ap_info(&ap_info) == ESP_OK) {
        rssi = ap_info.rssi;
    }

    char timestamp[32];
    char topic[128];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));
    snprintf(topic, sizeof(topic), "hotel/health/floor/%s", device_id);

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "floor");
    cJSON_AddStringToObject(root, "firmware_version", FLOOR_FIRMWARE_VERSION);
    cJSON_AddNumberToObject(root, "uptime_sec", xTaskGetTickCount() * portTICK_PERIOD_MS / 1000);
    cJSON_AddNumberToObject(root, "free_heap_bytes", (double)esp_get_free_heap_size());
    cJSON_AddNumberToObject(root, "rssi", rssi);
    cJSON_AddNumberToObject(root, "reconnect_counts", (double)s_reconnect_count);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    ESP_LOGI(TAG, "健康上报已发送: topic=%s rssi=%d reconnect=%lu",
             topic, rssi, (unsigned long)s_reconnect_count);
    free(json_str);
    cJSON_Delete(root);
}

static bool execute_floor_command(const char *cmd_type, const char **out_result_msg) {
    if (strcmp(cmd_type, "light_on") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
        if (err == ESP_OK) {
            s_corridor_light_on = true;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "走廊灯控失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "light_off") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
        if (err == ESP_OK) {
            s_corridor_light_on = false;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "走廊灯控失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "broadcast_alarm") == 0 || strcmp(cmd_type, "broadcast_start") == 0) {
        (void)hal_interactive_beep(4, 120);
        *out_result_msg = "广播警报已触发（蜂鸣器鸣叫）";
        return true;
    }

    if (strcmp(cmd_type, "broadcast_stop") == 0) {
        *out_result_msg = "广播警报停止（无需持续动作）";
        return true;
    }

    if (strcmp(cmd_type, "floor_reset") == 0) {
        (void)hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
        vTaskDelay(pdMS_TO_TICKS(120));
        (void)hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
        s_corridor_light_on = false;
        (void)hal_interactive_beep(3, 90);
        *out_result_msg = "楼控复位完成（继电器弹一次+蜂鸣三声）";
        return true;
    }

    *out_result_msg = "未识别的楼控指令";
    return false;
}

static void run_floor_local_policy(const sensor_data_t *env_data) {
    if (env_data == NULL) {
        return;
    }

    const bool hot_dht = env_data->temperature >= k_fire_suspect_temp_c;
    const bool hot_ntc = env_data->ntc_valid && env_data->ntc_temp_c >= k_fire_suspect_temp_c;
    const bool hot = hot_dht || hot_ntc;
    const bool smoky = env_data->air_quality_adc >= k_fire_suspect_smoke_adc;

    if (hot && smoky) {
        if (!s_fire_suspect_episode_reported && s_network_ready) {
            char detail[192];
            snprintf(detail, sizeof(detail),
                     "DHT=%.1f℃ NTC=%.1f℃(valid=%d) 烟雾ADC=%u 同时超阈，疑似火灾(需人工复核)",
                     (double)env_data->temperature,
                     (double)env_data->ntc_temp_c,
                     env_data->ntc_valid ? 1 : 0,
                     (unsigned)env_data->air_quality_adc);
            publish_floor_event("floor_fire_suspected", detail, "warning");
            ESP_LOGW(TAG, "疑似火灾告警已上报: (DHT或NTC)>=%.0f℃ 且 MQ2ADC>=%u",
                     (double)k_fire_suspect_temp_c, (unsigned)k_fire_suspect_smoke_adc);
            s_fire_suspect_episode_reported = true;
        }
    } else {
        s_fire_suspect_episode_reported = false;
    }
}

// --- 辅助组包函数 ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过楼控上线状态上报");
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/floor/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "floor");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddStringToObject(root, "firmware_version", FLOOR_FIRMWARE_VERSION);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    
    free(json_str);
    cJSON_Delete(root);
}

// 辅助函数：上报单项传感器数据 (规范 4.2.2)
void publish_sensor_data(const char *sensor_type, double value, const char *unit) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/%s/%s", GLOBAL_TOPIC_DEVICE_DATA_PREFIX, sensor_type, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "sensor_type", sensor_type);
    cJSON_AddNumberToObject(root, "value", value);
    cJSON_AddStringToObject(root, "unit", unit);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);

    free(json_str);
    cJSON_Delete(root);
}

// MQTT 消息接收回调 (群控解析)
void floor_mqtt_callback(const char *topic, const char *data, int data_len) {
    (void)topic;
    ESP_LOGI(TAG, "==== 收到云端 MQTT 楼控群控指令 ====");
    
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        ESP_LOGW(TAG, "指令 JSON 解析失败");
        return;
    }

    cJSON *cmd_id_item = cJSON_GetObjectItem(root, "command_id");
    cJSON *device_id_item = cJSON_GetObjectItem(root, "device_id");
    cJSON *cmd_type_item = cJSON_GetObjectItem(root, "command_type");
    cJSON *owned_command_value = NULL;
    parse_command_value_object(root, &owned_command_value);

    if (!cJSON_IsNumber(cmd_id_item) || !cJSON_IsString(device_id_item) || !cJSON_IsString(cmd_type_item)) {
        ESP_LOGW(TAG, "指令字段缺失: 需要 command_id/device_id/command_type");
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        cJSON_Delete(root);
        return;
    }

    if (strcmp(device_id_item->valuestring, device_id) != 0) {
        ESP_LOGW(TAG, "忽略非本机指令: target=%s self=%s", device_id_item->valuestring, device_id);
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        cJSON_Delete(root);
        return;
    }

    if (cJSON_IsNumber(cmd_id_item) && cJSON_IsString(cmd_type_item)) {
        int cmd_id = cmd_id_item->valueint;
        const char *cmd_type = cmd_type_item->valuestring;
        const char *result_msg = "未识别的楼控指令";
        bool exec_success = execute_floor_command(cmd_type, &result_msg);
        publish_command_result(cmd_id, cmd_type, exec_success, result_msg);
        publish_floor_runtime_status();
    }
    if (owned_command_value != NULL) {
        cJSON_Delete(owned_command_value);
    }
    cJSON_Delete(root);
}

static void auth_and_mqtt_task(void *pvParameters) {
    (void)pvParameters;
    ESP_LOGI(TAG, "开始设备注册/鉴权流程...");

    char http_api_base[128];
    load_nvs_string_with_fallback("HTTP_API_BASE", http_api_base, sizeof(http_api_base), GLOBAL_HTTP_API_BASE_DEFAULT);
    char register_url[192];
    esp_err_t url_err = service_auth_resolve_register_url(
        mqtt_broker_uri,
        (http_api_base[0] != '\0') ? http_api_base : NULL,
        register_url,
        sizeof(register_url));
    if (url_err != ESP_OK) {
        ESP_LOGE(TAG, "解析注册 URL 失败: %s，使用云端默认", esp_err_to_name(url_err));
        snprintf(register_url, sizeof(register_url), "http://8.134.166.69:9000/api/v1/devices/register");
    }
    ESP_LOGI(TAG, "设备注册 URL: %s (broker=%s)", register_url, mqtt_broker_uri);

    service_auth_perform_registration_blocking(
        register_url,
        3,
        device_id,
        "floor",
        "智慧走廊楼控",
        FLOOR_FIRMWARE_VERSION
    );

    ESP_LOGI(TAG, "鉴权通过，启动 MQTT 服务...");
    if (service_network_wait_sntp_sync(20000) != ESP_OK) {
        ESP_LOGW(TAG, "SNTP 未在 20s 内就绪，仍将启动 MQTT（请确认路由器未拦截 NTP）");
    }
    esp_err_t err = service_mqtt_start(mqtt_broker_uri, device_id);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "MQTT 启动失败: %s", esp_err_to_name(err));
        vTaskDelete(NULL);
        return;
    }

    char sub_topic[128];
    snprintf(sub_topic, sizeof(sub_topic), "%s/floor/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, device_id);
    err = service_mqtt_subscribe(sub_topic, floor_mqtt_callback);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "订阅楼控指令失败: %s", esp_err_to_name(err));
    }

    vTaskDelay(pdMS_TO_TICKS(1000));
    publish_device_online_status();
    publish_health_report();

    vTaskDelete(NULL);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        s_network_ready = true;
        ESP_LOGI(TAG, "网络已连接，IP: %s", ip_address);
        static bool s_auth_task_started = false;
        if (!s_auth_task_started) {
            s_auth_task_started = true;
            xTaskCreate(auth_and_mqtt_task, "auth_and_mqtt", 8192, NULL, 4, NULL);
        }
    } else {
        s_network_ready = false;
        s_reconnect_count++;
        ESP_LOGW(TAG, "网络已断开，楼控进入离线降级模式");
    }
}

// 环境采样与上报任务：只负责采样+上报
void task_floor_sensor_report(void *pvParameters) {
    (void)pvParameters;
    sensor_data_t env_data;

    while (1) {
        vTaskDelay(FLOOR_SENSOR_TASK_PERIOD); // 每半分钟发一次走廊环境数据
        hal_sensors_read_all(&env_data);
        run_floor_local_policy(&env_data);

        if (!s_network_ready) {
            continue;
        }

        /*
         * 楼控实际装配的传感器（以硬件清单为准，2026-04）：
         *   - MQ2 烟雾
         *   - LDR 光敏电阻
         *   - DHT11 温湿度
         * 只上报这三类。NTC / RD03 / 雨棚（canopy/雨感）均不再装配。
         */
        if (env_data.dht_valid) {
            publish_sensor_data("temperature", env_data.temperature, "℃");
            publish_sensor_data("humidity", env_data.humidity, "%");
        }
        if (env_data.mq2_valid) {
            publish_sensor_data("smoke", env_data.air_quality_adc, "adc");
        }
        if (env_data.ldr_valid) {
            publish_sensor_data("light", env_data.light_adc, "adc");
        }
    }
}

void task_floor_button_events(void *pvParameters) {
    (void)pvParameters;
    bool prev_alarm_pressed = false;

    while (1) {
        bool alarm_pressed = hal_interactive_is_button_pressed(BTN_FLOOR_ALARM);
        if (alarm_pressed && !prev_alarm_pressed) {
            ESP_LOGI(TAG, "楼控按键触发: 报警键");
            publish_floor_event("floor_alarm_pressed", "楼道报警按钮触发", "alarm");
            hal_interactive_beep(2, 100);
        }
        prev_alarm_pressed = alarm_pressed;
        vTaskDelay(FLOOR_BUTTON_TASK_PERIOD);
    }
}

void task_floor_health_report(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        vTaskDelay(FLOOR_HEALTH_TASK_PERIOD);
        publish_health_report();
    }
}

#if CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE

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

#endif /* CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE */

// 主入口
void app_main(void) {
#if CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE
    ESP_LOGW(TAG, "========== NET TEST MODE（无外设：仅配网 + MQTT）==========");
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    load_nvs_string_with_fallback("Floor_ID", current_floor_id, sizeof(current_floor_id), "03");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri),
                                  GLOBAL_MQTT_BROKER_URI);
    snprintf(device_id, sizeof(device_id), "floor_%s", current_floor_id);

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
    ESP_LOGI(TAG, "========== 🏢 智慧走廊楼控端 启动 ==========");

    // 1. 初始化系统非易失性存储 (NVS)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    service_auth_init();

    // 2. 初始化底层硬件驱动
    hal_actuators_init();
    hal_sensors_init();
    hal_interactive_init();

    // 3. 读取并拼接规范的 Client ID
    load_nvs_string_with_fallback("Floor_ID", current_floor_id, sizeof(current_floor_id), "03");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri), GLOBAL_MQTT_BROKER_URI);
    snprintf(device_id, sizeof(device_id), "floor_%s", current_floor_id);
    
    // 4. 启动网络与配网服务
    service_network_provisioning_start(on_network_status_changed);

    // 5. 创建环境采样上报任务；main 仅保留守护
    xTaskCreate(task_floor_sensor_report, "floor_sensor_task", 4096, NULL, 5, NULL);
    xTaskCreate(task_floor_health_report, "floor_health_task", 4096, NULL, 5, NULL);
    xTaskCreate(task_floor_button_events, "floor_button_task", 3072, NULL, 4, NULL);
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(60000));
    }
#endif /* CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE */
}
