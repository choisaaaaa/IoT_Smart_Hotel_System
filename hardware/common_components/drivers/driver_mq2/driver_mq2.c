#include "driver_mq2.h"
#include "hal_log.h"
#include "esp_adc/adc_oneshot.h"
#include "driver/gpio.h"

static const char *TAG = "DRIVER_MQ2";

static adc_oneshot_unit_handle_t s_adc = NULL;
static adc_channel_t s_channel;
static bool s_inited = false;
static int s_do_gpio = -1;

esp_err_t driver_mq2_init(int adc_gpio, int digital_gpio)
{
    if (s_inited) {
        return ESP_OK;
    }

    adc_unit_t unit_id;
    if (adc_oneshot_io_to_channel(adc_gpio, &unit_id, &s_channel) != ESP_OK) {
        HAL_LOGE(TAG, "GPIO %d is not a valid ADC pin", adc_gpio);
        return ESP_ERR_INVALID_ARG;
    }

    adc_oneshot_unit_init_cfg_t unit_cfg = {
        .unit_id = unit_id,
    };
    esp_err_t err = adc_oneshot_new_unit(&unit_cfg, &s_adc);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "adc_oneshot_new_unit failed: %s", esp_err_to_name(err));
        return err;
    }

    adc_oneshot_chan_cfg_t chan_cfg = {
        .bitwidth = ADC_BITWIDTH_DEFAULT,
        .atten = ADC_ATTEN_DB_12,
    };
    err = adc_oneshot_config_channel(s_adc, s_channel, &chan_cfg);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "adc_oneshot_config_channel failed: %s", esp_err_to_name(err));
        adc_oneshot_del_unit(s_adc);
        s_adc = NULL;
        return err;
    }

    if (digital_gpio >= 0) {
        gpio_config_t do_cfg = {
            .pin_bit_mask = 1ULL << digital_gpio,
            .mode = GPIO_MODE_INPUT,
            .pull_up_en = GPIO_PULLUP_DISABLE,
            .pull_down_en = GPIO_PULLDOWN_DISABLE,
            .intr_type = GPIO_INTR_DISABLE,
        };
        err = gpio_config(&do_cfg);
        if (err != ESP_OK) {
            HAL_LOGE(TAG, "DO gpio_config failed: %s", esp_err_to_name(err));
            adc_oneshot_del_unit(s_adc);
            s_adc = NULL;
            return err;
        }
        s_do_gpio = digital_gpio;
    }

    s_inited = true;
    HAL_LOGI(TAG, "MQ-2 init AO=%d (ADC unit %d), DO=%d", adc_gpio, (int)unit_id, digital_gpio);
    return ESP_OK;
}

esp_err_t driver_mq2_read_raw(int *out_raw)
{
    if (!s_inited || s_adc == NULL || out_raw == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    return adc_oneshot_read(s_adc, s_channel, out_raw);
}

esp_err_t driver_mq2_read_percent(int *out_percent)
{
    if (out_percent == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    int raw = 0;
    esp_err_t err = driver_mq2_read_raw(&raw);
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

esp_err_t driver_mq2_read_alarm(bool *out_alarm)
{
    if (!s_inited || out_alarm == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    if (s_do_gpio < 0) {
        return ESP_ERR_NOT_SUPPORTED;
    }

    // 常见 MQ 模块 DO 低电平表示超过阈值（告警）
    int level = gpio_get_level(s_do_gpio);
    *out_alarm = (level == 0);
    return ESP_OK;
}
