#include "hal_canopy.h"
#include "global_config.h"
#include "driver_sg90.h"
#include "driver/gpio.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

static const char *TAG = "HAL_CANOPY";

#ifndef GLOBAL_CANOPY_DEBOUNCE_SAMPLES
#define GLOBAL_CANOPY_DEBOUNCE_SAMPLES 5
#endif

static SemaphoreHandle_t s_mtx;
static bool s_have_servo;
static bool s_have_rain;
static bool s_auto = true;
static int s_angle = GLOBAL_CANOPY_ANGLE_RETRACT_DEG;
static bool s_rain_stable = false;
static uint8_t s_raw_agree_count;
static bool s_last_raw_rain;

static bool read_raw_rain(void)
{
#if GLOBAL_RAIN_SENSOR_DO_PIN < 0
    return false;
#else
    int lvl = gpio_get_level(GLOBAL_RAIN_SENSOR_DO_PIN);
#if GLOBAL_RAIN_SENSOR_ACTIVE_LOW
    return lvl == 0;
#else
    return lvl != 0;
#endif
#endif
}

static esp_err_t apply_angle(int angle)
{
    if (!s_have_servo) {
        return ESP_ERR_INVALID_STATE;
    }
    if (angle < 0) {
        angle = 0;
    }
    if (angle > 180) {
        angle = 180;
    }
    esp_err_t err = driver_sg90_set_angle(angle);
    if (err == ESP_OK) {
        s_angle = angle;
    }
    return err;
}

static void update_debounce_and_policy(void)
{
#if GLOBAL_RAIN_SENSOR_DO_PIN < 0
    return;
#endif
    if (!s_have_rain) {
        return;
    }

    bool raw = read_raw_rain();
    if (raw == s_last_raw_rain) {
        if (s_raw_agree_count < 255) {
            s_raw_agree_count++;
        }
    } else {
        s_last_raw_rain = raw;
        s_raw_agree_count = 1;
    }

    if (s_raw_agree_count < GLOBAL_CANOPY_DEBOUNCE_SAMPLES) {
        return;
    }

    if (raw == s_rain_stable) {
        return;
    }

    s_rain_stable = raw;
    ESP_LOGI(TAG, "雨量状态稳定: %s", s_rain_stable ? "有雨" : "无雨");

    if (!s_auto || !s_have_servo) {
        return;
    }

    if (s_rain_stable) {
        (void)apply_angle(GLOBAL_CANOPY_ANGLE_EXTEND_DEG);
    } else {
        (void)apply_angle(GLOBAL_CANOPY_ANGLE_RETRACT_DEG);
    }
}

esp_err_t hal_canopy_init(void)
{
    if (s_mtx == NULL) {
        s_mtx = xSemaphoreCreateMutex();
        if (s_mtx == NULL) {
            return ESP_ERR_NO_MEM;
        }
    }

    s_have_servo = (GLOBAL_CANOPY_SERVO_PIN >= 0);
    s_have_rain = (GLOBAL_RAIN_SENSOR_DO_PIN >= 0);

    if (s_have_servo) {
        esp_err_t err = driver_sg90_init(GLOBAL_CANOPY_SERVO_PIN);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "舵机初始化失败: %s", esp_err_to_name(err));
            s_have_servo = false;
        } else {
            (void)apply_angle(GLOBAL_CANOPY_ANGLE_RETRACT_DEG);
            ESP_LOGI(TAG, "雨棚舵机: GPIO%d (SG90 PWM)", GLOBAL_CANOPY_SERVO_PIN);
        }
    } else {
        ESP_LOGI(TAG, "雨棚舵机未启用 (GLOBAL_CANOPY_SERVO_PIN<0)");
    }

#if GLOBAL_RAIN_SENSOR_DO_PIN >= 0
    gpio_config_t io = {
        .pin_bit_mask = 1ULL << (unsigned)GLOBAL_RAIN_SENSOR_DO_PIN,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&io);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "雨量 DO 引脚配置失败: %s", esp_err_to_name(err));
        s_have_rain = false;
    } else {
        s_last_raw_rain = read_raw_rain();
        s_raw_agree_count = 1;
        s_rain_stable = s_last_raw_rain;
        ESP_LOGI(TAG, "雨量传感器 DO: GPIO%d (%s)",
                 GLOBAL_RAIN_SENSOR_DO_PIN,
#if GLOBAL_RAIN_SENSOR_ACTIVE_LOW
                 "有雨=低电平");
#else
                 "有雨=高电平");
#endif
    }
#else
    ESP_LOGI(TAG, "雨量传感器未启用 (GLOBAL_RAIN_SENSOR_DO_PIN<0)");
#endif

    return ESP_OK;
}

void hal_canopy_poll(void)
{
    if (s_mtx == NULL) {
        return;
    }
    if (xSemaphoreTake(s_mtx, pdMS_TO_TICKS(50)) != pdTRUE) {
        return;
    }
    update_debounce_and_policy();
    xSemaphoreGive(s_mtx);
}

bool hal_canopy_get_auto(void)
{
    return s_auto;
}

void hal_canopy_set_auto(bool enabled)
{
    if (s_mtx == NULL) {
        return;
    }
    if (xSemaphoreTake(s_mtx, pdMS_TO_TICKS(50)) != pdTRUE) {
        return;
    }
    s_auto = enabled;
    if (s_auto && s_have_servo && s_have_rain) {
        if (s_rain_stable) {
            (void)apply_angle(GLOBAL_CANOPY_ANGLE_EXTEND_DEG);
        } else {
            (void)apply_angle(GLOBAL_CANOPY_ANGLE_RETRACT_DEG);
        }
    }
    xSemaphoreGive(s_mtx);
}

bool hal_canopy_is_raining(void)
{
    return s_rain_stable;
}

int hal_canopy_get_angle(void)
{
    return s_angle;
}

esp_err_t hal_canopy_manual_extend(void)
{
    if (s_mtx == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    if (xSemaphoreTake(s_mtx, pdMS_TO_TICKS(200)) != pdTRUE) {
        return ESP_ERR_TIMEOUT;
    }
    s_auto = false;
    esp_err_t err = apply_angle(GLOBAL_CANOPY_ANGLE_EXTEND_DEG);
    xSemaphoreGive(s_mtx);
    return err;
}

esp_err_t hal_canopy_manual_retract(void)
{
    if (s_mtx == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    if (xSemaphoreTake(s_mtx, pdMS_TO_TICKS(200)) != pdTRUE) {
        return ESP_ERR_TIMEOUT;
    }
    s_auto = false;
    esp_err_t err = apply_angle(GLOBAL_CANOPY_ANGLE_RETRACT_DEG);
    xSemaphoreGive(s_mtx);
    return err;
}
