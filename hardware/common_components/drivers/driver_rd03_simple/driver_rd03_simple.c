#include "driver_rd03_simple.h"
#include "hal_log.h"
#include "driver/gpio.h"

static const char *TAG = "RD03_SIMPLE";

static bool s_inited = false;
static int s_gpio = -1;

esp_err_t driver_rd03_simple_init(int gpio_ot2)
{
    if (gpio_ot2 < 0) {
        return ESP_ERR_INVALID_ARG;
    }
    s_gpio = gpio_ot2;

    gpio_config_t io = {
        .pin_bit_mask = 1ULL << gpio_ot2,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&io);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "gpio_config failed: %s", esp_err_to_name(err));
        return err;
    }
    s_inited = true;
    HAL_LOGI(TAG, "RD-03 simple (OT2) on GPIO %d, active-high=present", gpio_ot2);
    return ESP_OK;
}

esp_err_t driver_rd03_simple_read(bool *out_present)
{
    if (!s_inited || s_gpio < 0 || out_present == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    *out_present = (gpio_get_level(s_gpio) == 1);
    return ESP_OK;
}
