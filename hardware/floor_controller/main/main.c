#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "cJSON.h"

// 引入所需的底层硬件抽象组件库
#include "service_mqtt.h"
#include "hal_actuators.h"
#include "hal_sensors.h"
#include "service_network.h"
#include "global_config.h"

static const char *TAG = "FLOOR_CONTROLLER_MAIN";
static char current_floor_id[16] = "UNKNOWN";
static char device_id[32] = "floor_UNKNOWN";

// --- 辅助组包函数 ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
    char topic[128];
    snprintf(topic, sizeof(topic), "hotel/device/status/floor/%s", device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "floor");
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

// MQTT 消息接收回调 (群控解析)
void floor_mqtt_callback(const char *topic, const char *data, int data_len) {
    ESP_LOGI(TAG, "==== 收到云端 MQTT 楼控群控指令 ====");
    
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) return;

    cJSON *cmd_id_item = cJSON_GetObjectItem(root, "command_id");
    cJSON *cmd_type_item = cJSON_GetObjectItem(root, "command_type");

    if (cJSON_IsNumber(cmd_id_item) && cJSON_IsString(cmd_type_item)) {
        int cmd_id = cmd_id_item->valueint;
        const char *cmd_type = cmd_type_item->valuestring;
        bool exec_success = false;

        // 如果是走廊灯控
        if (strcmp(cmd_type, "light_on") == 0) {
            hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
            exec_success = true;
        } else if (strcmp(cmd_type, "light_off") == 0) {
            hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
            exec_success = true;
        }

        // 上报执行结果
        char timestamp[32];
        service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

        cJSON *reply = cJSON_CreateObject();
        cJSON_AddStringToObject(reply, "device_id", device_id);
        cJSON_AddNumberToObject(reply, "command_id", cmd_id);
        cJSON_AddStringToObject(reply, "command_type", cmd_type);
        cJSON_AddStringToObject(reply, "status", exec_success ? "success" : "failed");
        cJSON_AddStringToObject(reply, "timestamp", timestamp);

        char *reply_str = cJSON_PrintUnformatted(reply);
        service_mqtt_publish("hotel/device/command/result", reply_str);
        
        free(reply_str);
        cJSON_Delete(reply);
    }
    cJSON_Delete(root);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        ESP_LOGI(TAG, "网络已连接，IP: %s", ip_address);
        
        // 启动 MQTT
        service_mqtt_start(GLOBAL_MQTT_BROKER_URI, device_id);
        
        // 订阅本楼层的公共指令
        char sub_topic[128];
        snprintf(sub_topic, sizeof(sub_topic), "hotel/device/command/floor/%s", device_id);
        service_mqtt_subscribe(sub_topic, floor_mqtt_callback);

        vTaskDelay(pdMS_TO_TICKS(1000));
        publish_device_online_status();
    }
}

// 主入口
void app_main(void) {
    ESP_LOGI(TAG, "========== 🏢 智慧走廊楼控端 启动 ==========");

    // 1. 初始化系统非易失性存储 (NVS)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    
    // 2. 初始化底层硬件驱动
    hal_actuators_init();
    hal_sensors_init();

    // 3. 读取并拼接规范的 Client ID
    if (service_network_read_nvs_string("Floor_ID", current_floor_id, sizeof(current_floor_id)) != ESP_OK) {
        strncpy(current_floor_id, "03", sizeof(current_floor_id)); // Mock 第3层
    }
    snprintf(device_id, sizeof(device_id), "floor_%s", current_floor_id);
    
    // 4. 启动网络与配网服务
    service_network_provisioning_start(on_network_status_changed);

    // 5. 走廊温湿度与光照监控
    sensor_data_t env_data;
    while(1) {
        vTaskDelay(pdMS_TO_TICKS(30000)); // 每半分钟发一次走廊环境数据
        
        hal_sensors_read_all(&env_data);
        
        publish_sensor_data("temperature", env_data.temperature, "℃");
        publish_sensor_data("light", 450.0, "lux"); // 模拟走廊光照
    }
}
