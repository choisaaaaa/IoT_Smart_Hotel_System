#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 简洁版红外接收驱动（NEC，面向常见解调接收头，低电平脉冲）
 */

esp_err_t driver_ir_rx_init(int gpio_num);

/**
 * 轮询尝试解码一帧 NEC
 * - 无新帧：out_updated=false，返回 ESP_OK
 * - 解码成功：out_updated=true，填充 addr/cmd，返回 ESP_OK
 * - 有帧但校验失败：返回 ESP_ERR_INVALID_RESPONSE
 */
esp_err_t driver_ir_rx_poll_nec(uint8_t *out_addr, uint8_t *out_cmd, bool *out_updated);

#ifdef __cplusplus
}
#endif
