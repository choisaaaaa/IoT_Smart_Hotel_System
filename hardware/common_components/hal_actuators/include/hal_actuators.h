#pragma once

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 执行器设备枚举，清晰易懂，避免直接操作数字引脚
 */
typedef enum {
    ACTUATOR_LIGHT_MAIN = 0, // 客房主灯 / 走廊灯
    ACTUATOR_SOCKET,         // 客房插座 / 备用控制
    ACTUATOR_CURTAIN,        // 窗帘电机
    ACTUATOR_DOOR_LOCK       // 电磁门锁
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

#ifdef __cplusplus
}
#endif
