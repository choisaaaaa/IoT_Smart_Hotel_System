#include "driver_ec11.h"
#include "hal_log.h"
#include "driver/gpio.h"

static const char *TAG = "DRIVER_EC11";

static bool s_inited = false;
static int s_pin_a = -1;
static int s_pin_b = -1;
static int s_pin_btn = -1;
static uint8_t s_prev_ab = 0;
static int s_step_acc = 0;
static int s_prev_btn_level = 1;

// 四相编码器状态转移表：每次合法跳变记 +/-1，累计到 +/-4 视为一步
static const int8_t s_quad_table[16] = {
    0, -1, 1, 0,
    1, 0, 0, -1,
    -1, 0, 0, 1,
    0, 1, -1, 0,
};

static uint8_t read_ab(void)
{
    int a = gpio_get_level(s_pin_a) ? 1 : 0;
    int b = gpio_get_level(s_pin_b) ? 1 : 0;
    return (uint8_t)((a << 1) | b);
}

esp_err_t driver_ec11_init(int pin_a, int pin_b, int pin_btn)
{
    if (pin_a < 0 || pin_b < 0) {
        return ESP_ERR_INVALID_ARG;
    }

    s_pin_a = pin_a;
    s_pin_b = pin_b;
    s_pin_btn = pin_btn;

    gpio_config_t ab_cfg = {
        .pin_bit_mask = (1ULL << pin_a) | (1ULL << pin_b),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&ab_cfg);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "AB gpio_config failed: %s", esp_err_to_name(err));
        return err;
    }

    if (pin_btn >= 0) {
        gpio_config_t btn_cfg = {
            .pin_bit_mask = (1ULL << pin_btn),
            .mode = GPIO_MODE_INPUT,
            .pull_up_en = GPIO_PULLUP_ENABLE,
            .pull_down_en = GPIO_PULLDOWN_DISABLE,
            .intr_type = GPIO_INTR_DISABLE,
        };
        err = gpio_config(&btn_cfg);
        if (err != ESP_OK) {
            HAL_LOGE(TAG, "BTN gpio_config failed: %s", esp_err_to_name(err));
            return err;
        }
    }

    s_prev_ab = read_ab();
    s_step_acc = 0;
    s_prev_btn_level = (pin_btn >= 0) ? gpio_get_level(pin_btn) : 1;
    s_inited = true;

    HAL_LOGI(TAG, "EC11 initialized A=%d B=%d BTN=%d", pin_a, pin_b, pin_btn);
    return ESP_OK;
}

esp_err_t driver_ec11_poll(driver_ec11_direction_t *out_dir, bool *out_btn_pressed)
{
    if (!s_inited || out_dir == NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    *out_dir = DRIVER_EC11_DIR_NONE;
    if (out_btn_pressed != NULL) {
        *out_btn_pressed = false;
    }

    uint8_t curr_ab = read_ab();
    uint8_t idx = (uint8_t)((s_prev_ab << 2) | curr_ab);
    s_step_acc += s_quad_table[idx];
    s_prev_ab = curr_ab;

    if (s_step_acc >= 4) {
        *out_dir = DRIVER_EC11_DIR_CW;
        s_step_acc = 0;
    } else if (s_step_acc <= -4) {
        *out_dir = DRIVER_EC11_DIR_CCW;
        s_step_acc = 0;
    }

    if (s_pin_btn >= 0 && out_btn_pressed != NULL) {
        int curr_btn = gpio_get_level(s_pin_btn);
        if (s_prev_btn_level == 1 && curr_btn == 0) {
            *out_btn_pressed = true;
        }
        s_prev_btn_level = curr_btn;
    }

    return ESP_OK;
}
