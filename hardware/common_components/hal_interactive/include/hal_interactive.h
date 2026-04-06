#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

// 定义常见的交互按键 ID
typedef enum {
    BTN_SOS = 0,         // SOS 报警按键 (客房/前台/楼控)
    BTN_CALL_FRONTDESK,  // 呼叫前台按键 (客房)
    BTN_CUSTOM_1         // 自定义按键 1
} interactive_button_id_t;

/**
 * @brief 初始化所有的声光交互外设 (RGB 状态灯墙, 蜂鸣器, 物理按键输入)
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t hal_interactive_init(void);

/**
 * @brief 蜂鸣器鸣叫指定次数 (用于刷卡反馈、报警等)
 * @param count 鸣叫次数
 * @param duration_ms 每次鸣叫持续时长(毫秒)
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t hal_interactive_beep(uint8_t count, uint32_t duration_ms);

/**
 * @brief 设置特定序号的 RGB 灯珠颜色 (支持 WS2812B 状态墙)
 * @param led_index 灯珠序号 (如前台端有8颗灯珠代表8间房，index为0-7)
 * @param r 红色分量 (0-255)
 * @param g 绿色分量 (0-255)
 * @param b 蓝色分量 (0-255)
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t hal_interactive_set_led_color(uint16_t led_index, uint8_t r, uint8_t g, uint8_t b);

/**
 * @brief 检查物理按键当前是否被按下 (适用于 FreeRTOS 任务轮询)
 * @param button 按键枚举
 * @return true 按下, false 抬起
 */
bool hal_interactive_is_button_pressed(interactive_button_id_t button);

#ifdef __cplusplus
}
#endif
