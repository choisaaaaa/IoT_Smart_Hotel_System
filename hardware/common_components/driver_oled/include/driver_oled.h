#pragma once

#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化 0.96 寸 I2C OLED 屏幕驱动及显存
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t driver_oled_init(void);

/**
 * @brief 在 OLED 的指定行显示一行文本并刷新 (极其方便的防堆屏接口)
 * @param line 行号 (通常 0-3 对应四行 16 像素高字符)
 * @param text 纯文本字符串 (UTF-8) 或英文 ASCII
 * @return esp_err_t ESP_OK 显示成功
 */
esp_err_t driver_oled_show_text_line(uint8_t line, const char *text);

/**
 * @brief 清空 OLED 屏幕上所有显示内容
 * @return esp_err_t ESP_OK 清屏成功
 */
esp_err_t driver_oled_clear_screen(void);

#ifdef __cplusplus
}
#endif
