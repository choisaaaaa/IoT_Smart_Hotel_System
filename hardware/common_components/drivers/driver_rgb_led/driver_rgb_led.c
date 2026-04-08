#include "driver_rgb_led.h"
#include "hal_log.h"
#include "driver/ledc.h"

static const char *TAG = "DRIVER_RGB";

#define RGB_LEDC_MODE       LEDC_LOW_SPEED_MODE
#define RGB_LEDC_TIMER      LEDC_TIMER_1
#define RGB_LEDC_DUTY_RES   LEDC_TIMER_8_BIT
#define RGB_LEDC_FREQ_HZ    5000

#define RGB_CH_R            LEDC_CHANNEL_1
#define RGB_CH_G            LEDC_CHANNEL_2
#define RGB_CH_B            LEDC_CHANNEL_3

static bool s_inited = false;
static driver_rgb_led_type_t s_type = DRIVER_RGB_LED_COMMON_CATHODE;

static uint32_t map_brightness_to_duty(uint8_t value)
{
    if (s_type == DRIVER_RGB_LED_COMMON_ANODE) {
        return (uint32_t)(255 - value);
    }
    return (uint32_t)value;
}

static esp_err_t set_channel(ledc_channel_t ch, uint8_t value)
{
    uint32_t duty = map_brightness_to_duty(value);
    esp_err_t err = ledc_set_duty(RGB_LEDC_MODE, ch, duty);
    if (err != ESP_OK) {
        return err;
    }
    return ledc_update_duty(RGB_LEDC_MODE, ch);
}

esp_err_t driver_rgb_led_init(int pin_r, int pin_g, int pin_b, driver_rgb_led_type_t type)
{
    if (pin_r < 0 || pin_g < 0 || pin_b < 0) {
        return ESP_ERR_INVALID_ARG;
    }

    ledc_timer_config_t timer_cfg = {
        .speed_mode = RGB_LEDC_MODE,
        .timer_num = RGB_LEDC_TIMER,
        .duty_resolution = RGB_LEDC_DUTY_RES,
        .freq_hz = RGB_LEDC_FREQ_HZ,
        .clk_cfg = LEDC_AUTO_CLK,
    };
    esp_err_t err = ledc_timer_config(&timer_cfg);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "ledc_timer_config failed: %s", esp_err_to_name(err));
        return err;
    }

    ledc_channel_config_t ch_r = {
        .speed_mode = RGB_LEDC_MODE,
        .channel = RGB_CH_R,
        .timer_sel = RGB_LEDC_TIMER,
        .intr_type = LEDC_INTR_DISABLE,
        .gpio_num = pin_r,
        .duty = 0,
        .hpoint = 0,
    };
    ledc_channel_config_t ch_g = ch_r;
    ch_g.channel = RGB_CH_G;
    ch_g.gpio_num = pin_g;

    ledc_channel_config_t ch_b = ch_r;
    ch_b.channel = RGB_CH_B;
    ch_b.gpio_num = pin_b;

    err = ledc_channel_config(&ch_r);
    if (err != ESP_OK) return err;
    err = ledc_channel_config(&ch_g);
    if (err != ESP_OK) return err;
    err = ledc_channel_config(&ch_b);
    if (err != ESP_OK) return err;

    s_type = type;
    s_inited = true;
    HAL_LOGI(TAG, "RGB LED init R=%d G=%d B=%d type=%d", pin_r, pin_g, pin_b, (int)type);
    return driver_rgb_led_off();
}

esp_err_t driver_rgb_led_set_rgb(uint8_t r, uint8_t g, uint8_t b)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }

    esp_err_t err = set_channel(RGB_CH_R, r);
    if (err != ESP_OK) return err;
    err = set_channel(RGB_CH_G, g);
    if (err != ESP_OK) return err;
    return set_channel(RGB_CH_B, b);
}

esp_err_t driver_rgb_led_set_color_hex(uint32_t rgb_hex)
{
    uint8_t r = (uint8_t)((rgb_hex >> 16) & 0xFF);
    uint8_t g = (uint8_t)((rgb_hex >> 8) & 0xFF);
    uint8_t b = (uint8_t)(rgb_hex & 0xFF);
    return driver_rgb_led_set_rgb(r, g, b);
}

esp_err_t driver_rgb_led_off(void)
{
    return driver_rgb_led_set_rgb(0, 0, 0);
}
