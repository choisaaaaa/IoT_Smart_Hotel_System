#ifndef SERVICE_AUTH_H
#define SERVICE_AUTH_H

#include "esp_err.h"
#include <stddef.h>

struct cJSON;

#ifdef __cplusplus
extern "C" {
#endif

// 认证状态枚举
typedef enum {
    AUTH_STATE_UNREGISTERED, // 还没注册，连 NVS 都没有 key
    AUTH_STATE_PENDING,      // 已注册，后台在待审核
    AUTH_STATE_APPROVED,     // 审核通过，已拿到 key
    AUTH_STATE_REJECTED      // 被拒绝
} service_auth_state_t;

/**
 * @brief 初始化认证组件，从 NVS 读取 device_key
 * @return esp_err_t 
 */
esp_err_t service_auth_init(void);

/**
 * @brief 获取当前认证状态
 * @return service_auth_state_t 
 */
service_auth_state_t service_auth_get_state(void);

/**
 * @brief 获取当前的 device_key (如果已 approved)
 * @param out_key 缓冲区
 * @param max_len 缓冲区最大长度
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t service_auth_get_device_key(char* out_key, size_t max_len);

/**
 * @brief 解析设备注册接口完整 URL（与浏览器/后端使用同一套 API）
 *
 * 规则：若 http_api_base_opt 非空（例如 NVS 键 HTTP_API_BASE），则
 *   {http_api_base_opt}/api/v1/devices/register（会自动去掉末尾 /）
 * 否则从 mqtt_broker_uri 提取主机名，生成
 *   http://<host>:9000/api/v1/devices/register
 * （与当前工程约定：HTTP API 与 MQTT Broker 同机、API 端口 9000）
 */
esp_err_t service_auth_resolve_register_url(
    const char *mqtt_broker_uri,
    const char *http_api_base_opt,
    char *out,
    size_t out_len);

/**
 * @brief 执行 HTTP 注册并轮询等待审核通过 (阻塞函数)
 * @param api_url 后端完整 API (例如 "http://192.168.1.100:9000/api/v1/devices/register")
 * @param hotel_id 酒店 ID
 * @param device_id 设备 ID (如 "ROO_101_CTRL_001")
 * @param device_type 设备类型 (如 "room", "floor", "front_desk")
 * @param device_name 设备名称
 * @param firmware_version 固件版本
 * @return esp_err_t 
 */
esp_err_t service_auth_perform_registration_blocking(
    const char* api_url,
    int hotel_id,
    const char* device_id,
    const char* device_type,
    const char* device_name,
    const char* firmware_version
);

/**
 * @brief 对 Payload 进行 HMAC-SHA256 签名 (使用 device_key)
 * @param payload 需要签名的原文 JSON 字符串
 * @param out_signature 用于存放签名的缓冲区 (至少 65 字节，64 hex + 1 null)
 * @return esp_err_t 
 */
esp_err_t service_auth_sign_payload(const char* payload, char* out_signature);

/**
 * @brief 对 cJSON 对象按「键名 ASCII 排序」序列化后做 HMAC（与后端 sortObject + JSON.stringify 一致）
 * @param root 待签名的 JSON 对象（勿含 signature；若含会先忽略副本中的 signature）
 * @param out_signature 至少 65 字节缓冲区
 */
esp_err_t service_auth_sign_cjson_object(const struct cJSON *root, char *out_signature);

#ifdef __cplusplus
}
#endif

#endif // SERVICE_AUTH_H
