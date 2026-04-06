#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "nvs_flash.h"

// 引入所有高内聚、低耦合的底层硬件抽象组件库！
#include "driver_rc522.h"
#include "service_mqtt.h"
#include "hal_actuators.h"
#include "hal_sensors.h"
#include "hal_interactive.h"
#include "hal_audio.h"
#include "hal_infrared.h"
#include "driver_oled.h"
#include "service_network.h"

static const char *TAG = "ROOM_TERMINAL_MAIN";
static char current_room_id[16] = "UNKNOWN";

// --- 业务回调函数 ---

// MQTT 消息接收回调 (模拟接收到后端开灯指令)
void hotel_mqtt_callback(const char *topic, const char *data, int data_len) {
    ESP_LOGI(TAG, "==== 收到云端 MQTT 消息 ====");
    ESP_LOGI(TAG, "Topic: %s | Payload: %.*s", topic, data_len, data);
    
    // 伪造业务逻辑：收到任何消息，立刻把主灯和窗帘打开
    ESP_LOGI(TAG, "业务逻辑触发：控制底层执行器...");
    hal_actuators_set_state(ACTUATOR_LIGHT_MAIN, true);
    hal_actuators_set_state(ACTUATOR_CURTAIN, true);
    
    // 并且屏幕显示提示
    driver_oled_show_text_line(2, "Cloud CMD Received");
    
    // 蜂鸣器提示
    hal_interactive_beep(1, 100);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        char msg[32];
        snprintf(msg, sizeof(msg), "IP:%s", ip_address);
        driver_oled_show_text_line(1, msg);
        
        // 连上网后，启动 MQTT
        char mqtt_client_id[32];
        snprintf(mqtt_client_id, sizeof(mqtt_client_id), "room_%s", current_room_id);
        service_mqtt_start("mqtt://hotel-backend-ip:1883", mqtt_client_id);
        
        char topic[64];
        snprintf(topic, sizeof(topic), "hotel/room/%s/cmd", current_room_id);
        service_mqtt_subscribe(topic, hotel_mqtt_callback);
    }
}

// --- 独立业务任务 (FreeRTOS) ---

// 定时传感器采集任务
void task_sensor_monitor(void *pvParameters) {
    ESP_LOGI(TAG, "传感器监控任务启动...");
    sensor_data_t env_data;
    
    while(1) {
        // 读取传感器数据
        hal_sensors_read_all(&env_data);
        
        // 将温湿度显示在 OLED 上
        char display_str[32];
        snprintf(display_str, sizeof(display_str), "T:%.1fC H:%.1f%%", env_data.temperature, env_data.humidity);
        driver_oled_show_text_line(3, display_str);
        
        // 判断如果有人，且空气质量差，自动发个 MQTT
        if (env_data.is_human_present && env_data.air_quality_adc > 420) {
            ESP_LOGW(TAG, "检测到有人且空气变差，准备自动控制...");
            ir_ac_cmd_t ac_cmd = {.power_on = true, .temperature = 26};
            hal_infrared_send_ac_command(IR_BRAND_GREE, &ac_cmd);
        }
        
        vTaskDelay(pdMS_TO_TICKS(5000)); // 每5秒采一次
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

    // 3. 从 NVS 读取当前房号
    if (service_network_read_nvs_string("Room_ID", current_room_id, sizeof(current_room_id)) != ESP_OK) {
        strncpy(current_room_id, "UNASSIGNED", sizeof(current_room_id));
    }
    
    char boot_msg[32];
    snprintf(boot_msg, sizeof(boot_msg), "Room: %s", current_room_id);
    driver_oled_show_text_line(0, boot_msg);

    // 4. 启动网络与配网服务
    ESP_LOGI(TAG, "--- 启动网络服务 ---");
    service_network_provisioning_start(on_network_status_changed);

    // 5. 挂载持续运行的业务逻辑任务 (双核分配)
    ESP_LOGI(TAG, "--- 挂载 FreeRTOS 任务 ---");
    xTaskCreatePinnedToCore(task_sensor_monitor, "Sensor_Task", 4096, NULL, 5, NULL, 1);

    // 6. 主线程死循环 (模拟一些突发的物理按键或卡片事件)
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(15000)); 
        
        ESP_LOGI(TAG, "--- (主线程模拟) 突发事件：住客刷房卡！ ---");
        uint8_t sector_data[16];
        
        // [安全演进提示]: 
        // 以下明文存放的默认通信密钥(FFFFFFFFFFFF) 仅限于原型联调期使用。
        // 在正式量产固件中，此密钥将被强制移入 NVS 存储区，由上位机经安全信道下发分发。
        uint8_t key[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
        
        if (driver_rc522_read_sector(1, key, sector_data) == ESP_OK) {
            // 假设卡片验证通过
            hal_actuators_set_state(ACTUATOR_DOOR_LOCK, true); // 开门
            hal_interactive_beep(1, 200); // 短鸣1声
            hal_interactive_set_led_color(0, 0, 255, 0); // 亮绿灯
            service_mqtt_publish("hotel/room/301/door", "{\"event\":\"opened\"}");
            
            vTaskDelay(pdMS_TO_TICKS(3000));
            hal_actuators_set_state(ACTUATOR_DOOR_LOCK, false); // 3秒后关门锁
        }
    }
}
