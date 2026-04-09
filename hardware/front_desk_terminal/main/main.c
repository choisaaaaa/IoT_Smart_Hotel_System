#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_system.h"
#include "nvs_flash.h"
#include "cJSON.h"

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
    snprintf(topic, sizeof(topic), "hotel/device/status/front_desk/%s", device_id);

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    free(json_str);
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

// 按键事件任务骨架：后续补充具体按键语义上报
void task_front_button_events(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        vTaskDelay(FRONT_BUTTON_TASK_PERIOD);
        // TODO: 读取按键状态并上报事件（如消音/广播）
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
    
    // 2. 从 NVS 读取配置（NVS 优先，默认值兜底）
    char front_id[16] = {0};
    load_nvs_string_with_fallback("FrontDesk_ID", front_id, sizeof(front_id), "01");
    snprintf(device_id, sizeof(device_id), "front_desk_%s", front_id);
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
}
