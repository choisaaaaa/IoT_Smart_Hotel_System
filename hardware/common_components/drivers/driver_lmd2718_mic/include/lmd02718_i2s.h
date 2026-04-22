#pragma once

#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * LMD2718+NS4168 音频模块的 I2S 总线绑定。
 *
 * 注意 MEMS 与功放的差异（见 LMD2718T 规格书）：
 *   - LMD2718T 麦克风输出格式是 **单比特 PDM**（CLK + DATA，无 WS），
 *     必须用 ESP32 的 I2S PDM RX 模式（非 I2S 标准模式）。PDM CLK 建议
 *     2.048 MHz（落在 LMD2718T 允许的 1.024~3.072 MHz 内）。
 *   - NS4168 功放是常规 I2S 串行输入（BCLK + WS/LRCK + SDATA），用 I2S STD TX。
 *
 * 为避免 BCLK/PDM_CLK 频率不同引起的争用，MIC 与 SPK 建议使用不同的 I2S 外设：
 *   - SPK(TX)  建议 I2S0 + STD 模式（BCLK/WS/DOUT 三脚）
 *   - MIC(RX)  建议 I2S1 + PDM 模式（PDM_CLK/PDM_DATA 两脚，PDM_CLK 必须独立）
 *
 * 以下两个 init 相互独立，可任意顺序调用。
 */
esp_err_t lmd02718_i2s_init_pdm_rx(int i2s_port, int pin_pdm_clk, int pin_pdm_din, uint32_t sample_rate_hz);
esp_err_t lmd02718_i2s_init_tx(int i2s_port, int pin_bclk, int pin_ws, int pin_dout, uint32_t sample_rate_hz);

esp_err_t lmd02718_i2s_read(int16_t *samples, size_t max_samples, size_t *out_read_samples);
esp_err_t lmd02718_i2s_write(const int16_t *samples, size_t sample_count);

#ifdef __cplusplus
}
#endif
