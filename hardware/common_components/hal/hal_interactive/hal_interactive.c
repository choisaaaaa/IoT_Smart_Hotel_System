#include "hal_interactive.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "global_config.h"
#include "driver_buzzer_active.h"
#include "driver_rgb_led.h"

static const char *TAG = "HAL_INTERACTIVE";
static const TickType_t k_button_debounce_ticks = pdMS_TO_TICKS(30);
static bool s_buzzer_ready = false;
static bool s_rgb_ready = false;

// 定义6个按键引脚，按 interactive_button_id_t 枚举顺序
static const int button_pins[] = {
    GLOBAL_PTT_BTN_PIN,      // 0: 客房 PTT（默认 GPIO1）
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

    if (GLOBAL_BUZZER_PIN < 0) {
        s_buzzer_ready = false;
        ESP_LOGI(TAG, "蜂鸣器未接入，已禁用");
    } else {
        esp_err_t buzzer_err =
            driver_buzzer_active_init(GLOBAL_BUZZER_PIN, GLOBAL_BUZZER_ACTIVE_HIGH != 0);
        if (buzzer_err != ESP_OK) {
            ESP_LOGE(TAG, "蜂鸣器初始化失败 GPIO%d: %s", GLOBAL_BUZZER_PIN, esp_err_to_name(buzzer_err));
            s_buzzer_ready = false;
        } else {
            s_buzzer_ready = true;
            ESP_LOGI(TAG, "蜂鸣器已就绪 GPIO%d", GLOBAL_BUZZER_PIN);
        }
    }

    if (GLOBAL_RGB_R_PIN < 0 || GLOBAL_RGB_G_PIN < 0 || GLOBAL_RGB_B_PIN < 0) {
        s_rgb_ready = false;
        ESP_LOGI(TAG, "RGB 氛围灯未接入 (R=%d G=%d B=%d)，已禁用",
                 (int)GLOBAL_RGB_R_PIN, (int)GLOBAL_RGB_G_PIN, (int)GLOBAL_RGB_B_PIN);
    } else {
        driver_rgb_led_type_t type = (GLOBAL_RGB_COMMON_ANODE != 0)
                                     ? DRIVER_RGB_LED_COMMON_ANODE
                                     : DRIVER_RGB_LED_COMMON_CATHODE;
        esp_err_t rgb_err = driver_rgb_led_init(GLOBAL_RGB_R_PIN,
                                                GLOBAL_RGB_G_PIN,
                                                GLOBAL_RGB_B_PIN,
                                                type);
        if (rgb_err != ESP_OK) {
            ESP_LOGE(TAG, "RGB 氛围灯初始化失败 R=%d G=%d B=%d: %s",
                     (int)GLOBAL_RGB_R_PIN, (int)GLOBAL_RGB_G_PIN, (int)GLOBAL_RGB_B_PIN,
                     esp_err_to_name(rgb_err));
            s_rgb_ready = false;
        } else {
            s_rgb_ready = true;
            ESP_LOGI(TAG, "RGB 氛围灯已就绪 R=%d G=%d B=%d %s",
                     (int)GLOBAL_RGB_R_PIN, (int)GLOBAL_RGB_G_PIN, (int)GLOBAL_RGB_B_PIN,
                     (type == DRIVER_RGB_LED_COMMON_ANODE) ? "共阳" : "共阴");
        }
    }

    return ESP_OK;
}

esp_err_t hal_interactive_beep(uint8_t count, uint32_t duration_ms) {
    ESP_LOGI(TAG, "蜂鸣器鸣叫: 共 %d 次，时长 %d ms", count, duration_ms);
    if (!s_buzzer_ready) {
        ESP_LOGW(TAG, "蜂鸣器未启用，跳过鸣叫");
        return ESP_OK;
    }
    return driver_buzzer_active_beep(count, duration_ms, 50);
}

esp_err_t hal_interactive_buzzer_steady(bool on) {
    if (!s_buzzer_ready) {
        return ESP_ERR_INVALID_STATE;
    }
    esp_err_t e = on ? driver_buzzer_active_on() : driver_buzzer_active_off();
    if (e == ESP_OK) {
        ESP_LOGI(TAG, "蜂鸣器常响: %s", on ? "开" : "关");
    }
    return e;
}

esp_err_t hal_interactive_set_led_color(uint16_t led_index, uint8_t r, uint8_t g, uint8_t b) {
    // 当前接线为 1 颗共阳/共阴三线 RGB，led_index 保留但忽略。
    // 若后续换成 WS2812 灯带，可在此按 index 写入到对应灯珠。
    (void)led_index;
    if (!s_rgb_ready) {
        ESP_LOGD(TAG, "RGB 未就绪，忽略 (%u,%u,%u)", r, g, b);
        return ESP_OK;
    }
    esp_err_t err = driver_rgb_led_set_rgb(r, g, b);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "RGB 写入失败 (%u,%u,%u): %s", r, g, b, esp_err_to_name(err));
    }
    return err;
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
