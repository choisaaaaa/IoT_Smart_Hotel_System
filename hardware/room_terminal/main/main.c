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

// --- 辅助组包函数 (规范化数据上报) ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
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
        bool exec_success = false;

        ESP_LOGI(TAG, "执行指令: %s (ID: %d)", cmd_type, cmd_id);

        // 简单清晰的指令分发逻辑 (查阅文档 A. 常用命令类型)
        if (strcmp(cmd_type, "light_on") == 0) {
            hal_actuators_set_state(ACTUATOR_LIGHT_MAIN, true);
            exec_success = true;
        } else if (strcmp(cmd_type, "light_off") == 0) {
            hal_actuators_set_state(ACTUATOR_LIGHT_MAIN, false);
            exec_success = true;
        } else if (strcmp(cmd_type, "door_unlock") == 0) {
            hal_actuators_set_state(ACTUATOR_DOOR_LOCK, true);
            exec_success = true;
        } else if (strcmp(cmd_type, "incoming_call") == 0) {
            cJSON *call_id = cJSON_GetObjectItem(root, "call_id");
            cJSON *caller_id = cJSON_GetObjectItem(root, "caller_id");
            if (call_id && caller_id) {
                strncpy(current_call_id, call_id->valuestring, sizeof(current_call_id));
                strncpy(remote_id, caller_id->valuestring, sizeof(remote_id));
                is_on_call = true;
                exec_success = true;
            }
        } else if (strcmp(cmd_type, "hangup_call") == 0) {
            is_on_call = false;
            exec_success = true;
        }

        // 上报执行结果回执 (规范 4.2.4)
        char timestamp[32];
        service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

        cJSON *reply = cJSON_CreateObject();
        cJSON_AddStringToObject(reply, "device_id", device_id);
        cJSON_AddNumberToObject(reply, "command_id", cmd_id);
        cJSON_AddStringToObject(reply, "command_type", cmd_type);
        cJSON_AddStringToObject(reply, "status", exec_success ? "success" : "failed");
        if (exec_success) {
            cJSON_AddStringToObject(reply, "result", "执行成功");
        } else {
            cJSON_AddStringToObject(reply, "result", "未识别的指令或设备故障");
        }
        cJSON_AddStringToObject(reply, "timestamp", timestamp);

        char *reply_str = cJSON_PrintUnformatted(reply);
        service_mqtt_publish("hotel/device/command/result", reply_str);
        
        free(reply_str);
        cJSON_Delete(reply);
        
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
        char msg[32];
        snprintf(msg, sizeof(msg), "IP:%s", ip_address);
        driver_oled_show_text_line(1, msg);
        
        // 连上网后，使用统一的宏地址启动 MQTT
        service_mqtt_start(GLOBAL_MQTT_BROKER_URI, device_id);
        
        // 订阅房间专属控制指令 (规范 11.4)
        char sub_topic[128];
        snprintf(sub_topic, sizeof(sub_topic), "hotel/device/command/room/%s", device_id);
        service_mqtt_subscribe(sub_topic, hotel_mqtt_callback);

        // 延迟一小段以确保 MQTT 连接建立后再发送状态 (Mock演示用)
        vTaskDelay(pdMS_TO_TICKS(1000));
        
        // 发布规范的上线状态
        publish_device_online_status();
    }
}

// --- 独立业务任务 (FreeRTOS) ---

// 定_时传感器采集任务
void task_sensor_monitor(void *pvParameters) {
    ESP_LOGI(TAG, "传感器监控任务启动...");
    sensor_data_t env_data;
    
    while(1) {
        vTaskDelay(pdMS_TO_TICKS(15000)); // 每15秒采一次，避免刷屏
        
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

static bool is_on_call = false;
static char current_call_id[64] = "";
static char remote_id[32] = "";

void task_voice_call(void *pvParameters) {
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
        vTaskDelay(pdMS_TO_TICKS(100)); 
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
    if (service_network_read_nvs_string("Room_ID", current_room_id, sizeof(current_room_id)) != ESP_OK) {
        strncpy(current_room_id, "301", sizeof(current_room_id));
    }
    snprintf(device_id, sizeof(device_id), "room_%s", current_room_id);
    
    char boot_msg[32];
    snprintf(boot_msg, sizeof(boot_msg), "Room: %s", current_room_id);
    driver_oled_show_text_line(0, boot_msg);

    // 4. 启动网络与配网服务
    ESP_LOGI(TAG, "--- 启动网络服务 ---");
    service_network_provisioning_start(on_network_status_changed);

    // 5. 挂载持续运行的业务逻辑任务 (双核分配)
    ESP_LOGI(TAG, "--- 挂载 FreeRTOS 任务 ---");
    xTaskCreatePinnedToCore(task_sensor_monitor, "Sensor_Task", 4096, NULL, 5, NULL, 1);
    xTaskCreate(task_voice_call, "voice_call_task", 4096, NULL, 5, NULL);

    // 6. 主线程死循环 (模拟突发的安防事件：刷卡开门)
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(30000)); // 每30秒模拟一次开门 
        
        ESP_LOGI(TAG, "--- (主线程模拟) 突发事件：住客刷房卡！ ---");
        uint8_t sector_data[16];
        
        // [安全演进提示]: 明文存放的默认通信密钥(FFFFFFFFFFFF) 仅限于原型联调期使用。
        uint8_t key[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
        
        if (driver_rc522_read_sector(1, key, sector_data) == ESP_OK) {
            hal_actuators_set_state(ACTUATOR_DOOR_LOCK, true); // 开门
            hal_interactive_beep(1, 200); // 短鸣1声
            hal_interactive_set_led_color(0, 0, 255, 0); // 亮绿灯
            
            // 按规范上报带时间戳和 event_data 嵌套的安防 JSON 报文
            publish_security_door_event();
            
            vTaskDelay(pdMS_TO_TICKS(3000));
            hal_actuators_set_state(ACTUATOR_DOOR_LOCK, false); // 3秒后关门锁
        }
    }
}
