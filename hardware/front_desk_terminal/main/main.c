#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "cJSON.h"

#include "hal_interactive.h"
#include "service_mqtt.h"
#include "service_network.h"
#include "driver_rc522.h"
#include "global_config.h"

static const char *TAG = "FRONT_DESK_MAIN";
static char device_id[32] = "front_desk_01"; // 规范命名 (6.1.1)

// --- 辅助组包函数 ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
    char topic[128];
    snprintf(topic, sizeof(topic), "hotel/device/status/front_desk/%s", device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "front_desk");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddStringToObject(root, "firmware_version", "v1.1.0");
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    
    free(json_str);
    cJSON_Delete(root);
}

// 发布设备心跳 (规范 6.1.2)
void publish_device_heartbeat() {
    char topic[128];
    snprintf(topic, sizeof(topic), "hotel/device/status/front_desk/%s", device_id);

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

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    
    free(json_str);
    cJSON_Delete(root);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        ESP_LOGI(TAG, "网络已连接，IP: %s", ip_address);
        
        // 启动 MQTT
        service_mqtt_start(GLOBAL_MQTT_BROKER_URI, device_id);
        
        // 延迟一小段以确保 MQTT 连接建立
        vTaskDelay(pdMS_TO_TICKS(1000));
        
        // 发布规范的上线状态
        publish_device_online_status();
        
        // 声光提示：蓝灯常亮，短鸣2声表示上线成功
        hal_interactive_set_led_color(0, 0, 0, 255); 
        hal_interactive_beep(2, 100);
    }
}

// 主入口
void app_main(void) {
    ESP_LOGI(TAG, "========== 🛎️ 智慧前台管理端 启动 ==========");

    // 1. 初始化系统非易失性存储 (NVS)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    
    // 2. 初始化底层硬件驱动
    driver_rc522_init();
    hal_interactive_init();
    
    // 3. 启动网络与配网服务
    service_network_provisioning_start(on_network_status_changed);

    // 4. 主线程死循环维持心跳及监听刷卡事件
    while(1) {
        vTaskDelay(pdMS_TO_TICKS(60000)); // 每分钟发一次心跳
        
        // 发送规范心跳报文
        publish_device_heartbeat();
    }
}
