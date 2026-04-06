#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "hal_interactive.h"
#include "service_mqtt.h"
#include "service_network.h"
#include "driver_rc522.h"

static const char *TAG = "FRONT_DESK_APP";

void app_main(void) {
    ESP_LOGI(TAG, "前台管理端 (Front Desk Terminal) 启动中...");

    // TODO: 调用 service_network_provisioning_start 启动配网
    
    // 初始化并建立 MQTT 服务器连接 (服务层抽象)
    service_mqtt_start("mqtt://hotel-backend-ip:1883", "front_desk_01");
    
    // 执行硬件级别声光提示 (HAL 层抽象，隔离 GPIO 操作)
    hal_interactive_beep(1, 200);                  // 设置蜂鸣器单次短鸣，持续 200ms
    hal_interactive_set_led_color(0, 0, 255, 0);   // 将 0 号 LED 节点设为标准绿色
    
    // 向后端服务发布标准协议 JSON 报文
    service_mqtt_publish("hotel/frontdesk/status", "{\"status\":\"online\"}");
    
    while(1) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
