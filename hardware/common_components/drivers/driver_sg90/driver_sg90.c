#include "driver_sg90.h"
#include "hal_log.h"
#include "driver/ledc.h"

static const char *TAG = "DRIVER_SG90";

// 使用 LEDC 的低速模式和通道 0
#define SG90_LEDC_MODE       LEDC_LOW_SPEED_MODE
#define SG90_LEDC_CHANNEL    LEDC_CHANNEL_0
#define SG90_LEDC_TIMER      LEDC_TIMER_0
// SG90 需要 50Hz 的 PWM 频率 (周期 20ms)
#define SG90_LEDC_DUTY_RES   LEDC_TIMER_13_BIT // 13位分辨率 (0 ~ 8191)
#define SG90_LEDC_FREQUENCY  (50)

// 占空比计算：
// 20ms = 8192
// 0度 = 0.5ms = 2.5% = 205
// 180度 = 2.5ms = 12.5% = 1024
#define SG90_DUTY_MIN        205
#define SG90_DUTY_MAX        1024

static bool is_initialized = false;

esp_err_t driver_sg90_init(int servo_pin) {
    if (is_initialized) return ESP_OK;

    HAL_LOGI(TAG, "Initializing SG90 Servo on GPIO %d...", servo_pin);

    // 1. 配置 LEDC 定时器
    ledc_timer_config_t ledc_timer = {
        .speed_mode       = SG90_LEDC_MODE,
        .timer_num        = SG90_LEDC_TIMER,
        .duty_resolution  = SG90_LEDC_DUTY_RES,
        .freq_hz          = SG90_LEDC_FREQUENCY,
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ESP_ERROR_CHECK(ledc_timer_config(&ledc_timer));

    // 2. 配置 LEDC 通道
    ledc_channel_config_t ledc_channel = {
        .speed_mode     = SG90_LEDC_MODE,
        .channel        = SG90_LEDC_CHANNEL,
        .timer_sel      = SG90_LEDC_TIMER,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = servo_pin,
        .duty           = SG90_DUTY_MIN, // 默认回到 0 度位置
        .hpoint         = 0
    };
    ESP_ERROR_CHECK(ledc_channel_config(&ledc_channel));

    is_initialized = true;
    HAL_LOGI(TAG, "SG90 Servo Initialized and set to 0 degrees.");
    return ESP_OK;
}

esp_err_t driver_sg90_set_angle(int angle) {
    if (!is_initialized) {
        HAL_LOGE(TAG, "SG90 is not initialized!");
        return ESP_FAIL;
    }

    if (angle < 0 || angle > 180) {
        HAL_LOGW(TAG, "Invalid angle %d. Must be between 0 and 180.", angle);
        return ESP_ERR_INVALID_ARG;
    }

    // 将角度 (0~180) 线性映射到占空比 (205~1024)
    uint32_t duty = SG90_DUTY_MIN + (angle * (SG90_DUTY_MAX - SG90_DUTY_MIN)) / 180;

    HAL_LOGI(TAG, "Setting SG90 to %d degrees (Duty: %lu)", angle, duty);

    // 设置并更新占空比
    ESP_ERROR_CHECK(ledc_set_duty(SG90_LEDC_MODE, SG90_LEDC_CHANNEL, duty));
    ESP_ERROR_CHECK(ledc_update_duty(SG90_LEDC_MODE, SG90_LEDC_CHANNEL));

    return ESP_OK;
}
