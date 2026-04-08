#include "driver_buzzer_active.h"
#include "hal_log.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "DRIVER_BUZZER";

static bool s_inited = false;
static int s_gpio = -1;
static bool s_active_high = true;

static int on_level(void)
{
    return s_active_high ? 1 : 0;
}

static int off_level(void)
{
    return s_active_high ? 0 : 1;
}

esp_err_t driver_buzzer_active_init(int gpio_num, bool active_high)
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
    s_active_high = active_high;
    s_inited = true;
    gpio_set_level(s_gpio, off_level());
    HAL_LOGI(TAG, "Buzzer init GPIO=%d active_high=%d", gpio_num, active_high ? 1 : 0);
    return ESP_OK;
}

esp_err_t driver_buzzer_active_on(void)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    return gpio_set_level(s_gpio, on_level());
}

esp_err_t driver_buzzer_active_off(void)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    return gpio_set_level(s_gpio, off_level());
}

esp_err_t driver_buzzer_active_beep(uint8_t count, uint32_t duration_ms, uint32_t gap_ms)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    for (uint8_t i = 0; i < count; i++) {
        driver_buzzer_active_on();
        vTaskDelay(pdMS_TO_TICKS(duration_ms));
        driver_buzzer_active_off();
        if (i + 1 < count) {
            vTaskDelay(pdMS_TO_TICKS(gap_ms));
        }
    }
    return ESP_OK;
}
