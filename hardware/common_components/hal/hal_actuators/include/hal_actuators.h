#pragma once

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 执行器设备枚举，对应 CH1-CH4
 */
typedef enum {
    ACTUATOR_RELAY_CH1 = 0, // 灯光 (客房主灯/走廊灯)
    ACTUATOR_RELAY_CH2,     // 插座 / 备用
    ACTUATOR_RELAY_CH3,     // 窗帘电机
    ACTUATOR_RELAY_CH4      // 电磁门锁
} actuator_type_t;

/**
 * @brief 初始化所有继电器控制引脚
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t hal_actuators_init(void);

/**
 * @brief 控制设备开关 (底层自动处理继电器的高低电平逻辑)
 * @param type 设备枚举
 * @param state true: 开启/吸合, false: 关闭/断开
 * @return esp_err_t 
 */
esp_err_t hal_actuators_set_state(actuator_type_t type, bool state);

/**
 * @brief 设置继电器有效电平
 * @param active_low true: 低电平吸合, false: 高电平吸合
 */
void hal_actuators_set_active_level(bool active_low);

#ifdef __cplusplus
}
#endif
