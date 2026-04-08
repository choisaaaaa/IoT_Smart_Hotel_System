#include "hal_actuators.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "global_config.h"

static const char *TAG = "HAL_ACTUATORS";

// 配置数组，按 actuator_type_t 顺序映射
static const int relay_pins[] = {
    GLOBAL_RELAY_CH1_PIN,
    GLOBAL_RELAY_CH2_PIN,
    GLOBAL_RELAY_CH3_PIN,
    GLOBAL_RELAY_CH4_PIN
};

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
            gpio_config(&cfg);
            // 继电器默认关闭 (低有效控制时，输出高电平断开)
            // 假设默认继电器模块是低电平有效，初始化时拉高
            gpio_set_level(pin, 1);
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

    // 假设继电器为低电平吸合(Active Low): state=true 时输出0, state=false 时输出1
    int level = state ? 0 : 1;
    gpio_set_level(pin, level);
    
    ESP_LOGI(TAG, "设置继电器 CH%d (GPIO %d) -> %s", type + 1, pin, state ? "ON" : "OFF");
    return ESP_OK;
}
