#include "driver_lmd2718_mic.h"
#include "lmd02718_i2s.h"
#include "hal_log.h"

static const char *TAG = "DRIVER_LMD2718_MIC";
static bool s_inited = false;

esp_err_t driver_lmd2718_mic_init(const driver_lmd2718_mic_config_t *cfg)
{
    if (cfg == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    esp_err_t err = lmd02718_i2s_init_pdm_rx(cfg->i2s_port, cfg->pin_pdm_clk, cfg->pin_pdm_din,
                                             cfg->sample_rate_hz);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "MEMS PDM RX 初始化失败: %s", esp_err_to_name(err));
        return err;
    }
    s_inited = true;
    HAL_LOGI(TAG, "LMD2718T MEMS PDM RX ok (i2s%d clk=%d din=%d rate=%lu)",
             cfg->i2s_port, cfg->pin_pdm_clk, cfg->pin_pdm_din,
             (unsigned long)cfg->sample_rate_hz);
    return ESP_OK;
}

esp_err_t driver_lmd2718_mic_read_pcm(int16_t *out_samples, size_t max_samples, size_t *out_read_samples)
{
    if (!s_inited || out_samples == NULL || out_read_samples == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    return lmd02718_i2s_read(out_samples, max_samples, out_read_samples);
}
