#pragma once

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

// 定义 MQTT 消息的回调类型
typedef void (*mqtt_event_callback_t)(const char *topic, const char *data, int data_len);

// 初始化并连接到后端的 MQTT Broker
esp_err_t service_mqtt_start(const char *broker_uri, const char *client_id);

// 订阅特定的 Topic (如 hotel/room/301/cmd)
esp_err_t service_mqtt_subscribe(const char *topic, mqtt_event_callback_t callback);

// 发布 JSON 数据到后端的 Topic
esp_err_t service_mqtt_publish(const char *topic, const char *json_payload);

/** 同上但不打印「发布成功」日志，供高频音频块等场景。 */
esp_err_t service_mqtt_publish_silent(const char *topic, const char *payload);

#ifdef __cplusplus
}
#endif
