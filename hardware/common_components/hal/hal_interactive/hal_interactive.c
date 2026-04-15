#include "hal_interactive.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "global_config.h"

static const char *TAG = "HAL_INTERACTIVE";
static const TickType_t k_button_debounce_ticks = pdMS_TO_TICKS(30);

// 定义6个按键引脚，按 interactive_button_id_t 枚举顺序
static const int button_pins[] = {
    GLOBAL_PTT_BTN_PIN,      // 0: 客房呼叫前台
    GLOBAL_BTN_ROOM_1_PIN,   // 1: 客房SOS
    GLOBAL_BTN_ROOM_2_PIN,   // 2: 客房场景
    GLOBAL_BTN_FRONT_1_PIN,  // 3: 前台消音
    GLOBAL_BTN_FRONT_2_PIN,  // 4: 前台广播
    GLOBAL_BTN_FLOOR_1_PIN   // 5: 楼道报警
};
#define NUM_BUTTONS (sizeof(button_pins) / sizeof(button_pins[0]))
static bool s_debounced_pressed[NUM_BUTTONS] = {0};
static TickType_t s_last_change_tick[NUM_BUTTONS] = {0};
static int s_last_raw_level[NUM_BUTTONS] = {1, 1, 1, 1, 1, 1};

esp_err_t hal_interactive_init(void) {
    ESP_LOGI(TAG, "初始化交互设备 (按键、RGB灯带、蜂鸣器)");

    // 初始化 6个独立按键
    for (int i = 0; i < NUM_BUTTONS; i++) {
        int pin = button_pins[i];
        if (pin >= 0) {
            gpio_config_t btn_cfg = {
                .pin_bit_mask = (1ULL << pin),
                .mode = GPIO_MODE_INPUT,
                // 根据文档，大部分建议外部上拉。安全起见，这里打开内部上拉
                .pull_up_en = GPIO_PULLUP_ENABLE,
                .pull_down_en = GPIO_PULLDOWN_DISABLE,
                .intr_type = GPIO_INTR_DISABLE,
            };
            esp_err_t err = gpio_config(&btn_cfg);
            if (err != ESP_OK) {
                ESP_LOGE(TAG, "按键 GPIO%d 配置失败: %s", pin, esp_err_to_name(err));
                return err;
            }

            s_last_raw_level[i] = gpio_get_level(pin);
            s_debounced_pressed[i] = (s_last_raw_level[i] == 0);
            s_last_change_tick[i] = xTaskGetTickCount();
        }
    }

    // 可在此处追加初始化 driver_rgb_led 或 driver_buzzer_active 等
    
    return ESP_OK;
}

esp_err_t hal_interactive_beep(uint8_t count, uint32_t duration_ms) {
    ESP_LOGI(TAG, "蜂鸣器鸣叫: 共 %d 次，时长 %d ms", count, duration_ms);
    // 这里仅做简单占位输出。如果连接了 driver_buzzer_active，直接调用它
    // 简单实现为了不依赖太多多余代码，避免过度复杂逻辑
    for (int i = 0; i < count; i++) {
        // gpio_set_level(GLOBAL_BUZZER_PIN, 1);
        vTaskDelay(pdMS_TO_TICKS(duration_ms));
        // gpio_set_level(GLOBAL_BUZZER_PIN, 0);
        vTaskDelay(pdMS_TO_TICKS(50));
    }
    return ESP_OK;
}

esp_err_t hal_interactive_set_led_color(uint16_t led_index, uint8_t r, uint8_t g, uint8_t b) {
    ESP_LOGI(TAG, "RGB LED 墙: Index %d 设置为 (%d, %d, %d)", led_index, r, g, b);
    // TODO: 结合实际 WS2812 或普通 RGB 模块进行写入
    return ESP_OK;
}

bool hal_interactive_is_button_pressed(interactive_button_id_t button) {
    if ((int)button < 0 || (size_t)button >= NUM_BUTTONS) {
        return false;
    }
    
    int pin = button_pins[button];
    if (pin < 0) {
        return false;
    }

    int raw_level = gpio_get_level(pin);
    TickType_t now = xTaskGetTickCount();

    if (raw_level != s_last_raw_level[button]) {
        s_last_raw_level[button] = raw_level;
        s_last_change_tick[button] = now;
    }

    if ((now - s_last_change_tick[button]) >= k_button_debounce_ticks) {
        // 所有按键均规定为“低电平有效”，按下时读取到 0
        s_debounced_pressed[button] = (s_last_raw_level[button] == 0);
    }

    return s_debounced_pressed[button];
}
