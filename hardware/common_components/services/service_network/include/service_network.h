#pragma once

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

// 定义网络连接状态回调函数指针 (业务层可用此函数点亮OLED或改变指示灯)
typedef void (*network_status_cb_t)(bool connected, const char* ip_address);

/**
 * @brief 启动配网流程
 * @param cb 连接成功或断开时的回调通知函数
 * @return esp_err_t ESP_OK 启动配网服务成功
 */
esp_err_t service_network_provisioning_start(network_status_cb_t cb);

/**
 * @brief 从 NVS 存储区读取配网时配置的特定信息（如："Room_ID" : "301"）
 * @param key 需要读取的键名 (最多15字符)
 * @param out_value 读取到的字符串缓冲区
 * @param max_len 缓冲区最大长度
 * @return esp_err_t ESP_OK 成功, ESP_ERR_NOT_FOUND 未找到该键
 */
esp_err_t service_network_read_nvs_string(const char* key, char* out_value, size_t max_len);

/**
 * @brief 获取 ISO8601 格式的当前时间戳 (如 "2026-04-07T00:00:00.000Z")
 * @param out_buffer 输出字符串缓冲区 (建议至少分配 32 字节)
 * @param max_len 缓冲区最大长度
 */
void service_network_get_iso8601_timestamp(char* out_buffer, size_t max_len);

#ifdef __cplusplus
}
#endif
