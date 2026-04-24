#include "service_mqtt.h"
#include "esp_log.h"
#include "mqtt_client.h"
#include "esp_event.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <stdbool.h>
#include <string.h>

static const char *TAG = "SERVICE_MQTT";
static esp_mqtt_client_handle_t s_client = NULL;
static volatile bool s_started = false;
static volatile bool s_connected = false;
static volatile bool s_reconnect_task_running = false;

#define MQTT_MAX_SUBSCRIPTIONS 16
#define MQTT_TOPIC_MAX_LEN     128
#define MQTT_BACKOFF_MIN_MS    1000
#define MQTT_BACKOFF_MAX_MS    60000

typedef struct {
    char topic[MQTT_TOPIC_MAX_LEN];
    mqtt_event_callback_t callback;
    bool used;
} mqtt_subscription_t;

static mqtt_subscription_t s_subscriptions[MQTT_MAX_SUBSCRIPTIONS];

static bool topic_equals_event(const char *topic, const char *event_topic, int event_topic_len) {
    if (topic == NULL || event_topic == NULL || event_topic_len <= 0) {
        return false;
    }
    size_t len = strlen(topic);
    return (len == (size_t)event_topic_len) && (strncmp(topic, event_topic, (size_t)event_topic_len) == 0);
}

static void resubscribe_all_topics(void) {
    for (int i = 0; i < MQTT_MAX_SUBSCRIPTIONS; ++i) {
        if (s_subscriptions[i].used) {
            int msg_id = esp_mqtt_client_subscribe(s_client, s_subscriptions[i].topic, 1);
            ESP_LOGI(TAG, "重订阅主题: topic=%s msg_id=%d", s_subscriptions[i].topic, msg_id);
        }
    }
}

static void reconnect_task(void *param) {
    (void)param;
    int backoff_ms = MQTT_BACKOFF_MIN_MS;

    ESP_LOGW(TAG, "MQTT 重连任务已启动");
    while (s_started && !s_connected) {
        vTaskDelay(pdMS_TO_TICKS(backoff_ms));
        if (!s_started || s_connected || s_client == NULL) {
            break;
        }

        ESP_LOGW(TAG, "MQTT 重连尝试, backoff_ms=%d", backoff_ms);
        esp_mqtt_client_reconnect(s_client);
        backoff_ms = (backoff_ms < MQTT_BACKOFF_MAX_MS / 2) ? backoff_ms * 2 : MQTT_BACKOFF_MAX_MS;
    }

    s_reconnect_task_running = false;
    ESP_LOGI(TAG, "MQTT 重连任务已停止");
    vTaskDelete(NULL);
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data) {
    (void)handler_args;
    (void)base;
    esp_mqtt_event_handle_t event = event_data;

    switch (event_id) {
        case MQTT_EVENT_CONNECTED:
            s_connected = true;
            ESP_LOGI(TAG, "MQTT 已连接");
            resubscribe_all_topics();
            break;

        case MQTT_EVENT_DISCONNECTED:
            s_connected = false;
            ESP_LOGW(TAG, "MQTT 已断开");
            if (s_started && !s_reconnect_task_running) {
                s_reconnect_task_running = true;
                xTaskCreate(reconnect_task, "mqtt_reconnect", 3072, NULL, 4, NULL);
            }
            break;

        case MQTT_EVENT_DATA:
            for (int i = 0; i < MQTT_MAX_SUBSCRIPTIONS; ++i) {
                if (s_subscriptions[i].used &&
                    s_subscriptions[i].callback != NULL &&
                    topic_equals_event(s_subscriptions[i].topic, event->topic, event->topic_len)) {
                    s_subscriptions[i].callback(event->topic, event->data, event->data_len);
                }
            }
            break;

        default:
            break;
    }
}

esp_err_t service_mqtt_start(const char *broker_uri, const char *client_id) {
    if (broker_uri == NULL || client_id == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    if (s_started && s_client != NULL) {
        ESP_LOGI(TAG, "MQTT 服务已启动");
        return ESP_OK;
    }

    ESP_LOGI(TAG, "启动 MQTT 服务: broker=%s, client_id=%s", broker_uri, client_id);

    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = broker_uri,
        .credentials.client_id = client_id,
        .network.disable_auto_reconnect = true,
        .buffer.size = 20480,       // 下行：每包分段 PCM JSON + base64
        .buffer.out_size = 8192,    // 上行：分段 PCM
    };

    s_client = esp_mqtt_client_init(&mqtt_cfg);
    if (s_client == NULL) {
        ESP_LOGE(TAG, "esp_mqtt_client_init 失败");
        return ESP_FAIL;
    }

    esp_mqtt_client_register_event(s_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_err_t err = esp_mqtt_client_start(s_client);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_mqtt_client_start 失败: %s", esp_err_to_name(err));
        return err;
    }

    s_started = true;
    return ESP_OK;
}

esp_err_t service_mqtt_subscribe(const char *topic, mqtt_event_callback_t callback) {
    if (topic == NULL || callback == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    // 去重更新
    for (int i = 0; i < MQTT_MAX_SUBSCRIPTIONS; ++i) {
        if (s_subscriptions[i].used && strcmp(s_subscriptions[i].topic, topic) == 0) {
            s_subscriptions[i].callback = callback;
            if (s_connected && s_client != NULL) {
                esp_mqtt_client_subscribe(s_client, topic, 1);
            }
            return ESP_OK;
        }
    }

    for (int i = 0; i < MQTT_MAX_SUBSCRIPTIONS; ++i) {
        if (!s_subscriptions[i].used) {
            strncpy(s_subscriptions[i].topic, topic, MQTT_TOPIC_MAX_LEN - 1);
            s_subscriptions[i].topic[MQTT_TOPIC_MAX_LEN - 1] = '\0';
            s_subscriptions[i].callback = callback;
            s_subscriptions[i].used = true;

            ESP_LOGI(TAG, "订阅主题: %s", s_subscriptions[i].topic);
            if (s_connected && s_client != NULL) {
                esp_mqtt_client_subscribe(s_client, s_subscriptions[i].topic, 1);
            }
            return ESP_OK;
        }
    }

    ESP_LOGE(TAG, "订阅表已满, topic=%s", topic);
    return ESP_ERR_NO_MEM;
}

esp_err_t service_mqtt_publish(const char *topic, const char *json_payload) {
    if (topic == NULL || json_payload == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    if (!s_connected || s_client == NULL) {
        ESP_LOGW(TAG, "MQTT 未连接，跳过发布: topic=%s", topic);
        return ESP_ERR_INVALID_STATE;
    }

    int msg_id = esp_mqtt_client_publish(s_client, topic, json_payload, 0, 1, 0);
    if (msg_id < 0) {
        ESP_LOGE(TAG, "MQTT 发布失败: topic=%s", topic);
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "MQTT 发布成功: topic=%s msg_id=%d", topic, msg_id);
    return ESP_OK;
}

esp_err_t service_mqtt_publish_silent(const char *topic, const char *payload)
{
    if (topic == NULL || payload == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!s_connected || s_client == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    int msg_id = esp_mqtt_client_publish(s_client, topic, payload, 0, 1, 0);
    if (msg_id < 0) {
        ESP_LOGE(TAG, "MQTT 发布失败: topic=%s", topic);
        return ESP_FAIL;
    }
    return ESP_OK;
}

esp_err_t service_mqtt_publish_audio(const char *topic, const char *payload)
{
    if (topic == NULL || payload == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!s_connected || s_client == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    /* QoS 0 不等 PUBACK，避免高频语音 PCM 上行被 ACK 串行化拖慢；偶发丢包仅影响一帧 (~32ms@16k)，可忽略。 */
    int msg_id = esp_mqtt_client_publish(s_client, topic, payload, 0, 0, 0);
    if (msg_id < 0) {
        return ESP_FAIL;
    }
    return ESP_OK;
}
