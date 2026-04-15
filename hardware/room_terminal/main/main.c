#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "cJSON.h"

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

// 统一任务周期配置，避免散落魔法数字
static const TickType_t SENSOR_TASK_PERIOD = pdMS_TO_TICKS(15000);
static const TickType_t VOICE_TASK_PERIOD = pdMS_TO_TICKS(100);
static const TickType_t MAIN_GUARD_PERIOD = pdMS_TO_TICKS(30000);
static const TickType_t DOOR_UNLOCK_HOLD_PERIOD = pdMS_TO_TICKS(3000);

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

static void publish_command_result(int cmd_id, const char *cmd_type, bool exec_success, const char *result_msg) {
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
    cJSON_AddStringToObject(reply, "timestamp", timestamp);

    char *reply_str = cJSON_PrintUnformatted(reply);
    service_mqtt_publish("hotel/device/command/result", reply_str);

    free(reply_str);
    cJSON_Delete(reply);
}

static bool execute_room_command(const char *cmd_type, cJSON *root, const char **out_result_msg) {
    if (strcmp(cmd_type, "light_on") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "灯光控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "light_off") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "灯光控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "door_unlock") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH4, true);
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
    snprintf(topic, sizeof(topic), "hotel/device/status/room/%s", device_id);

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
    snprintf(topic, sizeof(topic), "hotel/device/data/%s/%s", sensor_type, device_id);

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

// 上报安全事件 (规范 4.2.5)
void publish_security_door_event() {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过安防事件上报");
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "event_type", "door_open");
    
    cJSON *event_data = cJSON_CreateObject();
    cJSON_AddNumberToObject(event_data, "room_id", atoi(current_room_id));
    cJSON_AddStringToObject(event_data, "door_type", "main");
    cJSON_AddItemToObject(root, "event_data", event_data);

    cJSON_AddStringToObject(root, "level", "info");
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish("hotel/security/event", json_str);

    free(json_str);
    cJSON_Delete(root);
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

        ESP_LOGI(TAG, "执行指令: %s (ID: %d)", cmd_type, cmd_id);

        bool exec_success = execute_room_command(cmd_type, root, &result_msg);
        publish_command_result(cmd_id, cmd_type, exec_success, result_msg);
        
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
        snprintf(sub_topic, sizeof(sub_topic), "hotel/device/command/room/%s", device_id);
        service_mqtt_subscribe(sub_topic, hotel_mqtt_callback);

        // 订阅 AI 助手响应 (规范 12.1)
        char ai_sub_topic[128];
        snprintf(ai_sub_topic, sizeof(ai_sub_topic), MQTT_TOPIC_AI_RESPONSE, current_room_id);
        service_mqtt_subscribe(ai_sub_topic, ai_mqtt_callback);

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
    }
}

// --- 语音通话相关任务 (新) ---

// AI 助手相关配置
#define AI_WAKE_WORD "小智"
#define MQTT_TOPIC_AI_REQUEST "hotel/ai/request/room/%s"
#define MQTT_TOPIC_AI_RESPONSE "hotel/ai/response/room/%s"

static bool is_ai_awake = false;

// 语音唤醒处理 (伪代码/逻辑说明)
void handle_voice_wake_word(const char* recognized_text) {
    if (strstr(recognized_text, AI_WAKE_WORD)) {
        ESP_LOGI(TAG, "AI 助手已唤醒");
        is_ai_awake = true;
        // 播放唤醒提示音
        hal_interactive_beep(2, 50);
        
        // 发送唤醒事件到后台
        char topic[128];
        snprintf(topic, sizeof(topic), MQTT_TOPIC_AI_REQUEST, current_room_id);
        
        cJSON *root = cJSON_CreateObject();
        cJSON_AddStringToObject(root, "event", "awake");
        cJSON_AddStringToObject(root, "room_id", current_room_id);
        char *json_str = cJSON_PrintUnformatted(root);
        service_mqtt_publish(topic, json_str);
        free(json_str);
        cJSON_Delete(root);
    }
}

// AI 响应处理回调
void ai_mqtt_callback(const char *topic, const char *data, int data_len) {
    ESP_LOGI(TAG, "收到 AI 助手回复");
    
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) return;

    cJSON *text = cJSON_GetObjectItem(root, "text");
    cJSON *audio_data = cJSON_GetObjectItem(root, "audio_data");
    cJSON *action = cJSON_GetObjectItem(root, "action");

    if (cJSON_IsString(text)) {
        ESP_LOGI(TAG, "AI 说: %s", text->valuestring);
        driver_oled_show_text_line(2, text->valuestring);
    }

    if (cJSON_IsString(audio_data)) {
        ESP_LOGI(TAG, "正在播放 AI 语音...");
        // 调用底层音频组件播放 base64 或者是 URL
        // hal_audio_play_base64(audio_data->valuestring);
    }

    if (cJSON_IsString(action)) {
        if (strcmp(action->valuestring, "transfer") == 0) {
            ESP_LOGI(TAG, "AI 请求转接前台");
            // 触发通话逻辑
            is_on_call = true;
            hal_interactive_beep(1, 500);
        }
    }

    cJSON_Delete(root);
    is_ai_awake = false; // 处理完回复后重置唤醒状态
}

// 修改任务以支持 AI 语音
void task_voice_call(void *pvParameters) {
    (void)pvParameters;
    uint8_t audio_buffer[1024];
    size_t read_len = 0;
    
    while(1) {
        if (is_on_call || is_ai_awake) {
            // 1. 录制一段音频
            if (hal_audio_record_chunk(audio_buffer, sizeof(audio_buffer), &read_len) == ESP_OK) {
                // 2. 发送音频数据
                if (is_ai_awake) {
                    // 硬件端实时发送语音片段到后端进行 ASR
                    char topic[128];
                    snprintf(topic, sizeof(topic), MQTT_TOPIC_AI_REQUEST, current_room_id);
                    
                    // 这里通常会将音频转为 base64 或直接发二进制（取决于 MQTT 服务端支持）
                    // 简化演示：封装为 JSON 发送音频数据块
                    cJSON *root = cJSON_CreateObject();
                    cJSON_AddStringToObject(root, "event", "voice_stream");
                    cJSON_AddStringToObject(root, "room_id", current_room_id);
                    // cJSON_AddStringToObject(root, "audio_chunk", base64_encode(audio_buffer, read_len));
                    
                    char *json_str = cJSON_PrintUnformatted(root);
                    service_mqtt_publish(topic, json_str);
                    free(json_str);
                    cJSON_Delete(root);
                } else if (is_on_call) {
                    // 正在与前台通话中，发送音频流到通话 Topic
                    char call_topic[128];
                    snprintf(call_topic, sizeof(call_topic), "hotel/call/audio/%s", current_call_id);
                    // service_mqtt_publish_binary(call_topic, audio_buffer, read_len);
                }
            }
        }
        vTaskDelay(VOICE_TASK_PERIOD);
    }
}

// 主入口
void app_main(void)
{
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

    // 6. main 仅做守护与轻量模拟事件
    while (1) {
        vTaskDelay(MAIN_GUARD_PERIOD); // 每30秒模拟一次开门
        
        ESP_LOGI(TAG, "--- (主线程模拟) 突发事件：住客刷房卡！ ---");
        uint8_t sector_data[16];
        
        // [安全演进提示]: 明文存放的默认通信密钥(FFFFFFFFFFFF) 仅限于原型联调期使用。
        uint8_t key[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
        
        if (driver_rc522_read_sector(1, key, sector_data) == ESP_OK) {
            hal_actuators_set_state(ACTUATOR_RELAY_CH4, true); // 开门
            hal_interactive_beep(1, 200); // 短鸣1声
            hal_interactive_set_led_color(0, 0, 255, 0); // 亮绿灯
            
            // 按规范上报带时间戳和 event_data 嵌套的安防 JSON 报文
            publish_security_door_event();
            
            vTaskDelay(DOOR_UNLOCK_HOLD_PERIOD);
            hal_actuators_set_state(ACTUATOR_RELAY_CH4, false); // 3秒后关门锁
        }
    }
}
