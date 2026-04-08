#pragma once

/**
 * =============================================================================
 * 【版本 A】RD-03 最简接入 —— 仅使用 OT2 数字输出（不接 UART）
 * =============================================================================
 * 适用：快速判断“有人/无人”，引脚占用少、代码最简单。
 * 接线：模组 OT2 -> 本参数 gpio；GND 共地；模组按规格书供电（常见 3.3V）。
 * 注意：电平极性以安信可说明书为准；本驱动默认「高电平 = 有人」。
 * 与【版本 B】互斥选一种即可，见目录 ../driver_rd03_uart/
 * =============================================================================
 */

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/** 初始化 OT2 所接 GPIO 为输入（无上拉下拉，由模组推挽驱动） */
esp_err_t driver_rd03_simple_init(int gpio_ot2);

/**
 * 读取当前是否判定有人
 * @param out_present 输出；true 表示有人（在默认高有效假设下）
 */
esp_err_t driver_rd03_simple_read(bool *out_present);

#ifdef __cplusplus
}
#endif
