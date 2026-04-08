#pragma once

/**
 * =============================================================================
 * 【版本 B】RD-03 UART 接入 —— 按安信可《Rd-03 V2 UART communication protocol》
 * =============================================================================
 * 适用：需串口数据、与上位机协议一致；默认仅被动接收并解析上报帧（不发送配网命令）。
 * 接线（Rd-03 V2 表 1）：MCU UART RX <- 模组 Pin3（模块 TX 输出）；
 *                      MCU UART TX -> 模组 OT1（模块 RX 输入）。GND 共地。
 * 若你手中为旧版 RD-03，引脚命名可能与 V2 不同，请先对 PDF 再接线。
 * 解析：识别上报头 F4 F3 F2 F1 或 F8 F7 F6 F5，小端 16 位长度后的首字节作有无目标结果（非 0 视为有人）。
 * 与【版本 A】互斥选一种即可，见目录 ../driver_rd03_simple/
 * =============================================================================
 */

#include <stdbool.h>
#include <stddef.h>
#include "driver/uart.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @param uart_num   如 UART_NUM_1
 * @param pin_mcu_tx MCU 侧 TX（接模组 OT1 / 模块 RX）
 * @param pin_mcu_rx MCU 侧 RX（接模组 Pin3 / 模块 TX）
 */
esp_err_t driver_rd03_uart_init(uart_port_t uart_num, int pin_mcu_tx, int pin_mcu_rx);

/**
 * 从 UART 读入内部缓冲并尝试解析；可在任务中周期性调用。
 * 仅当 *out_updated 为 true 时，*out_present 为本次解析结果；否则 *out_present 不变。
 */
esp_err_t driver_rd03_uart_poll(bool *out_updated, bool *out_present);

/** 仅清空内部粘包缓冲（例如重新上电模组后） */
void driver_rd03_uart_reset_buffer(void);

#ifdef __cplusplus
}
#endif
