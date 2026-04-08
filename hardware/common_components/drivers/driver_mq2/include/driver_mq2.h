#pragma once

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * MQ-2 简洁驱动
 * - AO: 模拟量（ADC）读取烟雾/可燃气体趋势
 * - DO: 数字阈值告警（可选）
 */

/**
 * @brief 初始化 MQ-2
 * @param adc_gpio AO 接入的 ADC GPIO（必填）
 * @param digital_gpio DO 接入 GPIO（可选，不使用传 -1）
 */
esp_err_t driver_mq2_init(int adc_gpio, int digital_gpio);

/**
 * @brief 读取 AO 原始 ADC 值（约 0~4095）
 */
esp_err_t driver_mq2_read_raw(int *out_raw);

/**
 * @brief 读取 AO 百分比（0~100，线性映射）
 */
esp_err_t driver_mq2_read_percent(int *out_percent);

/**
 * @brief 读取 DO 告警状态（true=告警），未配置 DO 会返回错误
 */
esp_err_t driver_mq2_read_alarm(bool *out_alarm);

#ifdef __cplusplus
}
#endif
