#include "driver_ntc.h"
#include "hal_log.h"
#include "esp_adc/adc_oneshot.h"
#include <math.h>

static const char *TAG = "DRIVER_NTC";

static adc_oneshot_unit_handle_t s_adc = NULL;
static adc_channel_t s_channel;
static bool s_inited = false;
static driver_ntc_config_t s_cfg;

esp_err_t driver_ntc_init(int gpio_num, const driver_ntc_config_t *cfg)
{
    if (s_inited) {
        return ESP_OK;
    }
    if (cfg == NULL || cfg->r_fixed_ohm <= 0.0f || cfg->r_ntc_nominal_ohm <= 0.0f ||
        cfg->beta <= 0.0f || cfg->t0_kelvin <= 0.0f) {
        return ESP_ERR_INVALID_ARG;
    }

    adc_unit_t unit_id;
    if (adc_oneshot_io_to_channel(gpio_num, &unit_id, &s_channel) != ESP_OK) {
        HAL_LOGE(TAG, "GPIO %d is not a valid ADC pin", gpio_num);
        return ESP_ERR_INVALID_ARG;
    }

    adc_oneshot_unit_init_cfg_t unit_cfg = {
        .unit_id = unit_id,
    };
    esp_err_t err = adc_oneshot_new_unit(&unit_cfg, &s_adc);
    if (err != ESP_OK) {
        return err;
    }

    adc_oneshot_chan_cfg_t chan_cfg = {
        .bitwidth = ADC_BITWIDTH_DEFAULT,
        .atten = ADC_ATTEN_DB_12,
    };
    err = adc_oneshot_config_channel(s_adc, s_channel, &chan_cfg);
    if (err != ESP_OK) {
        adc_oneshot_del_unit(s_adc);
        s_adc = NULL;
        return err;
    }

    s_cfg = *cfg;
    s_inited = true;
    HAL_LOGI(TAG, "NTC on GPIO %d (ADC unit %d)", gpio_num, (int)unit_id);
    return ESP_OK;
}

esp_err_t driver_ntc_read_raw(int *out_raw)
{
    if (!s_inited || s_adc == NULL || out_raw == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    return adc_oneshot_read(s_adc, s_channel, out_raw);
}

esp_err_t driver_ntc_read_temperature_c(float *out_temp_c)
{
    if (out_temp_c == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    int raw = 0;
    esp_err_t err = driver_ntc_read_raw(&raw);
    if (err != ESP_OK) {
        return err;
    }

    if (raw <= 0 || raw >= 4095) {
        return ESP_ERR_INVALID_RESPONSE;
    }

    // 假设分压：Vout = Vcc * Rntc / (R_fixed + Rntc)
    float ratio = (float)raw / (4095.0f - (float)raw);
    float r_ntc = s_cfg.r_fixed_ohm * ratio;

    float inv_t = (1.0f / s_cfg.t0_kelvin) + (1.0f / s_cfg.beta) * logf(r_ntc / s_cfg.r_ntc_nominal_ohm);
    float temp_k = 1.0f / inv_t;
    *out_temp_c = temp_k - 273.15f;
    return ESP_OK;
}
