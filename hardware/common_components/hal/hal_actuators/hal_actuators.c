#include "hal_actuators.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "global_config.h"

static const char *TAG = "HAL_ACTUATORS";
static bool s_relay_active_low = true;

// 配置数组，按 actuator_type_t 顺序映射
static const int relay_pins[] = {
    GLOBAL_RELAY_CH1_PIN,
    GLOBAL_RELAY_CH2_PIN,
    GLOBAL_RELAY_CH3_PIN,
    GLOBAL_RELAY_CH4_PIN
};

static int relay_level_from_state(bool state_on)
{
    if (s_relay_active_low) {
        return state_on ? 0 : 1;
    }
    return state_on ? 1 : 0;
}

esp_err_t hal_actuators_init(void) {
    ESP_LOGI(TAG, "初始化 4路继电器控制");

    for (int i = 0; i < 4; i++) {
        int pin = relay_pins[i];
        if (pin >= 0) {
            gpio_config_t cfg = {
                .pin_bit_mask = (1ULL << pin),
                .mode = GPIO_MODE_OUTPUT,
                .pull_up_en = GPIO_PULLUP_DISABLE,
                .pull_down_en = GPIO_PULLDOWN_DISABLE,
                .intr_type = GPIO_INTR_DISABLE,
            };
            esp_err_t err = gpio_config(&cfg);
            if (err != ESP_OK) {
                ESP_LOGE(TAG, "继电器 GPIO%d 配置失败: %s", pin, esp_err_to_name(err));
                return err;
            }

            // 默认关闭继电器，按当前有效电平策略计算 GPIO 电平
            err = gpio_set_level(pin, relay_level_from_state(false));
            if (err != ESP_OK) {
                ESP_LOGE(TAG, "继电器 GPIO%d 默认电平设置失败: %s", pin, esp_err_to_name(err));
                return err;
            }
        }
    }
    return ESP_OK;
}

esp_err_t hal_actuators_set_state(actuator_type_t type, bool state) {
    if (type < ACTUATOR_RELAY_CH1 || type > ACTUATOR_RELAY_CH4) {
        ESP_LOGE(TAG, "未知的继电器通道: %d", type);
        return ESP_ERR_INVALID_ARG;
    }

    int pin = relay_pins[type];
    if (pin < 0) {
        return ESP_ERR_NOT_SUPPORTED;
    }

    int level = relay_level_from_state(state);
    esp_err_t err = gpio_set_level(pin, level);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "继电器 CH%d(GPIO %d) 设置失败: %s", type + 1, pin, esp_err_to_name(err));
        return err;
    }
    
    ESP_LOGI(TAG, "设置继电器 CH%d (GPIO %d) -> %s", type + 1, pin, state ? "ON" : "OFF");
    return ESP_OK;
}

void hal_actuators_set_active_level(bool active_low)
{
    s_relay_active_low = active_low;
    ESP_LOGI(TAG, "继电器有效电平已更新: %s", active_low ? "LOW_ACTIVE" : "HIGH_ACTIVE");
}
