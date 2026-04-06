#include "hal_interactive.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "HAL_INTERACTIVE_MOCK";

esp_err_t hal_interactive_init(void) {
    ESP_LOGI(TAG, "[MOCK] 声光交互及物理按键外设 GPIO 初始化完成");
    // TODO: 硬件到货后，此处配置 RMT 模块驱动 WS2812，以及按键的上拉输入中断
    return ESP_OK;
}

esp_err_t hal_interactive_beep(uint8_t count, uint32_t duration_ms) {
    ESP_LOGI(TAG, "[MOCK] 蜂鸣器执行鸣叫: 共 %d 次，单次时长 %d 毫秒", count, duration_ms);
    for (int i = 0; i < count; i++) {
        // 模拟蜂鸣器鸣叫时的线程阻塞延时，让上层体验真实的硬件时序
        vTaskDelay(pdMS_TO_TICKS(duration_ms));
        vTaskDelay(pdMS_TO_TICKS(50)); // 短暂间隔
    }
    // TODO: 硬件到货后，替换为真实的 gpio_set_level 操作
    return ESP_OK;
}

esp_err_t hal_interactive_set_led_color(uint16_t led_index, uint8_t r, uint8_t g, uint8_t b) {
    ESP_LOGI(TAG, "[MOCK] WS2812 状态灯墙更新: 第 %d 颗灯珠被点亮为 RGB(%d, %d, %d)", led_index, r, g, b);
    // TODO: 硬件到货后，替换为 led_strip 真实驱动代码
    return ESP_OK;
}

bool hal_interactive_is_button_pressed(interactive_button_id_t button) {
    // 作为模拟测试，我们永远返回 false，避免无限触发中断和死循环
    // 如果组长你想在没有硬件时测试按键，可以在这里写个硬编码逻辑
    // 比如：判断开机超过 30 秒后，伪造返回一次 true (模拟住客按下呼叫前台)
    return false;
}
