#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * PAM8403 为模拟功放，通常无数字总线控制。
 * 本驱动仅管理可选 EN 引脚及播放接口占位。
 */

esp_err_t driver_pam8403_init(int pin_enable);
esp_err_t driver_pam8403_enable(bool enable);
esp_err_t driver_pam8403_play_pcm8(const uint8_t *data, size_t len);

#ifdef __cplusplus
}
#endif
