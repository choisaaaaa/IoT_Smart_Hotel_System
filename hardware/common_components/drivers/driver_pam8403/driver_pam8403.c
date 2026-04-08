#include "driver_pam8403.h"
#include "hal_log.h"
#include "driver/gpio.h"

static const char *TAG = "DRIVER_PAM8403";

static bool s_inited = false;
static int s_en_pin = -1;
static bool s_enabled = true;

esp_err_t driver_pam8403_init(int pin_enable)
{
    s_en_pin = pin_enable;
    if (pin_enable >= 0) {
        gpio_config_t cfg = {
            .pin_bit_mask = 1ULL << pin_enable,
            .mode = GPIO_MODE_OUTPUT,
            .pull_up_en = GPIO_PULLUP_DISABLE,
            .pull_down_en = GPIO_PULLDOWN_DISABLE,
            .intr_type = GPIO_INTR_DISABLE,
        };
        esp_err_t err = gpio_config(&cfg);
        if (err != ESP_OK) {
            HAL_LOGE(TAG, "EN gpio_config failed: %s", esp_err_to_name(err));
            return err;
        }
        gpio_set_level(pin_enable, 1);
    }
    s_enabled = true;
    s_inited = true;
    HAL_LOGI(TAG, "PAM8403 init EN pin=%d", pin_enable);
    return ESP_OK;
}

esp_err_t driver_pam8403_enable(bool enable)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    s_enabled = enable;
    if (s_en_pin >= 0) {
        return gpio_set_level(s_en_pin, enable ? 1 : 0);
    }
    return ESP_OK;
}

esp_err_t driver_pam8403_play_pcm8(const uint8_t *data, size_t len)
{
    if (!s_inited || !s_enabled || data == NULL || len == 0) {
        return ESP_ERR_INVALID_STATE;
    }
    // 基础占位：真实播放由上层 DAC/I2S->DAC 链路驱动
    (void)data;
    (void)len;
    return ESP_OK;
}
