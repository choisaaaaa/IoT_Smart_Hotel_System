#include "driver_oled.h"
#include "esp_log.h"
#include <string.h>

static const char *TAG = "DRIVER_OLED_MOCK";

esp_err_t driver_oled_init(void) {
    ESP_LOGI(TAG, "[MOCK] SSD1306 OLED (I2C) 初始化命令序列发送完毕");
    // TODO: 硬件到位后配置 i2c_master_init() 和 u8g2/lvgl 显存分配
    return ESP_OK;
}

esp_err_t driver_oled_show_text_line(uint8_t line, const char *text) {
    if (text == NULL) return ESP_ERR_INVALID_ARG;
    if (line > 3) line = 3; // 假设只有4行 (0,1,2,3)

    // 模拟将字符通过 I2C 刷进屏幕的显存操作
    ESP_LOGI(TAG, "[MOCK OLED 虚拟屏] 第 %d 行显示: %s", line, text);

    // TODO: 硬件到位后替换为 u8g2_DrawStr() 等绘图API，再调用 u8g2_SendBuffer()
    return ESP_OK;
}

esp_err_t driver_oled_clear_screen(void) {
    ESP_LOGI(TAG, "[MOCK OLED 虚拟屏] ====== 执行全屏清空 ======");
    // TODO: 硬件到位后替换为 u8g2_ClearBuffer()
    return ESP_OK;
}
