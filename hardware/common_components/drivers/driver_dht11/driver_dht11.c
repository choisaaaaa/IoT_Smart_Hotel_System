#include "driver_dht11.h"
#include "hal_log.h"
#include "driver/gpio.h"
#include "esp_timer.h"
#include "esp_rom_sys.h"
#include "esp_check.h"

static const char *TAG = "DRIVER_DHT11";

static bool s_inited = false;
static int s_pin = -1;
static int64_t s_last_read_us = 0;

static void set_pin_output(void)
{
    gpio_set_direction(s_pin, GPIO_MODE_OUTPUT_OD);
}

static void set_pin_input(void)
{
    gpio_set_direction(s_pin, GPIO_MODE_INPUT);
}

static esp_err_t wait_level(int level, int timeout_us, int *elapsed_us)
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

esp_err_t driver_dht11_init(int gpio_num)
{
    if (gpio_num < 0) {
        return ESP_ERR_INVALID_ARG;
    }

    s_pin = gpio_num;
    gpio_config_t cfg = {
        .pin_bit_mask = 1ULL << gpio_num,
        .mode = GPIO_MODE_INPUT_OUTPUT_OD,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&cfg);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "gpio_config failed: %s", esp_err_to_name(err));
        return err;
    }

    set_pin_input();
    s_last_read_us = 0;
    s_inited = true;
    HAL_LOGI(TAG, "DHT11 initialized on GPIO %d", gpio_num);
    return ESP_OK;
}

esp_err_t driver_dht11_read(driver_dht11_data_t *out_data)
{
    if (!s_inited || out_data == NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    // DHT11 建议采样周期 >= 1s
    int64_t now = esp_timer_get_time();
    if (s_last_read_us > 0 && (now - s_last_read_us) < 1000000) {
        return ESP_ERR_INVALID_STATE;
    }

    uint8_t bytes[5] = {0};

    // 主机起始信号：拉低 >=18ms，再拉高 20~40us
    set_pin_output();
    gpio_set_level(s_pin, 0);
    esp_rom_delay_us(20000);
    gpio_set_level(s_pin, 1);
    esp_rom_delay_us(30);
    set_pin_input();

    // 传感器响应：低 ~80us + 高 ~80us
    ESP_RETURN_ON_ERROR(wait_level(1, 120, NULL), TAG, "response low timeout");
    ESP_RETURN_ON_ERROR(wait_level(0, 120, NULL), TAG, "response high timeout");

    // 读取 40bit：每 bit 先低电平 ~50us，再高电平（26~28us=0, ~70us=1）
    for (int i = 0; i < 40; i++) {
        int high_us = 0;
        ESP_RETURN_ON_ERROR(wait_level(1, 100, NULL), TAG, "bit low timeout");
        ESP_RETURN_ON_ERROR(wait_level(0, 120, &high_us), TAG, "bit high timeout");

        int byte_idx = i / 8;
        bytes[byte_idx] <<= 1;
        if (high_us > 50) {
            bytes[byte_idx] |= 1;
        }
    }

    uint8_t checksum = (uint8_t)(bytes[0] + bytes[1] + bytes[2] + bytes[3]);
    if (checksum != bytes[4]) {
        HAL_LOGW(TAG, "checksum mismatch calc=%u recv=%u", checksum, bytes[4]);
        return ESP_ERR_INVALID_CRC;
    }

    // DHT11 小数位通常为 0
    out_data->humidity_percent = (float)bytes[0];
    out_data->temperature_c = (float)bytes[2];
    s_last_read_us = esp_timer_get_time();
    return ESP_OK;
}
