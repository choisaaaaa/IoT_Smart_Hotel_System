#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

// 定义常见的交互按键 ID (6个按键)
typedef enum {
    BTN_ROOM_PTT = 0,    // 客房: PTT（见 GLOBAL_PTT_BTN_PIN，默认 GPIO1：短按接听/挂断，长按唤醒 Agent）
    BTN_ROOM_SOS,        // 客房: SOS 报警
    BTN_ROOM_SCENE,      // 客房: 场景切换
    BTN_FRONT_CLEAR,     // 前台: 警报解除
    BTN_FRONT_BROADCAST, // 前台: 全楼广播
    BTN_FLOOR_ALARM      // 楼控: 楼道报警按钮
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
