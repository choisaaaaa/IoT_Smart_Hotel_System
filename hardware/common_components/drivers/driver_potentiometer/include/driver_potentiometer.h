#pragma once

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化电位器（ADC 单端读取，中间脚接 GPIO，两端接 3.3V 与 GND）
 *
 * @param gpio_num 连接电位器中间脚的 GPIO（须为该芯片支持的 ADC 管脚）
 */
esp_err_t driver_potentiometer_init(int gpio_num);

/**
 * @brief 读取电位器位置，映射为 0~100（可用于音量百分比等）
 *
 * @param out_percent 输出 0~100，不可为 NULL
 */
esp_err_t driver_potentiometer_read_percent(int *out_percent);

/**
 * @brief 读取原始 ADC 值（约 0~4095，具体随芯片与量程略有差异）
 *
 * @param out_raw 输出原始读数，不可为 NULL
 */
esp_err_t driver_potentiometer_read_raw(int *out_raw);

#ifdef __cplusplus
}
#endif
