#pragma once

#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 简洁版红外发送驱动（NEC）
 * - 基于 GPIO 软件载波（38kHz），实现简单，后续可替换为 RMT
 */

esp_err_t driver_ir_tx_init(int gpio_num);

/**
 * 发送 NEC 32-bit 帧：addr, ~addr, cmd, ~cmd（LSB first）
 */
esp_err_t driver_ir_tx_send_nec(uint8_t addr, uint8_t cmd);

/**
 * 发送一段 38kHz 载波（用于对射式障碍检测，配合解调接收头）
 * @param duration_us 载波时长（微秒），结束后引脚拉低
 */
esp_err_t driver_ir_tx_send_38khz_burst_us(uint32_t duration_us);

#ifdef __cplusplus
}
#endif
