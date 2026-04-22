#include "driver_ldr.h"
#include "driver_adc_shared.h"
#include "hal_log.h"
#include "esp_adc/adc_oneshot.h"

static const char *TAG = "DRIVER_LDR";

static adc_oneshot_unit_handle_t s_adc = NULL;
static adc_channel_t s_channel;
static adc_unit_t s_unit = ADC_UNIT_1;
static bool s_inited = false;

esp_err_t driver_ldr_init(int gpio_num)
{
    if (s_inited) {
        return ESP_OK;
    }

    adc_unit_t unit_id;
    if (adc_oneshot_io_to_channel(gpio_num, &unit_id, &s_channel) != ESP_OK) {
        HAL_LOGE(TAG, "GPIO %d is not a valid ADC pin", gpio_num);
        return ESP_ERR_INVALID_ARG;
    }

    esp_err_t err = driver_adc_shared_acquire(unit_id, &s_adc);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "adc_shared_acquire failed: %s", esp_err_to_name(err));
        return err;
    }
    s_unit = unit_id;

    adc_oneshot_chan_cfg_t chan_cfg = {
        .bitwidth = ADC_BITWIDTH_DEFAULT,
        .atten = ADC_ATTEN_DB_12,
    };
    err = adc_oneshot_config_channel(s_adc, s_channel, &chan_cfg);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "adc_oneshot_config_channel failed: %s", esp_err_to_name(err));
        driver_adc_shared_release(s_unit);
        s_adc = NULL;
        return err;
    }

    s_inited = true;
    HAL_LOGI(TAG, "LDR on GPIO %d (ADC unit %d)", gpio_num, (int)unit_id);
    return ESP_OK;
}

esp_err_t driver_ldr_read_raw(int *out_raw)
{
    if (!s_inited || s_adc == NULL || out_raw == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    return adc_oneshot_read(s_adc, s_channel, out_raw);
}

esp_err_t driver_ldr_read_percent(int *out_percent)
{
    if (out_percent == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    int raw = 0;
    esp_err_t err = driver_ldr_read_raw(&raw);
    if (err != ESP_OK) {
        return err;
    }
    if (raw < 0) {
        raw = 0;
    }
    *out_percent = (raw * 100) / 4095;
    if (*out_percent > 100) {
        *out_percent = 100;
    }
    return ESP_OK;
}
