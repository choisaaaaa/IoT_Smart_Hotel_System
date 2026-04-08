#pragma once

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化光敏电阻（分压后接 ADC）
 */
esp_err_t driver_ldr_init(int gpio_num);

/**
 * @brief 读取原始 ADC 值（约 0~4095）
 */
esp_err_t driver_ldr_read_raw(int *out_raw);

/**
 * @brief 读取亮度百分比（0~100，线性映射）
 */
esp_err_t driver_ldr_read_percent(int *out_percent);

#ifdef __cplusplus
}
#endif
