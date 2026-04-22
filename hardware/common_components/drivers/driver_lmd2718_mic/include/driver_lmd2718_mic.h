#pragma once

#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * LMD2718T 是 PDM MEMS 麦克风（规格书：单比特 PDM 输出，1.024~3.072MHz 时钟）。
 * 因此：
 *   - i2s_port 推荐 I2S1（与 TX 走 I2S0 的 NS4168 功放分开）
 *   - pin_pdm_clk 必须独立引脚，不可与功放 BCLK 共用
 *   - pin_pdm_din 接 MEMS 的 DATA 引脚
 */
typedef struct {
    int i2s_port;            /* MIC 走的 I2S 外设号（0 或 1），推荐 1 */
    int pin_pdm_clk;         /* PDM CLK 输出引脚（独立于功放 BCLK） */
    int pin_pdm_din;         /* PDM DATA 输入引脚（接 MEMS DATA） */
    uint32_t sample_rate_hz;
} driver_lmd2718_mic_config_t;

esp_err_t driver_lmd2718_mic_init(const driver_lmd2718_mic_config_t *cfg);
esp_err_t driver_lmd2718_mic_read_pcm(int16_t *out_samples, size_t max_samples, size_t *out_read_samples);

#ifdef __cplusplus
}
#endif
