#include "driver_lmd2718_mic.h"
#include "hal_log.h"
#include <string.h>

static const char *TAG = "DRIVER_LMD2718_MIC";
static bool s_inited = false;

esp_err_t driver_lmd2718_mic_init(const driver_lmd2718_mic_config_t *cfg)
{
    if (cfg == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    s_inited = true;
    HAL_LOGI(TAG, "LMD2718 Mic init (port=%d bclk=%d ws=%d din=%d rate=%lu)",
             cfg->i2s_port, cfg->pin_bclk, cfg->pin_ws, cfg->pin_din, (unsigned long)cfg->sample_rate_hz);
    return ESP_OK;
}

esp_err_t driver_lmd2718_mic_read_pcm(int16_t *out_samples, size_t max_samples, size_t *out_read_samples)
{
    if (!s_inited || out_samples == NULL || out_read_samples == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    // 基础占位：返回静音样本，后续替换为真实 i2s_read
    memset(out_samples, 0, max_samples * sizeof(int16_t));
    *out_read_samples = max_samples;
    return ESP_OK;
}
