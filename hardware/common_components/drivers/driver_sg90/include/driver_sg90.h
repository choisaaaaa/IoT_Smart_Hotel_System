#pragma once

#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化 SG90 舵机控制模块 (使用 ESP32 LEDC PWM)
 * 
 * @param servo_pin 要控制舵机的 GPIO 引脚编号 (比如 15)
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t driver_sg90_init(int servo_pin);

/**
 * @brief 控制 SG90 舵机转动到指定角度
 * 
 * @param angle 目标角度 (范围: 0 ~ 180度)
 * @return esp_err_t ESP_OK 成功，ESP_ERR_INVALID_ARG 角度越界
 */
esp_err_t driver_sg90_set_angle(int angle);

#ifdef __cplusplus
}
#endif
