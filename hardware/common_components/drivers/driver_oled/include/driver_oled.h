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

/**
 * 一次性写入 4 行并仅触发一次 I2C flush，避免整屏重绘闪烁。
 * 任一行传 NULL 表示该行保留现有画面不擦除。
 */
esp_err_t driver_oled_show_4_lines(const char *l0, const char *l1, const char *l2, const char *l3);

esp_err_t driver_oled_clear_screen(void);

#ifdef __cplusplus
}
#endif
