#pragma once

#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    DRIVER_RGB_LED_COMMON_CATHODE = 0,  // 共阴：占空比越大越亮
    DRIVER_RGB_LED_COMMON_ANODE = 1,    // 共阳：占空比越小越亮
} driver_rgb_led_type_t;

/**
 * @brief 初始化 RGB LED（基于 LEDC PWM）
 * @param pin_r 红色引脚
 * @param pin_g 绿色引脚
 * @param pin_b 蓝色引脚
 * @param type 共阴/共阳
 */
esp_err_t driver_rgb_led_init(int pin_r, int pin_g, int pin_b, driver_rgb_led_type_t type);

/**
 * @brief 设置 RGB 亮度
 * @param r 0~255
 * @param g 0~255
 * @param b 0~255
 */
esp_err_t driver_rgb_led_set_rgb(uint8_t r, uint8_t g, uint8_t b);

/**
 * @brief 按 0xRRGGBB 设置颜色
 */
esp_err_t driver_rgb_led_set_color_hex(uint32_t rgb_hex);

/**
 * @brief 熄灭 RGB LED
 */
esp_err_t driver_rgb_led_off(void);

#ifdef __cplusplus
}
#endif
