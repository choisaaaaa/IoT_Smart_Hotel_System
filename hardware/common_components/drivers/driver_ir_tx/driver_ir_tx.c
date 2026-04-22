#include "driver_ir_tx.h"
#include "hal_log.h"
#include "driver/gpio.h"
#include "esp_rom_sys.h"

static const char *TAG = "DRIVER_IR_TX";

static bool s_inited = false;
static int s_pin = -1;

// 38kHz 半周期约 13us
static inline void carrier_half_cycle(void)
{
    gpio_set_level(s_pin, 1);
    esp_rom_delay_us(13);
    gpio_set_level(s_pin, 0);
    esp_rom_delay_us(13);
}

static void send_mark_us(int duration_us)
{
    int elapsed = 0;
    while (elapsed < duration_us) {
        carrier_half_cycle();
        elapsed += 26;
    }
}

static void send_space_us(int duration_us)
{
    gpio_set_level(s_pin, 0);
    esp_rom_delay_us((uint32_t)duration_us);
}

static void send_nec_bit(bool bit1)
{
    send_mark_us(560);
    send_space_us(bit1 ? 1690 : 560);
}

esp_err_t driver_ir_tx_init(int gpio_num)
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

    s_pin = gpio_num;
    gpio_set_level(s_pin, 0);
    s_inited = true;
    HAL_LOGI(TAG, "IR TX initialized on GPIO %d", gpio_num);
    return ESP_OK;
}

esp_err_t driver_ir_tx_send_38khz_burst_us(uint32_t duration_us)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    if (duration_us == 0) {
        gpio_set_level(s_pin, 0);
        return ESP_OK;
    }
    send_mark_us((int)duration_us);
    gpio_set_level(s_pin, 0);
    return ESP_OK;
}

esp_err_t driver_ir_tx_send_nec(uint8_t addr, uint8_t cmd)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }

    uint8_t bytes[4] = {addr, (uint8_t)~addr, cmd, (uint8_t)~cmd};

    // NEC 引导码
    send_mark_us(9000);
    send_space_us(4500);

    // LSB first
    for (int i = 0; i < 4; i++) {
        for (int b = 0; b < 8; b++) {
            bool bit1 = ((bytes[i] >> b) & 0x01) != 0;
            send_nec_bit(bit1);
        }
    }

    // 结束位
    send_mark_us(560);
    send_space_us(0);
    return ESP_OK;
}
