#include "driver_relay.h"
#include "hal_log.h"
#include "driver/gpio.h"

static const char *TAG = "DRIVER_RELAY";

static bool s_inited = false;
static int s_gpio = -1;
static bool s_on = false;
static driver_relay_active_level_t s_active = DRIVER_RELAY_ACTIVE_HIGH;

static int to_gpio_level(bool on)
{
    if (s_active == DRIVER_RELAY_ACTIVE_LOW) {
        return on ? 0 : 1;
    }
    return on ? 1 : 0;
}

esp_err_t driver_relay_init(int gpio_num, driver_relay_active_level_t active_level, bool default_on)
{
    if (gpio_num < 0) {
        return ESP_ERR_INVALID_ARG;
    }

    gpio_config_t cfg = {
        .pin_bit_mask = 1ULL << gpio_num,
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&cfg);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "gpio_config failed: %s", esp_err_to_name(err));
        return err;
    }

    s_gpio = gpio_num;
    s_active = active_level;
    s_on = default_on;
    s_inited = true;
    gpio_set_level(s_gpio, to_gpio_level(s_on));
    HAL_LOGI(TAG, "Relay init GPIO=%d active=%d default_on=%d", gpio_num, (int)active_level, default_on ? 1 : 0);
    return ESP_OK;
}

esp_err_t driver_relay_set(bool on)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    s_on = on;
    return gpio_set_level(s_gpio, to_gpio_level(on));
}

esp_err_t driver_relay_toggle(void)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    return driver_relay_set(!s_on);
}

esp_err_t driver_relay_get(bool *out_on)
{
    if (!s_inited || out_on == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    *out_on = s_on;
    return ESP_OK;
}
