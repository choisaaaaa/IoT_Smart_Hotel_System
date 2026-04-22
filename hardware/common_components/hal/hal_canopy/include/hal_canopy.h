#pragma once

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化雨棚：舵机 PWM（driver_sg90）+ 雨量数字 DO（上拉输入）。
 *        引脚由 global_config.h 的 GLOBAL_CANOPY_SERVO_PIN / GLOBAL_RAIN_SENSOR_DO_PIN 决定；
 *        任一脚为 -1 则跳过对应外设。
 */
esp_err_t hal_canopy_init(void);

/** 周期性调用（建议 100ms），内部做雨量去抖并驱动舵机（自动模式）。 */
void hal_canopy_poll(void);

bool hal_canopy_get_auto(void);
void hal_canopy_set_auto(bool enabled);

bool hal_canopy_is_raining(void);
int hal_canopy_get_angle(void);

esp_err_t hal_canopy_manual_extend(void);
esp_err_t hal_canopy_manual_retract(void);

#ifdef __cplusplus
}
#endif
