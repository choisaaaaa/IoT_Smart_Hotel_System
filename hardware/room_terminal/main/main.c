#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "sdkconfig.h"
#include "cJSON.h"
#if CONFIG_ROOM_TERMINAL_NET_TEST_MODE
#include "esp_timer.h"
#endif

// 引入底层硬件抽象组件库
#include "driver_rc522.h"
#include "service_mqtt.h"
#include "hal_actuators.h"
#include "hal_sensors.h"
#include "hal_interactive.h"
#include "hal_audio.h"
#include "hal_infrared.h"
#include "driver_oled.h"
#include "service_network.h"
#include "global_config.h"

static const char *TAG = "ROOM_TERMINAL_MAIN";
static char current_room_id[16] = "UNKNOWN";
static char device_id[32] = "room_UNKNOWN";
static char mqtt_broker_uri[128] = GLOBAL_MQTT_BROKER_URI;
static bool is_on_call = false;
static char current_call_id[64] = "";
static char remote_id[32] = "";
static volatile bool s_network_ready = false;

typedef enum {
    ROOM_SCENE_WELCOME = 0,
    ROOM_SCENE_READING,
    ROOM_SCENE_NIGHT,
    ROOM_SCENE_SLEEP
} room_scene_mode_t;

typedef struct {
    bool light_on;
    bool air_on;
    bool curtain_open;
    bool door_unlocked;
} room_runtime_state_t;

static room_runtime_state_t s_room_state = {0};
static room_scene_mode_t s_scene_mode = ROOM_SCENE_WELCOME;
static volatile bool s_auto_lock_pending = false;
static TickType_t s_auto_lock_deadline = 0;
static const char *s_last_result_code = NULL;

// 统一任务周期配置，避免散落魔法数字
static const TickType_t SENSOR_TASK_PERIOD = pdMS_TO_TICKS(15000);
static const TickType_t VOICE_TASK_PERIOD = pdMS_TO_TICKS(100);
static const TickType_t BUTTON_TASK_PERIOD = pdMS_TO_TICKS(60);
static const TickType_t AUTO_LOCK_TASK_PERIOD = pdMS_TO_TICKS(200);
static const TickType_t AUTO_LOCK_DELAY = pdMS_TO_TICKS(8000);
#if !CONFIG_ROOM_TERMINAL_NET_TEST_MODE
static const TickType_t MAIN_GUARD_PERIOD = pdMS_TO_TICKS(30000);
#endif

static void copy_str_safe(char *dst, size_t dst_size, const char *src) {
    if (dst == NULL || dst_size == 0) {
        return;
    }
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

static void publish_command_result_ex(int cmd_id, const char *cmd_type, bool exec_success, const char *result_msg, const char *result_code) {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过指令回执上报: %s", cmd_type);
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
    if (result_code != NULL && result_code[0] != '\0') {
        cJSON_AddStringToObject(reply, "result_code", result_code);
    }
    cJSON_AddStringToObject(reply, "timestamp", timestamp);

    char *reply_str = cJSON_PrintUnformatted(reply);
    service_mqtt_publish(GLOBAL_TOPIC_DEVICE_COMMAND_RESULT, reply_str);

    free(reply_str);
    cJSON_Delete(reply);
}

static void publish_command_result(int cmd_id, const char *cmd_type, bool exec_success, const char *result_msg) {
    publish_command_result_ex(cmd_id, cmd_type, exec_success, result_msg, NULL);
}

static void publish_room_runtime_status(void) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "room");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddBoolToObject(root, "light_on", s_room_state.light_on);
    cJSON_AddBoolToObject(root, "air_on", s_room_state.air_on);
    cJSON_AddBoolToObject(root, "curtain_open", s_room_state.curtain_open);
    cJSON_AddBoolToObject(root, "door_unlocked", s_room_state.door_unlocked);
    cJSON_AddBoolToObject(root, "is_on_call", is_on_call);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);

    free(json_str);
    cJSON_Delete(root);
}

static bool validate_command_value_object(cJSON *root) {
    cJSON *command_value = cJSON_GetObjectItem(root, "command_value");
    if (command_value == NULL || cJSON_IsNull(command_value)) {
        return true;
    }
    return cJSON_IsObject(command_value) || cJSON_IsString(command_value);
}

static bool apply_room_scene(room_scene_mode_t mode, const char **out_result_msg) {
    esp_err_t err = ESP_OK;
    bool main_light = false;
    uint8_t led_r = 0;
    uint8_t led_g = 0;
    uint8_t led_b = 0;

    switch (mode) {
        case ROOM_SCENE_WELCOME:
            main_light = true;
            led_r = 255; led_g = 180; led_b = 120;
            *out_result_msg = "已切换到迎宾场景";
            break;
        case ROOM_SCENE_READING:
            main_light = true;
            led_r = 255; led_g = 255; led_b = 255;
            *out_result_msg = "已切换到阅读场景";
            break;
        case ROOM_SCENE_NIGHT:
            main_light = false;
            led_r = 16; led_g = 32; led_b = 96;
            *out_result_msg = "已切换到夜灯场景";
            break;
        case ROOM_SCENE_SLEEP:
            main_light = false;
            led_r = 0; led_g = 0; led_b = 0;
            *out_result_msg = "已切换到睡眠场景";
            break;
        default:
            *out_result_msg = "未知场景";
            return false;
    }

    err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, main_light);
    if (err != ESP_OK) {
        *out_result_msg = "场景切换失败: 主灯控制失败";
        return false;
    }

    err = hal_interactive_set_led_color(0, led_r, led_g, led_b);
    if (err != ESP_OK) {
        *out_result_msg = "场景切换失败: 氛围灯控制失败";
        return false;
    }

    s_room_state.light_on = main_light;
    s_scene_mode = mode;

    return true;
}

static bool execute_room_command(const char *cmd_type, cJSON *root, const char **out_result_msg) {
    if (strcmp(cmd_type, "light_on") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
        if (err == ESP_OK) {
            s_room_state.light_on = true;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "灯光控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "light_off") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
        if (err == ESP_OK) {
            s_room_state.light_on = false;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "灯光控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "air_on") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH2, true);
        if (err == ESP_OK) {
            s_room_state.air_on = true;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "空调控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "air_off") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH2, false);
        if (err == ESP_OK) {
            s_room_state.air_on = false;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "空调控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "curtain_open") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH3, true);
        if (err == ESP_OK) {
            s_room_state.curtain_open = true;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "窗帘控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "curtain_close") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH3, false);
        if (err == ESP_OK) {
            s_room_state.curtain_open = false;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "窗帘控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "door_unlock") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH4, true);
        if (err == ESP_OK) {
            s_room_state.door_unlocked = true;
            s_auto_lock_pending = true;
            s_auto_lock_deadline = xTaskGetTickCount() + AUTO_LOCK_DELAY;
            s_last_result_code = "door_unlock_ok";
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "门锁控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "door_lock") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH4, false);
        if (err == ESP_OK) {
            s_room_state.door_unlocked = false;
            s_auto_lock_pending = false;
            s_last_result_code = "door_lock_manual";
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "门锁控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "incoming_call") == 0) {
        cJSON *call_id = cJSON_GetObjectItem(root, "call_id");
        cJSON *caller_id = cJSON_GetObjectItem(root, "caller_id");
        if (cJSON_IsString(call_id) && cJSON_IsString(caller_id)) {
            copy_str_safe(current_call_id, sizeof(current_call_id), call_id->valuestring);
            copy_str_safe(remote_id, sizeof(remote_id), caller_id->valuestring);
            is_on_call = true;
            *out_result_msg = "通话已建立";
            return true;
        }
        *out_result_msg = "通话参数缺失";
        return false;
    }

    if (strcmp(cmd_type, "hangup_call") == 0) {
        is_on_call = false;
        current_call_id[0] = '\0';
        remote_id[0] = '\0';
        *out_result_msg = "通话已结束";
        return true;
    }

    if (strcmp(cmd_type, "scene_welcome") == 0) {
        return apply_room_scene(ROOM_SCENE_WELCOME, out_result_msg);
    }

    if (strcmp(cmd_type, "scene_reading") == 0) {
        return apply_room_scene(ROOM_SCENE_READING, out_result_msg);
    }

    if (strcmp(cmd_type, "scene_night") == 0) {
        return apply_room_scene(ROOM_SCENE_NIGHT, out_result_msg);
    }

    if (strcmp(cmd_type, "scene_sleep") == 0) {
        return apply_room_scene(ROOM_SCENE_SLEEP, out_result_msg);
    }

    if (strcmp(cmd_type, "scene_next") == 0) {
        room_scene_mode_t next_mode = (room_scene_mode_t)((((int)s_scene_mode) + 1) % 4);
        return apply_room_scene(next_mode, out_result_msg);
    }

    *out_result_msg = "未识别的指令或设备故障";
    return false;
}

// --- 辅助组包函数 (规范化数据上报) ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过上线状态上报");
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "room");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddStringToObject(root, "firmware_version", "v1.1.0");
    cJSON_AddStringToObject(root, "timestamp", timestamp);

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

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);

    free(json_str);
    cJSON_Delete(root);
}

static void publish_security_event(const char *event_type, const char *level) {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过安防事件上报");
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "event_type", event_type);
    
    cJSON *event_data = cJSON_CreateObject();
    cJSON_AddNumberToObject(event_data, "room_id", atoi(current_room_id));
    cJSON_AddItemToObject(root, "event_data", event_data);

    cJSON_AddStringToObject(root, "level", level);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(GLOBAL_TOPIC_SECURITY_EVENT, json_str);

    free(json_str);
    cJSON_Delete(root);
}

// 上报门禁类安全事件 (规范 4.2.5)
void publish_security_door_event() {
    publish_security_event("door_open", "info");
}

// --- 业务回调函数 ---

// MQTT 消息接收回调 (处理云端指令，规范 4.2.3 和 4.2.4)
void hotel_mqtt_callback(const char *topic, const char *data, int data_len) {
    (void)topic;
    ESP_LOGI(TAG, "==== 收到云端 MQTT 指令 ====");
    
    // 解析 JSON
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        ESP_LOGE(TAG, "JSON 解析失败，不符合规范格式");
        return;
    }

    cJSON *cmd_id_item = cJSON_GetObjectItem(root, "command_id");
    cJSON *cmd_type_item = cJSON_GetObjectItem(root, "command_type");

    if (cJSON_IsNumber(cmd_id_item) && cJSON_IsString(cmd_type_item)) {
        int cmd_id = cmd_id_item->valueint;
        const char *cmd_type = cmd_type_item->valuestring;
        const char *result_msg = "未识别的指令或设备故障";

        if (!validate_command_value_object(root)) {
            ESP_LOGW(TAG, "command_value 参数类型非法");
            publish_command_result(cmd_id, cmd_type, false, "command_value 参数非法");
            cJSON_Delete(root);
            return;
        }

        ESP_LOGI(TAG, "执行指令: %s (ID: %d)", cmd_type, cmd_id);

        s_last_result_code = NULL;
        bool exec_success = execute_room_command(cmd_type, root, &result_msg);
        publish_command_result_ex(cmd_id, cmd_type, exec_success, result_msg, s_last_result_code);
        s_last_result_code = NULL;
        publish_room_runtime_status();
        
        // 界面及声音反馈
        driver_oled_show_text_line(2, cmd_type);
        hal_interactive_beep(1, 100);
    } else {
        ESP_LOGW(TAG, "云端指令缺少 command_id 或 command_type 字段");
    }
    cJSON_Delete(root);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        s_network_ready = true;
        char msg[32];
        snprintf(msg, sizeof(msg), "IP:%s", ip_address);
        driver_oled_show_text_line(1, msg);
        
        // 连上网后，使用统一的宏地址启动 MQTT
        service_mqtt_start(mqtt_broker_uri, device_id);
        
        // 订阅房间专属控制指令 (规范 11.4)
        char sub_topic[128];
        snprintf(sub_topic, sizeof(sub_topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, device_id);
        service_mqtt_subscribe(sub_topic, hotel_mqtt_callback);

        // 延迟一小段以确保 MQTT 连接建立后再发送状态 (Mock演示用)
        vTaskDelay(pdMS_TO_TICKS(1000));
        
        // 发布规范的上线状态
        publish_device_online_status();
    } else {
        s_network_ready = false;
        ESP_LOGW(TAG, "网络已断开，进入离线降级模式");
    }
}

// --- 独立业务任务 (FreeRTOS) ---

// 定_时传感器采集任务
void task_sensor_monitor(void *pvParameters) {
    (void)pvParameters;
    ESP_LOGI(TAG, "传感器监控任务启动...");
    sensor_data_t env_data;
    
    while(1) {
        vTaskDelay(SENSOR_TASK_PERIOD); // 每15秒采一次，避免刷屏
        if (!s_network_ready) {
            continue;
        }
        
        // 读取真实的传感器层数据 (在没插真外设时是 Mock 的固定值)
        hal_sensors_read_all(&env_data);
        
        // 将温湿度显示在 OLED 上
        char display_str[32];
        snprintf(display_str, sizeof(display_str), "T:%.1fC H:%.1f%%", env_data.temperature, env_data.humidity);
        driver_oled_show_text_line(3, display_str);
        
        // 分拆 Topic，按照规范格式发送
        publish_sensor_data("temperature", env_data.temperature, "℃");
        publish_sensor_data("humidity", env_data.humidity, "%");
        publish_sensor_data("air_quality_adc", env_data.air_quality_adc, "adc");
        publish_sensor_data("light_adc", env_data.light_adc, "adc");
        publish_sensor_data("human_present", env_data.is_human_present ? 1.0 : 0.0, "bool");
    }
}

// --- 语音通话相关任务 (新) ---

void task_voice_call(void *pvParameters) {
    (void)pvParameters;
    uint8_t audio_buffer[1024];
    size_t read_len = 0;
    
    while(1) {
        if (is_on_call) {
            // 1. 录制一段音频
            if (hal_audio_record_chunk(audio_buffer, sizeof(audio_buffer), &read_len) == ESP_OK) {
                // 2. 通过 MQTT 发送音频数据块 (演示用)
                ESP_LOGD(TAG, "正在通话中，录制并发送音频块: %zu Bytes", read_len);
            }
        }
        vTaskDelay(VOICE_TASK_PERIOD);
    }
}

void task_room_auto_lock(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        if (s_auto_lock_pending) {
            TickType_t now = xTaskGetTickCount();
            if (now >= s_auto_lock_deadline) {
                esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH4, false);
                s_auto_lock_pending = false;
                if (err == ESP_OK) {
                    s_room_state.door_unlocked = false;
                    publish_command_result_ex(0, "door_lock", true, "门锁自动回锁完成", "door_lock_auto");
                    publish_security_event("door_auto_locked", "info");
                    publish_room_runtime_status();
                    ESP_LOGI(TAG, "门锁自动回锁完成");
                } else {
                    ESP_LOGW(TAG, "门锁自动回锁失败: %s", esp_err_to_name(err));
                }
            }
        }
        vTaskDelay(AUTO_LOCK_TASK_PERIOD);
    }
}

void task_room_button_events(void *pvParameters) {
    (void)pvParameters;
    bool prev_scene_pressed = false;
    bool prev_sos_pressed = false;

    while (1) {
        bool scene_pressed = hal_interactive_is_button_pressed(BTN_ROOM_SCENE);
        bool sos_pressed = hal_interactive_is_button_pressed(BTN_ROOM_SOS);

        if (scene_pressed && !prev_scene_pressed) {
            const char *scene_msg = "场景切换";
            room_scene_mode_t next_mode = (room_scene_mode_t)((((int)s_scene_mode) + 1) % 4);
            bool ok = apply_room_scene(next_mode, &scene_msg);
            ESP_LOGI(TAG, "本地场景按键触发: %s (ok=%d)", scene_msg, (int)ok);
            publish_room_runtime_status();
            hal_interactive_beep(ok ? 1 : 2, 80);
        }

        if (sos_pressed && !prev_sos_pressed) {
            publish_security_event("room_sos_pressed", "critical");
            hal_interactive_beep(3, 60);
        }

        prev_scene_pressed = scene_pressed;
        prev_sos_pressed = sos_pressed;
        vTaskDelay(BUTTON_TASK_PERIOD);
    }
}

#if CONFIG_ROOM_TERMINAL_NET_TEST_MODE

/** 多块板互通测试：统一订阅/发布同一 topic，串口可看到彼此 payload */
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

#endif /* CONFIG_ROOM_TERMINAL_NET_TEST_MODE */

// 主入口
void app_main(void)
{
#if CONFIG_ROOM_TERMINAL_NET_TEST_MODE
    ESP_LOGW(TAG, "========== NET TEST MODE（无外设：仅配网 + MQTT）==========");
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    load_nvs_string_with_fallback("Room_ID", current_room_id, sizeof(current_room_id), "301");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri),
                                  GLOBAL_MQTT_BROKER_URI);
    snprintf(device_id, sizeof(device_id), "room_%s", current_room_id);

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
    ESP_LOGI(TAG, "========== 🏨 智慧客房边缘控制终端 启动 ==========");

    // 1. 初始化系统非易失性存储 (NVS)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    
    // 2. 初始化所有的底层硬件驱动模块 (极简拼装)
    ESP_LOGI(TAG, "--- 硬件底层驱动加载 ---");
    driver_oled_init();
    driver_rc522_init();
    hal_actuators_init();
    hal_sensors_init();
    hal_interactive_init();
    hal_audio_init();
    hal_infrared_init();
    
    driver_oled_clear_screen();
    driver_oled_show_text_line(0, "System Booting...");

    // 3. 从 NVS 读取当前房号，严格拼接规范的 Client ID
    load_nvs_string_with_fallback("Room_ID", current_room_id, sizeof(current_room_id), "301");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri), GLOBAL_MQTT_BROKER_URI);
    snprintf(device_id, sizeof(device_id), "room_%s", current_room_id);
    
    char boot_msg[32];
    snprintf(boot_msg, sizeof(boot_msg), "Room: %s", current_room_id);
    driver_oled_show_text_line(0, boot_msg);

    // 4. 启动网络与配网服务
    ESP_LOGI(TAG, "--- 启动网络服务 ---");
    service_network_provisioning_start(on_network_status_changed);

    // 5. 挂载持续运行的业务逻辑任务
    ESP_LOGI(TAG, "--- 挂载 FreeRTOS 任务 ---");
    // sensor_task: 只负责采集+上报
    xTaskCreatePinnedToCore(task_sensor_monitor, "sensor_task", 4096, NULL, 5, NULL, 1);
    // voice_task: 只负责通话态音频处理
    xTaskCreate(task_voice_call, "voice_task", 4096, NULL, 5, NULL);
    // auto_lock_task: 门锁自动回锁守护
    xTaskCreate(task_room_auto_lock, "room_auto_lock_task", 3072, NULL, 4, NULL);
    // button_task: 客房场景/SOS 按键业务
    xTaskCreate(task_room_button_events, "room_button_task", 3072, NULL, 4, NULL);

    // 6. main 仅做守护，不注入模拟业务动作，避免干扰真实联调
    while (1) {
        vTaskDelay(MAIN_GUARD_PERIOD);
        ESP_LOGI(TAG, "main_guard alive, room=%s, net=%d", current_room_id, (int)s_network_ready);
    }
#endif /* CONFIG_ROOM_TERMINAL_NET_TEST_MODE */
}
