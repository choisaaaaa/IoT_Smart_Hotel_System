#include "driver_ir_rx.h"
#include "hal_log.h"
#include "driver/gpio.h"
#include "esp_timer.h"

static const char *TAG = "DRIVER_IR_RX";

static bool s_inited = false;
static int s_pin = -1;

static esp_err_t wait_level_end(int level, int timeout_us, int *elapsed_us)
{
    int64_t start = esp_timer_get_time();
    while (gpio_get_level(s_pin) == level) {
        if ((esp_timer_get_time() - start) > timeout_us) {
            return ESP_ERR_TIMEOUT;
        }
    }
    if (elapsed_us != NULL) {
        *elapsed_us = (int)(esp_timer_get_time() - start);
    }
    return ESP_OK;
}

static bool in_range(int v, int min_v, int max_v)
{
    return v >= min_v && v <= max_v;
}

esp_err_t driver_ir_rx_init(int gpio_num)
{
    if (gpio_num < 0) {
        return ESP_ERR_INVALID_ARG;
    }

    gpio_config_t cfg = {
        .pin_bit_mask = 1ULL << gpio_num,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&cfg);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "gpio_config failed: %s", esp_err_to_name(err));
        return err;
    }

    s_pin = gpio_num;
    s_inited = true;
    HAL_LOGI(TAG, "IR RX initialized on GPIO %d", gpio_num);
    return ESP_OK;
}

int driver_ir_rx_demod_level(void)
{
    if (!s_inited) {
        return -1;
    }
    return gpio_get_level(s_pin);
}

esp_err_t driver_ir_rx_poll_nec(uint8_t *out_addr, uint8_t *out_cmd, bool *out_updated)
{
    if (!s_inited || out_addr == NULL || out_cmd == NULL || out_updated == NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    *out_updated = false;

    // 常见红外接收头空闲为高电平
    if (gpio_get_level(s_pin) == 1) {
        return ESP_OK;
    }

    int low_us = 0;
    int high_us = 0;

    // NEC 引导：低约 9ms + 高约 4.5ms
    if (wait_level_end(0, 12000, &low_us) != ESP_OK) {
        return ESP_ERR_TIMEOUT;
    }
    if (!in_range(low_us, 8000, 10000)) {
        return ESP_ERR_INVALID_RESPONSE;
    }

    if (wait_level_end(1, 7000, &high_us) != ESP_OK) {
        return ESP_ERR_TIMEOUT;
    }
    if (!in_range(high_us, 3500, 5500)) {
        return ESP_ERR_INVALID_RESPONSE;
    }

    uint8_t bytes[4] = {0};
    for (int i = 0; i < 32; i++) {
        int bit_low_us = 0;
        int bit_high_us = 0;

        if (wait_level_end(0, 1500, &bit_low_us) != ESP_OK) {
            return ESP_ERR_TIMEOUT;
        }
        if (!in_range(bit_low_us, 300, 900)) {
            return ESP_ERR_INVALID_RESPONSE;
        }

        if (wait_level_end(1, 2500, &bit_high_us) != ESP_OK) {
            return ESP_ERR_TIMEOUT;
        }

        bool bit1 = bit_high_us > 1000;
        int byte_idx = i / 8;
        int bit_idx = i % 8; // LSB first
        if (bit1) {
            bytes[byte_idx] |= (uint8_t)(1u << bit_idx);
        }
    }

    // NEC 反码校验
    if ((uint8_t)(bytes[0] ^ bytes[1]) != 0xFF || (uint8_t)(bytes[2] ^ bytes[3]) != 0xFF) {
        return ESP_ERR_INVALID_CRC;
    }

    *out_addr = bytes[0];
    *out_cmd = bytes[2];
    *out_updated = true;
    return ESP_OK;
}
