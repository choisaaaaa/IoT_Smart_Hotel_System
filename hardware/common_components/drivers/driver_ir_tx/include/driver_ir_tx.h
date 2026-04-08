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

#ifdef __cplusplus
}
#endif
