#pragma once

/**
 * 0.96 寸 I2C OLED，控制器 SSD1306（128×高可在 global_config 中配置 32/64）。
 * 使用 ESP-IDF esp_lcd SSD1306 驱动 + 5×7 ASCII 字模；UTF-8 多字节汉字不会正确显示。
 */

#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t driver_oled_init(void);

/** 在第 line 行（0~3）显示一行 ASCII 文本，并刷新全屏缓冲 */
esp_err_t driver_oled_show_text_line(uint8_t line, const char *text);

esp_err_t driver_oled_clear_screen(void);

#ifdef __cplusplus
}
#endif
