#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

// 支持的家电品牌枚举 (简化红外发送)
typedef enum {
    IR_BRAND_GREE = 0, // 格力空调
    IR_BRAND_MIDEA,    // 美的空调
    IR_BRAND_TV        // 电视机通用
} ir_brand_type_t;

// 简单的红外空调指令结构 (避免底层涉及复杂拼包)
typedef struct {
    bool power_on;       // true:开机 false:关机
    uint8_t temperature; // 目标温度 16-30
} ir_ac_cmd_t;

/**
 * @brief 初始化红外收发系统 (RMT/GPIO)
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t hal_infrared_init(void);

/**
 * @brief 向指定品牌的空调发送特定指令
 * @param brand 空调品牌
 * @param cmd 包含开关与温度的结构体
 * @return esp_err_t 
 */
esp_err_t hal_infrared_send_ac_command(ir_brand_type_t brand, const ir_ac_cmd_t *cmd);

/**
 * @brief 阻塞等待并学习外部遥控器的红外特征码
 * @param out_buffer 存放学习到的红外时序特征
 * @param max_len 缓冲区最大长度
 * @param timeout_ms 超时毫秒数 (如 5000ms 等待用户按遥控器)
 * @return esp_err_t ESP_OK 学习成功, ESP_ERR_TIMEOUT 超时
 */
esp_err_t hal_infrared_learn_code(uint8_t *out_buffer, size_t max_len, uint32_t timeout_ms);

/**
 * @brief 红外对射一次采样：发射短载波后看接收头是否收到
 * @param out_obstructed true 表示接收端未收到（视为光束被遮挡）
 */
esp_err_t hal_infrared_barrier_poll(bool *out_obstructed);

#ifdef __cplusplus
}
#endif
