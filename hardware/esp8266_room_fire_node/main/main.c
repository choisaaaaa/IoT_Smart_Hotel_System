/*
 * ESP8266 客房火灾辅助节点：
 * - ADC 读取分压热敏（NTC）估算本地温度；
 * - MQTT 订阅楼控上报的 air_quality_adc（与客房端 topic 一致）；
 * - 当「楼控 MQ2 超阈」且「本地温度过高」且楼控数据未过期时，向 hotel/security/event 上报。
 *
 * 硬件：ESP8266 ADC（TOUT / 常见开发板 A0）输入电压不得超过约 1.0V（按芯片手册与衰减配置），
 * 请用分压把 NTC 节点电压限制在安全范围内。
 *
 * NVS 命名空间 fire8266（可选覆盖下面默认宏）：
 *   wifi_ssid, wifi_pass, mqtt_uri, floor_dev, node_dev, room_id, mq2_th, temp_th_c
 */

#include <string.h>
#include <stdio.h>
#include <math.h>
#include <time.h>
#include <sys/time.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"

#include "esp_system.h"
#include "esp_log.h"
#include "esp_err.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_timer.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "mqtt_client.h"
#include "cJSON.h"
#include "driver/adc.h"

#include "esp_sntp.h"

static const char *TAG = "fire8266";

/* 与仓库 global_config.h / 楼控 main.c 默认值对齐，可按现场改宏或写 NVS */
#ifndef DEFAULT_MQTT_URI
#define DEFAULT_MQTT_URI       "mqtt://172.20.10.3:1883"
#endif
#ifndef DEFAULT_WIFI_SSID
#define DEFAULT_WIFI_SSID      ""
#endif
#ifndef DEFAULT_WIFI_PASS
#define DEFAULT_WIFI_PASS      ""
#endif
#ifndef DEFAULT_FLOOR_DEV_ID
#define DEFAULT_FLOOR_DEV_ID   "floor_03"
#endif
#ifndef DEFAULT_NODE_DEV_ID
#define DEFAULT_NODE_DEV_ID    "esp8266_room_fire"
#endif
#define DEFAULT_ROOM_ID        301
#define DEFAULT_MQ2_ADC_TH     400
#define DEFAULT_TEMP_ALARM_C   40.0f

#define TOPIC_DATA_PREFIX      "hotel/device/data"
#define TOPIC_SECURITY_EVENT   "hotel/security/event"

#define FLOOR_DATA_MAX_AGE_US  (30 * 1000000LL)
#define FIRE_ALERT_COOLDOWN_US (120 * 1000000LL)
#define NTC_SAMPLE_COUNT       32

static EventGroupHandle_t s_wifi_event_group;
#define WIFI_CONNECTED_BIT BIT0

static esp_mqtt_client_handle_t s_mqtt;
static volatile bool s_mqtt_connected;
static char s_mqtt_client_id[40];

static portMUX_TYPE s_floor_mux = portMUX_INITIALIZER_UNLOCKED;
static int s_floor_mq2_adc;
static bool s_floor_mq2_valid;
static int64_t s_floor_mq2_us;

static int64_t s_last_fire_publish_us;

static char s_wifi_ssid[64];
static char s_wifi_pass[64];
static char s_mqtt_uri[160];
static char s_floor_dev[48];
static char s_node_dev[48];
static int s_room_id = DEFAULT_ROOM_ID;
static int s_mq2_adc_th = DEFAULT_MQ2_ADC_TH;
static float s_temp_alarm_c = DEFAULT_TEMP_ALARM_C;

static void nvs_load_config(void) {
    strncpy(s_wifi_ssid, DEFAULT_WIFI_SSID, sizeof(s_wifi_ssid) - 1);
    strncpy(s_wifi_pass, DEFAULT_WIFI_PASS, sizeof(s_wifi_pass) - 1);
    strncpy(s_mqtt_uri, DEFAULT_MQTT_URI, sizeof(s_mqtt_uri) - 1);
    strncpy(s_floor_dev, DEFAULT_FLOOR_DEV_ID, sizeof(s_floor_dev) - 1);
    strncpy(s_node_dev, DEFAULT_NODE_DEV_ID, sizeof(s_node_dev) - 1);

    nvs_handle_t h;
    if (nvs_open("fire8266", NVS_READONLY, &h) != ESP_OK) {
        return;
    }
    size_t sz;

    sz = sizeof(s_wifi_ssid);
    if (nvs_get_str(h, "wifi_ssid", s_wifi_ssid, &sz) != ESP_OK) {
        strncpy(s_wifi_ssid, DEFAULT_WIFI_SSID, sizeof(s_wifi_ssid) - 1);
    }
    sz = sizeof(s_wifi_pass);
    if (nvs_get_str(h, "wifi_pass", s_wifi_pass, &sz) != ESP_OK) {
        strncpy(s_wifi_pass, DEFAULT_WIFI_PASS, sizeof(s_wifi_pass) - 1);
    }
    sz = sizeof(s_mqtt_uri);
    if (nvs_get_str(h, "mqtt_uri", s_mqtt_uri, &sz) != ESP_OK) {
        strncpy(s_mqtt_uri, DEFAULT_MQTT_URI, sizeof(s_mqtt_uri) - 1);
    }
    sz = sizeof(s_floor_dev);
    if (nvs_get_str(h, "floor_dev", s_floor_dev, &sz) != ESP_OK) {
        strncpy(s_floor_dev, DEFAULT_FLOOR_DEV_ID, sizeof(s_floor_dev) - 1);
    }
    sz = sizeof(s_node_dev);
    if (nvs_get_str(h, "node_dev", s_node_dev, &sz) != ESP_OK) {
        strncpy(s_node_dev, DEFAULT_NODE_DEV_ID, sizeof(s_node_dev) - 1);
    }

    int32_t v32 = 0;
    if (nvs_get_i32(h, "room_id", &v32) == ESP_OK) {
        s_room_id = (int)v32;
    }
    if (nvs_get_i32(h, "mq2_th", &v32) == ESP_OK && v32 > 0) {
        s_mq2_adc_th = (int)v32;
    }
    if (nvs_get_i32(h, "temp_th_c", &v32) == ESP_OK) {
        s_temp_alarm_c = (float)v32 / 10.0f;
    }
    nvs_close(h);
}

static void wifi_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data) {
    (void)arg;
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
        esp_wifi_connect();
        ESP_LOGW(TAG, "WiFi 断开，重连中…");
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
        ESP_LOGI(TAG, "已获取 IP");
    }
}

static esp_err_t wifi_init_sta(void) {
    s_wifi_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    esp_event_handler_instance_t instance_any_id;
    esp_event_handler_instance_t instance_got_ip;
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL, &instance_any_id));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL, &instance_got_ip));

    wifi_config_t wifi_config = {0};
    strncpy((char *)wifi_config.sta.ssid, s_wifi_ssid, sizeof(wifi_config.sta.ssid) - 1);
    strncpy((char *)wifi_config.sta.password, s_wifi_pass, sizeof(wifi_config.sta.password) - 1);
    wifi_config.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    xEventGroupWaitBits(s_wifi_event_group, WIFI_CONNECTED_BIT, pdFALSE, pdFALSE, portMAX_DELAY);
    return ESP_OK;
}

static void obtain_time(void) {
    esp_sntp_setoperatingmode(SNTP_OPMODE_POLL);
    esp_sntp_setservername(0, "pool.ntp.org");
    esp_sntp_init();
    for (int i = 0; i < 40; i++) {
        if (esp_sntp_get_sync_status() == SNTP_SYNC_STATUS_COMPLETED) {
            break;
        }
        vTaskDelay(pdMS_TO_TICKS(250));
    }
}

static void fill_iso8601_timestamp(char *buf, size_t buflen) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    struct tm tm_info;
    localtime_r(&tv.tv_sec, &tm_info);
    strftime(buf, buflen, "%Y-%m-%dT%H:%M:%S", &tm_info);
    size_t n = strlen(buf);
    if (n + 6 < buflen) {
        snprintf(buf + n, buflen - n, ".%03ldZ", (long)(tv.tv_usec / 1000));
    }
}

static void mqtt_publish_fire_alert(float room_ntc_c, int floor_mq2) {
    char timestamp[40];
    fill_iso8601_timestamp(timestamp, sizeof(timestamp));

    char detail[192];
    snprintf(detail, sizeof(detail),
             "8266 NTC=%.1fC floor MQ2=%d th=%d (楼控+客房高温)",
             (double)room_ntc_c, floor_mq2, s_mq2_adc_th);

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", s_node_dev);
    cJSON_AddStringToObject(root, "device_type", "room");
    cJSON_AddStringToObject(root, "event_type", "room_fire_suspected");
    cJSON_AddStringToObject(root, "detail", detail);
    cJSON *event_data = cJSON_CreateObject();
    cJSON_AddNumberToObject(event_data, "room_id", s_room_id);
    cJSON_AddItemToObject(root, "event_data", event_data);
    cJSON_AddStringToObject(root, "level", "warning");
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char *json_str = cJSON_PrintUnformatted(root);
    if (json_str != NULL && s_mqtt_connected && s_mqtt != NULL) {
        int msg_id = esp_mqtt_client_publish(s_mqtt, TOPIC_SECURITY_EVENT, json_str, 0, 1, 0);
        ESP_LOGW(TAG, "火灾疑似上报 security/event msg_id=%d", msg_id);
    }
    free(json_str);
    cJSON_Delete(root);
}

static void floor_air_mqtt_handle(const char *data, int data_len) {
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        return;
    }
    cJSON *did = cJSON_GetObjectItem(root, "device_id");
    cJSON *stype = cJSON_GetObjectItem(root, "sensor_type");
    cJSON *val = cJSON_GetObjectItem(root, "value");
    if (!cJSON_IsString(did) || did->valuestring == NULL ||
        strcmp(did->valuestring, s_floor_dev) != 0) {
        cJSON_Delete(root);
        return;
    }
    if (!cJSON_IsString(stype) || stype->valuestring == NULL || !cJSON_IsNumber(val)) {
        cJSON_Delete(root);
        return;
    }
    if (strcmp(stype->valuestring, "air_quality_adc") != 0) {
        cJSON_Delete(root);
        return;
    }
    int adc = cJSON_IsNumber(val) ? (int)(val->valuedouble + 0.5) : 0;
    int64_t now = esp_timer_get_time();
    portENTER_CRITICAL(&s_floor_mux);
    s_floor_mq2_adc = adc;
    s_floor_mq2_valid = true;
    s_floor_mq2_us = now;
    portEXIT_CRITICAL(&s_floor_mux);
    cJSON_Delete(root);
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data) {
    (void)handler_args;
    (void)base;
    esp_mqtt_event_handle_t event = event_data;
    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED: {
        s_mqtt_connected = true;
        char topic[128];
        snprintf(topic, sizeof(topic), "%s/air_quality_adc/%s", TOPIC_DATA_PREFIX, s_floor_dev);
        esp_mqtt_client_subscribe(event->client, topic, 1);
        ESP_LOGI(TAG, "MQTT 已连接，订阅 %s", topic);
        break;
    }
    case MQTT_EVENT_DISCONNECTED:
        s_mqtt_connected = false;
        ESP_LOGW(TAG, "MQTT 断开");
        break;
    case MQTT_EVENT_DATA: {
        char *tmp = malloc((size_t)event->data_len + 1);
        if (tmp == NULL) {
            break;
        }
        memcpy(tmp, event->data, (size_t)event->data_len);
        tmp[event->data_len] = '\0';
        floor_air_mqtt_handle(tmp, event->data_len);
        free(tmp);
        break;
    }
    default:
        break;
    }
}

static void mqtt_app_start(void) {
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    snprintf(s_mqtt_client_id, sizeof(s_mqtt_client_id), "8266fire_%02x%02x%02x", mac[3], mac[4], mac[5]);

    esp_mqtt_client_config_t mc = {0};
    mc.uri = s_mqtt_uri;
    mc.client_id = s_mqtt_client_id;
    mc.keepalive = 60;
    mc.disable_auto_reconnect = false;

    s_mqtt = esp_mqtt_client_init(&mc);
    esp_mqtt_client_register_event(s_mqtt, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(s_mqtt);
}

/* 分压：Vdd -- Rseries --+-- NTC -- GND，ADC 测节点电压 V（伏）。与楼控 hal NTC 思路一致。 */
#ifndef NTC_RSERIES_OHM
#define NTC_RSERIES_OHM 10000.0f
#endif
#ifndef NTC_R25_OHM
#define NTC_R25_OHM     10000.0f
#endif
#ifndef NTC_BETA
#define NTC_BETA        3950.0f
#endif
#ifndef NTC_VDD
#define NTC_VDD         3.3f
#endif

static float ntc_resistance_to_c(float r_ohm) {
    if (r_ohm < 1.0f || !isfinite(r_ohm)) {
        return NAN;
    }
    const float inv_t0 = 1.0f / 298.15f;
    const float ln = logf(r_ohm / NTC_R25_OHM);
    const float inv_t = inv_t0 + ln / NTC_BETA;
    return (1.0f / inv_t) - 273.15f;
}

static float adc_read_ntc_temp_c(void) {
    uint32_t acc = 0;
    for (int i = 0; i < NTC_SAMPLE_COUNT; i++) {
        acc += (uint32_t)adc1_get_raw(ADC1_CHANNEL_0);
    }
    float raw = (float)acc / (float)NTC_SAMPLE_COUNT;
    const float v_adc_max = 1.0f;
    const float v = (raw / 4095.0f) * v_adc_max;
    if (v <= 0.002f || v >= (NTC_VDD - 0.002f)) {
        return NAN;
    }
    float r_ntc = NTC_RSERIES_OHM * v / (NTC_VDD - v);
    return ntc_resistance_to_c(r_ntc);
}

static void ntc_adc_init(void) {
    adc1_config_width(ADC_WIDTH_BIT_12);
    adc1_config_channel_atten(ADC1_CHANNEL_0, ADC_ATTEN_DB_11);
}

static void fire_eval_task(void *pv) {
    (void)pv;
    s_last_fire_publish_us = 0;
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(2000));
        float room_c = adc_read_ntc_temp_c();
        int64_t now = esp_timer_get_time();

        bool mq2_ok = false;
        int mq2v = 0;
        int64_t mq2_age = 0;
        portENTER_CRITICAL(&s_floor_mux);
        if (s_floor_mq2_valid) {
            mq2v = s_floor_mq2_adc;
            mq2_age = now - s_floor_mq2_us;
            mq2_ok = true;
        }
        portEXIT_CRITICAL(&s_floor_mux);

        if (!isfinite(room_c)) {
            ESP_LOGD(TAG, "NTC 读数无效");
            continue;
        }
        if (!mq2_ok || mq2_age > FLOOR_DATA_MAX_AGE_US) {
            ESP_LOGD(TAG, "楼控 MQ2 无有效数据或已过期");
            continue;
        }

        const bool smoky = mq2v >= s_mq2_adc_th;
        const bool hot = room_c >= s_temp_alarm_c;
        if (smoky && hot) {
            if (now - s_last_fire_publish_us >= FIRE_ALERT_COOLDOWN_US) {
                mqtt_publish_fire_alert(room_c, mq2v);
                s_last_fire_publish_us = now;
            }
        }
    }
}

void app_main(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    nvs_load_config();
    if (s_wifi_ssid[0] == '\0') {
        ESP_LOGE(TAG, "WiFi SSID 为空：请设置 DEFAULT_WIFI_SSID 或 NVS fire8266/wifi_ssid");
        return;
    }

    ntc_adc_init();

    ESP_LOGI(TAG, "连接 WiFi: %s", s_wifi_ssid);
    if (wifi_init_sta() != ESP_OK) {
        ESP_LOGE(TAG, "WiFi 失败");
        return;
    }
    obtain_time();

    ESP_LOGI(TAG, "楼控 device_id=%s MQ2>=%d 且本地 NTC>=%.1fC 触发告警", s_floor_dev, s_mq2_adc_th, (double)s_temp_alarm_c);
    mqtt_app_start();

    xTaskCreate(fire_eval_task, "fire_eval", 4096, NULL, 5, NULL);
}
