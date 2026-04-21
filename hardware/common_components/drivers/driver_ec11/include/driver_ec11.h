#pragma once

/**
 * EC11 增量编码器（A/B 相 + 可选按键）简洁驱动
 * - 轮询式，不使用中断，便于快速集成与调试
 * - 默认按键低电平有效（常见接法：按钮到 GND，GPIO 开上拉）
 * - SW 经连续采样消抖；旋转时 A/B 毛刺常耦合到 SW 线，底层在 A/B 跳变时清零 SW 累计并依赖调用频率（建议 8～10ms 轮询）
 */

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    DRIVER_EC11_DIR_NONE = 0,
    DRIVER_EC11_DIR_CW = 1,
    DRIVER_EC11_DIR_CCW = -1,
} driver_ec11_direction_t;

/**
 * @brief 初始化 EC11
 * @param pin_a A 相 GPIO
 * @param pin_b B 相 GPIO
 * @param pin_btn 按键 GPIO（不使用则传 -1）
 */
esp_err_t driver_ec11_init(int pin_a, int pin_b, int pin_btn);

/**
 * @brief 轮询一次编码器状态（须周期性调用以推进消抖状态）
 * @param out_dir 本次检测到的方向（无旋转则 NONE）
 * @param out_btn_pressed 本次是否出现「消抖后刚进入按下」事件（不关心可传 NULL）
 */
esp_err_t driver_ec11_poll(driver_ec11_direction_t *out_dir, bool *out_btn_pressed);

/** @brief 无按键脚或未初始化时返回 false；否则返回消抖后的稳定按下状态（低有效=按下） */
bool driver_ec11_sw_stable_pressed(void);

#ifdef __cplusplus
}
#endif
