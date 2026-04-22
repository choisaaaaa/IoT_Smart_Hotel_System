#include "driver_ns4168.h"
#include "lmd02718_i2s.h"
#include "hal_log.h"

static const char *TAG = "DRIVER_NS4168";
static bool s_inited = false;

esp_err_t driver_ns4168_init(const driver_ns4168_config_t *cfg)
{
    if (cfg == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    esp_err_t err = lmd02718_i2s_init_tx(cfg->i2s_port, cfg->pin_bclk, cfg->pin_ws, cfg->pin_dout,
                                         cfg->sample_rate_hz);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "I2S TX init failed: %s", esp_err_to_name(err));
        return err;
    }
    s_inited = true;
    HAL_LOGI(TAG, "NS4168 I2S TX (port=%d bclk=%d ws=%d dout=%d rate=%lu)",
             cfg->i2s_port, cfg->pin_bclk, cfg->pin_ws, cfg->pin_dout, (unsigned long)cfg->sample_rate_hz);
    return ESP_OK;
}

esp_err_t driver_ns4168_play_pcm(const int16_t *samples, size_t sample_count)
{
    if (!s_inited || samples == NULL || sample_count == 0) {
        return ESP_ERR_INVALID_STATE;
    }
    return lmd02718_i2s_write(samples, sample_count);
}
