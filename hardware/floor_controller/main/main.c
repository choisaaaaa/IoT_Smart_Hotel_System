#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "nvs_flash.h"
#include "sdkconfig.h"
#include "cJSON.h"
#ifndef CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE
#define CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE 0
#endif
#if CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE
#include "esp_timer.h"
#endif

// 引入所需的底层硬件抽象组件库
#include "service_mqtt.h"
#include "hal_actuators.h"
#include "hal_sensors.h"
#include "hal_interactive.h"
#include "service_network.h"
#include "global_config.h"
#include "service_auth.h"

static const char *TAG = "FLOOR_CONTROLLER_MAIN";
#define FLOOR_FIRMWARE_VERSION "v1.1.0"
static char current_floor_id[16] = "UNKNOWN";
static char target_room_id[16] = "301";
static char room_device_id[32] = "room_301";
static char device_id[32] = "floor_UNKNOWN";
static char mqtt_broker_uri[128] = GLOBAL_MQTT_BROKER_URI;
static const TickType_t FLOOR_SENSOR_TASK_PERIOD = pdMS_TO_TICKS(30000);
static const TickType_t FLOOR_BUTTON_TASK_PERIOD = pdMS_TO_TICKS(80);
static const TickType_t FLOOR_HEALTH_TASK_PERIOD = pdMS_TO_TICKS(600000);
static volatile bool s_network_ready = false;
static bool s_corridor_light_on = false;
/** MQTT 广播类指令：蜂鸣器长鸣开/关（再发 broadcast_alarm|broadcast_start 为关闭） */
static bool s_floor_broadcast_buzzer_on = false;
static uint32_t s_reconnect_count = 0;

/** 疑似火灾：DHT11 或 走廊 NTC 任一超温 + MQ2 烟雾 ADC 超阈（现场请标定 MQ2 基线） */
static const float k_fire_suspect_temp_c = 40.0f;
static const uint16_t k_fire_suspect_smoke_adc = 400;
static bool s_fire_suspect_episode_reported = false;

static void copy_str_safe(char *dst, size_t dst_size, const char *src) {
    if (dst == NULL || dst_size == 0) return;
    if (src == NULL) {
        dst[0] = '\0';
        return;
    }
    strncpy(dst, src, dst_size - 1);
    dst[dst_size - 1] = '\0';
}

static void load_nvs_string_with_fallback(const char *key, char *out, size_t out_size, const char *fallback) {
    if (service_network_read_nvs_string(key, out, out_size) != ESP_OK || out[0] == '\0') {
        copy_str_safe(out, out_size, fallback);
    } else {
        out[out_size - 1] = '\0';
    }
}

static const char *topic_tail(const char *topic)
{
    if (topic == NULL) {
        return "";
    }
    const char *p = strrchr(topic, '/');
    return (p != NULL) ? (p + 1) : topic;
}

static bool eq_nocase(const char *a, const char *b)
{
    if (a == NULL || b == NULL) {
        return false;
    }
    return strcasecmp(a, b) == 0;
}

static bool is_floor_target_match(const char *target)
{
    if (target == NULL || target[0] == '\0') {
        return false;
    }
    if (eq_nocase(target, "all") || eq_nocase(target, device_id) || eq_nocase(target, current_floor_id)) {
        return true;
    }
    char flo_alias[24];
    int floor_num = atoi(current_floor_id);
    if (floor_num > 0) {
        snprintf(flo_alias, sizeof(flo_alias), "FLO_%dF", floor_num);
    } else {
        snprintf(flo_alias, sizeof(flo_alias), "FLO_%sF", current_floor_id);
    }
    return eq_nocase(target, flo_alias);
}

static bool is_room_target_match(const char *target)
{
    if (target == NULL || target[0] == '\0') {
        return false;
    }
    return eq_nocase(target, "all") || eq_nocase(target, room_device_id) || eq_nocase(target, target_room_id);
}

/** 与常见后端约定对齐：command_id 可为 JSON number，或 "123" 字符串 */
static bool mqtt_cmd_get_int(cJSON *item, int *out)
{
    if (item == NULL || out == NULL) {
        return false;
    }
    if (cJSON_IsNumber(item)) {
        *out = item->valueint;
        return true;
    }
    if (cJSON_IsString(item) && item->valuestring != NULL) {
        char *end = NULL;
        errno = 0;
        long v = strtol(item->valuestring, &end, 10);
        if (end == item->valuestring || *end != '\0' || errno == ERANGE) {
            return false;
        }
        *out = (int)v;
        return true;
    }
    return false;
}

/** command_type 一般为 string；也允许数字，便于与弱类型对端联调 */
static const char *mqtt_cmd_get_type_str(cJSON *item, char *buf, size_t buf_size)
{
    if (item == NULL || buf == NULL || buf_size < 2) {
        return NULL;
    }
    if (cJSON_IsString(item) && item->valuestring != NULL) {
        return item->valuestring;
    }
    if (cJSON_IsNumber(item)) {
        snprintf(buf, buf_size, "%d", item->valueint);
        return buf;
    }
    return NULL;
}

static cJSON *parse_command_value_object(cJSON *root, cJSON **out_owned_json)
{
    if (out_owned_json != NULL) {
        *out_owned_json = NULL;
    }
    if (root == NULL) {
        return NULL;
    }

    cJSON *command_value = cJSON_GetObjectItem(root, "command_value");
    if (cJSON_IsObject(command_value)) {
        return command_value;
    }
    if (!cJSON_IsString(command_value) || command_value->valuestring == NULL) {
        return NULL;
    }

    cJSON *parsed = cJSON_Parse(command_value->valuestring);
    if (!cJSON_IsObject(parsed)) {
        if (parsed != NULL) {
            cJSON_Delete(parsed);
        }
        /* 多数楼控指令只依赖 command_type，command_value 仅作扩展；非法则按无参处理 */
        ESP_LOGD(TAG, "command_value 非 JSON 对象字符串，已忽略");
        return NULL;
    }
    if (out_owned_json != NULL) {
        *out_owned_json = parsed;
    }
    return parsed;
}

static void publish_command_result(int cmd_id, const char *cmd_type, bool exec_success, const char *result_msg) {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过楼控指令回执: %s", cmd_type);
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *reply = cJSON_CreateObject();
    cJSON_AddStringToObject(reply, "device_id", device_id);
    cJSON_AddNumberToObject(reply, "command_id", cmd_id);
    cJSON_AddStringToObject(reply, "command_type", cmd_type);
    cJSON_AddStringToObject(reply, "status", exec_success ? "success" : "failed");
    cJSON_AddStringToObject(reply, "result", result_msg);
    cJSON_AddStringToObject(reply, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(reply, signature) == ESP_OK) {
        cJSON_AddStringToObject(reply, "signature", signature);
    }
    char *reply_str = cJSON_PrintUnformatted(reply);
    service_mqtt_publish(GLOBAL_TOPIC_DEVICE_COMMAND_RESULT, reply_str);
    free(reply_str);
    cJSON_Delete(reply);
}

static void publish_room_command_result(int cmd_id, const char *cmd_type, bool exec_success, const char *result_msg) {
    if (!s_network_ready) {
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *reply = cJSON_CreateObject();
    cJSON_AddStringToObject(reply, "device_id", room_device_id);
    cJSON_AddNumberToObject(reply, "command_id", cmd_id);
    cJSON_AddStringToObject(reply, "command_type", cmd_type);
    cJSON_AddStringToObject(reply, "status", exec_success ? "success" : "failed");
    cJSON_AddStringToObject(reply, "result", result_msg);
    cJSON_AddStringToObject(reply, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(reply, signature) == ESP_OK) {
        cJSON_AddStringToObject(reply, "signature", signature);
    }
    char *reply_str = cJSON_PrintUnformatted(reply);
    service_mqtt_publish(GLOBAL_TOPIC_DEVICE_COMMAND_RESULT, reply_str);
    free(reply_str);
    cJSON_Delete(reply);
}

static void publish_floor_runtime_status(void) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/floor/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "floor");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddBoolToObject(root, "corridor_light_on", s_corridor_light_on);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    free(json_str);
    cJSON_Delete(root);
}

static void publish_floor_event(const char *event_type, const char *detail, const char *level) {
    if (!s_network_ready) {
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "event_type", event_type);
    cJSON_AddStringToObject(root, "detail", detail);
    cJSON_AddStringToObject(root, "level", (level != NULL && level[0] != '\0') ? level : "info");
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(GLOBAL_TOPIC_SECURITY_EVENT, json_str);
    free(json_str);
    cJSON_Delete(root);
}

/** 与物理「报警键」一致：上报告警事件 + 蜂鸣 2×100ms；若正有 MQTT 广播长鸣，短鸣后恢复长鸣 */
static void floor_trigger_alarm_match_physical_button(void) {
    publish_floor_event("floor_alarm_pressed", "楼道报警按钮触发", "alarm");
    hal_interactive_beep(2, 100);
    if (s_floor_broadcast_buzzer_on) {
        (void)hal_interactive_buzzer_steady(true);
    }
}

/** 楼控/客房灯路：开、关均做继电器脉冲（弾接），不长期保持电平 */
static const uint32_t k_floor_relay_light_pulse_ms = 220;

static esp_err_t floor_relay_ch1_pulse(uint32_t hold_ms) {
    esp_err_t e = hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
    if (e != ESP_OK) {
        return e;
    }
    vTaskDelay(pdMS_TO_TICKS(hold_ms));
    return hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
}

static void floor_restart_task(void *arg) {
    (void)arg;
    vTaskDelay(pdMS_TO_TICKS(500));
    esp_restart();
}

static void floor_schedule_restart(void) {
    if (xTaskCreate(floor_restart_task, "reboot", 2048, NULL, 1, NULL) != pdPASS) {
        ESP_LOGE(TAG, "创建重启任务失败，立即 esp_restart");
        esp_restart();
    }
}

static void publish_health_report(void) {
    if (!s_network_ready) {
        return;
    }

    wifi_ap_record_t ap_info = {0};
    int rssi = 0;
    if (esp_wifi_sta_get_ap_info(&ap_info) == ESP_OK) {
        rssi = ap_info.rssi;
    }

    char timestamp[32];
    char topic[128];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));
    snprintf(topic, sizeof(topic), "hotel/health/floor/%s", device_id);

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "floor");
    cJSON_AddStringToObject(root, "firmware_version", FLOOR_FIRMWARE_VERSION);
    cJSON_AddNumberToObject(root, "uptime_sec", xTaskGetTickCount() * portTICK_PERIOD_MS / 1000);
    cJSON_AddNumberToObject(root, "free_heap_bytes", (double)esp_get_free_heap_size());
    cJSON_AddNumberToObject(root, "rssi", rssi);
    cJSON_AddNumberToObject(root, "reconnect_counts", (double)s_reconnect_count);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    ESP_LOGI(TAG, "健康上报已发送: topic=%s rssi=%d reconnect=%lu",
             topic, rssi, (unsigned long)s_reconnect_count);
    free(json_str);
    cJSON_Delete(root);
}

static bool execute_room_command_on_floor(const char *cmd_type, const char **out_result_msg) {
    if (strcmp(cmd_type, "light_on") == 0) {
        esp_err_t err = floor_relay_ch1_pulse(k_floor_relay_light_pulse_ms);
        *out_result_msg = (err == ESP_OK) ? "执行成功(继电器脉冲/开灯)" : "客房灯控失败";
        return (err == ESP_OK);
    }
    if (strcmp(cmd_type, "light_off") == 0) {
        esp_err_t err = floor_relay_ch1_pulse(k_floor_relay_light_pulse_ms);
        *out_result_msg = (err == ESP_OK) ? "执行成功(继电器脉冲/关灯)" : "客房灯控失败";
        return (err == ESP_OK);
    }
    if (strcmp(cmd_type, "air_on") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "空调控制失败";
        return (err == ESP_OK);
    }
    if (strcmp(cmd_type, "air_off") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "空调控制失败";
        return (err == ESP_OK);
    }
    if (strcmp(cmd_type, "door_unlock") == 0) {
        esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
        if (err == ESP_OK) {
            vTaskDelay(pdMS_TO_TICKS(3000));
            hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "门锁控制失败";
        return (err == ESP_OK);
    }
    if (strcmp(cmd_type, "curtain_open") == 0 || strcmp(cmd_type, "curtain_close") == 0) {
        *out_result_msg = "执行成功(模拟)";
        return true;
    }
    *out_result_msg = "未识别的客房指令(由楼控代为处理)";
    return false;
}

static bool execute_floor_command(const char *cmd_type, const char **out_result_msg) {
    if (strcmp(cmd_type, "light_on") == 0) {
        esp_err_t err = floor_relay_ch1_pulse(k_floor_relay_light_pulse_ms);
        if (err == ESP_OK) {
            s_corridor_light_on = true;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功(继电器脉冲/开灯)" : "走廊灯控失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "light_off") == 0) {
        esp_err_t err = floor_relay_ch1_pulse(k_floor_relay_light_pulse_ms);
        if (err == ESP_OK) {
            s_corridor_light_on = false;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功(继电器脉冲/关灯)" : "走廊灯控失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "broadcast_alarm") == 0 || strcmp(cmd_type, "broadcast_start") == 0) {
        if (!s_floor_broadcast_buzzer_on) {
            esp_err_t bz = hal_interactive_buzzer_steady(true);
            if (bz == ESP_OK) {
                s_floor_broadcast_buzzer_on = true;
                publish_floor_event("floor_broadcast_buzzer", "蜂鸣器广播已开启(再发同指令可解除)", "alarm");
                *out_result_msg = "广播蜂鸣：已长鸣(再发 broadcast_alarm 或 broadcast_start 取消)";
            } else {
                *out_result_msg = "广播蜂鸣：蜂鸣器未接入或未初始化，无法开";
            }
        } else {
            (void)hal_interactive_buzzer_steady(false);
            s_floor_broadcast_buzzer_on = false;
            publish_floor_event("floor_broadcast_buzzer", "蜂鸣器广播已解除(同指令关)", "info");
            *out_result_msg = "广播蜂鸣：已关闭";
        }
        return true;
    }

    if (strcmp(cmd_type, "broadcast_stop") == 0) {
        (void)hal_interactive_buzzer_steady(false);
        s_floor_broadcast_buzzer_on = false;
        publish_floor_event("floor_broadcast_buzzer", "蜂鸣器广播已停止(broadcast_stop)", "info");
        *out_result_msg = "广播蜂鸣：已停止";
        return true;
    }

    if (strcmp(cmd_type, "floor_reset") == 0 || strcmp(cmd_type, "system_reset") == 0) {
        floor_schedule_restart();
        *out_result_msg = "系统复位：约0.5s后重启";
        return true;
    }

    *out_result_msg = "未识别的楼控指令";
    return false;
}

static void run_floor_local_policy(const sensor_data_t *env_data) {
    if (env_data == NULL) {
        return;
    }

    const bool hot_dht = env_data->temperature >= k_fire_suspect_temp_c;
    const bool hot_ntc = env_data->ntc_valid && env_data->ntc_temp_c >= k_fire_suspect_temp_c;
    const bool hot = hot_dht || hot_ntc;
    const bool smoky = env_data->air_quality_adc >= k_fire_suspect_smoke_adc;

    if (hot && smoky) {
        if (!s_fire_suspect_episode_reported && s_network_ready) {
            char detail[192];
            snprintf(detail, sizeof(detail),
                     "DHT=%.1f℃ NTC=%.1f℃(valid=%d) 烟雾ADC=%u 同时超阈，疑似火灾(需人工复核)",
                     (double)env_data->temperature,
                     (double)env_data->ntc_temp_c,
                     env_data->ntc_valid ? 1 : 0,
                     (unsigned)env_data->air_quality_adc);
            publish_floor_event("floor_fire_suspected", detail, "warning");
            ESP_LOGW(TAG, "疑似火灾告警已上报: (DHT或NTC)>=%.0f℃ 且 MQ2ADC>=%u",
                     (double)k_fire_suspect_temp_c, (unsigned)k_fire_suspect_smoke_adc);
            s_fire_suspect_episode_reported = true;
        }
    } else {
        s_fire_suspect_episode_reported = false;
    }
}

// --- 辅助组包函数 ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过楼控上线状态上报");
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/floor/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "floor");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddStringToObject(root, "firmware_version", FLOOR_FIRMWARE_VERSION);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    
    free(json_str);
    cJSON_Delete(root);
}

// 辅助函数：上报单项传感器数据 (规范 4.2.2)
void publish_sensor_data(const char *sensor_type, double value, const char *unit) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/%s/%s", GLOBAL_TOPIC_DEVICE_DATA_PREFIX, sensor_type, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "sensor_type", sensor_type);
    cJSON_AddNumberToObject(root, "value", value);
    cJSON_AddStringToObject(root, "unit", unit);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);

    free(json_str);
    cJSON_Delete(root);
}

void publish_room_sensor_data(const char *sensor_type, double value, const char *unit) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/%s/%s", GLOBAL_TOPIC_DEVICE_DATA_PREFIX, sensor_type, room_device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", room_device_id);
    cJSON_AddStringToObject(root, "sensor_type", sensor_type);
    cJSON_AddNumberToObject(root, "value", value);
    cJSON_AddStringToObject(root, "unit", unit);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }
    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);

    free(json_str);
    cJSON_Delete(root);
}

// MQTT 消息接收回调 (群控解析)
void floor_mqtt_callback(const char *topic, const char *data, int data_len) {
    ESP_LOGI(TAG, "==== 收到云端 MQTT 指令 topic=%s len=%d ====", topic ? topic : "(null)", data_len);
    
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        ESP_LOGW(TAG, "指令 JSON 解析失败");
        return;
    }

    cJSON *cmd_id_item = cJSON_GetObjectItem(root, "command_id");
    cJSON *device_id_item = cJSON_GetObjectItem(root, "device_id");
    cJSON *cmd_type_item = cJSON_GetObjectItem(root, "command_type");
    cJSON *owned_command_value = NULL;
    parse_command_value_object(root, &owned_command_value);

    int cmd_id = 0;
    char cmd_type_num_buf[24];
    const char *cmd_type_str = mqtt_cmd_get_type_str(cmd_type_item, cmd_type_num_buf, sizeof(cmd_type_num_buf));
    if (cmd_type_str == NULL) {
        char preview[80];
        if (data != NULL && data_len > 0) {
            size_t n = (size_t)data_len < sizeof(preview) - 1u ? (size_t)data_len : sizeof(preview) - 1u;
            memcpy(preview, data, n);
            preview[n] = '\0';
        } else {
            preview[0] = '\0';
        }
        ESP_LOGW(TAG, "指令未执行: 缺少或无法解析 command_type len=%d 预览: %s", data_len, preview);
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        cJSON_Delete(root);
        return;
    }
    /* command_id 可选：与当前云端一致时仅发 device_id + command_type；缺省 0 */
    if (cmd_id_item != NULL && !cJSON_IsNull(cmd_id_item)) {
        if (!mqtt_cmd_get_int(cmd_id_item, &cmd_id)) {
            char preview[80];
            if (data != NULL && data_len > 0) {
                size_t n = (size_t)data_len < sizeof(preview) - 1u ? (size_t)data_len : sizeof(preview) - 1u;
                memcpy(preview, data, n);
                preview[n] = '\0';
            } else {
                preview[0] = '\0';
            }
            ESP_LOGW(TAG, "指令未执行: command_id 非数字/十进制串 len=%d 预览: %s", data_len, preview);
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            cJSON_Delete(root);
            return;
        }
    }

    const bool has_device_id = cJSON_IsString(device_id_item) && device_id_item->valuestring != NULL;
    const char *payload_device_id = has_device_id ? device_id_item->valuestring : "";
    const char *target = topic_tail(topic);
    const bool topic_floor = (topic != NULL && strstr(topic, "/floor/") != NULL);
    const bool topic_room = (topic != NULL && strstr(topic, "/room/") != NULL);

    bool is_floor_cmd = false;
    bool is_room_cmd = false;
    if (has_device_id) {
        is_floor_cmd = is_floor_target_match(payload_device_id);
        is_room_cmd = is_room_target_match(payload_device_id);
    } else {
        is_floor_cmd = topic_floor && is_floor_target_match(target);
        is_room_cmd = topic_room && is_room_target_match(target);
    }

    ESP_LOGI(TAG, "指令解析: cmd_id=%d cmd_type=%s payload_device_id=%s topic_target=%s floor_match=%d room_match=%d",
             cmd_id,
             cmd_type_str,
             has_device_id ? payload_device_id : "(missing)",
             target,
             is_floor_cmd ? 1 : 0,
             is_room_cmd ? 1 : 0);

    if (!is_floor_cmd && !is_room_cmd) {
        ESP_LOGW(TAG, "忽略非本机指令: payload_target=%s topic_target=%s self_floor=%s self_room=%s",
                 has_device_id ? payload_device_id : "(missing)",
                 target,
                 device_id,
                 room_device_id);
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        cJSON_Delete(root);
        return;
    }

    {
        const char *result_msg = "未识别的指令";
        bool exec_success = false;

        if (is_floor_cmd) {
            ESP_LOGI(TAG, "执行楼控指令: %s", cmd_type_str);
            exec_success = execute_floor_command(cmd_type_str, &result_msg);
            publish_command_result(cmd_id, cmd_type_str, exec_success, result_msg);
            publish_floor_runtime_status();
        } else if (is_room_cmd) {
            ESP_LOGI(TAG, "执行客房代控指令: %s", cmd_type_str);
            exec_success = execute_room_command_on_floor(cmd_type_str, &result_msg);
            publish_room_command_result(cmd_id, cmd_type_str, exec_success, result_msg);
        }
        ESP_LOGI(TAG, "指令执行结束: cmd_id=%d type=%s success=%d result=%s",
                 cmd_id, cmd_type_str, exec_success ? 1 : 0, result_msg);
    }
    if (owned_command_value != NULL) {
        cJSON_Delete(owned_command_value);
    }
    cJSON_Delete(root);
}

static void auth_and_mqtt_task(void *pvParameters) {
    (void)pvParameters;
    ESP_LOGI(TAG, "开始设备注册/鉴权流程...");

    char http_api_base[128];
    load_nvs_string_with_fallback("HTTP_API_BASE", http_api_base, sizeof(http_api_base), GLOBAL_HTTP_API_BASE_DEFAULT);
    char register_url[192];
    esp_err_t url_err = service_auth_resolve_register_url(
        mqtt_broker_uri,
        (http_api_base[0] != '\0') ? http_api_base : NULL,
        register_url,
        sizeof(register_url));
    if (url_err != ESP_OK) {
        ESP_LOGE(TAG, "解析注册 URL 失败: %s，使用云端默认", esp_err_to_name(url_err));
        snprintf(register_url, sizeof(register_url), "http://8.134.166.69:9000/api/v1/devices/register");
    }
    ESP_LOGI(TAG, "设备注册 URL: %s (broker=%s)", register_url, mqtt_broker_uri);

    service_auth_perform_registration_blocking(
        register_url,
        3,
        device_id,
        "floor",
        "智慧走廊楼控",
        FLOOR_FIRMWARE_VERSION
    );

    ESP_LOGI(TAG, "鉴权通过，启动 MQTT 服务...");
    if (service_network_wait_sntp_sync(20000) != ESP_OK) {
        ESP_LOGW(TAG, "SNTP 未在 20s 内就绪，仍将启动 MQTT（请确认路由器未拦截 NTP）");
    }
    esp_err_t err = service_mqtt_start(mqtt_broker_uri, device_id);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "MQTT 启动失败: %s", esp_err_to_name(err));
        vTaskDelete(NULL);
        return;
    }

    char sub_topic[128];
    snprintf(sub_topic, sizeof(sub_topic), "%s/floor/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, device_id);
    err = service_mqtt_subscribe(sub_topic, floor_mqtt_callback);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "订阅楼控指令失败: %s", esp_err_to_name(err));
    } else {
        ESP_LOGI(TAG, "已订阅楼控指令: %s", sub_topic);
    }

    char floor_alias_topic[128];
    int floor_num = atoi(current_floor_id);
    if (floor_num > 0) {
        snprintf(floor_alias_topic, sizeof(floor_alias_topic), "%s/floor/FLO_%dF", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, floor_num);
    } else {
        snprintf(floor_alias_topic, sizeof(floor_alias_topic), "%s/floor/FLO_%sF", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, current_floor_id);
    }
    err = service_mqtt_subscribe(floor_alias_topic, floor_mqtt_callback);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "订阅楼层别名指令失败: %s", esp_err_to_name(err));
    } else {
        ESP_LOGI(TAG, "已订阅楼层别名指令: %s", floor_alias_topic);
    }

    char floor_all_topic[128];
    snprintf(floor_all_topic, sizeof(floor_all_topic), "%s/floor/all", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX);
    err = service_mqtt_subscribe(floor_all_topic, floor_mqtt_callback);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "订阅楼层广播指令失败: %s", esp_err_to_name(err));
    } else {
        ESP_LOGI(TAG, "已订阅楼层广播指令: %s", floor_all_topic);
    }

    char room_sub_topic[128];
    snprintf(room_sub_topic, sizeof(room_sub_topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, room_device_id);
    err = service_mqtt_subscribe(room_sub_topic, floor_mqtt_callback);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "订阅客房指令失败: %s", esp_err_to_name(err));
    } else {
        ESP_LOGI(TAG, "已订阅客房指令: %s", room_sub_topic);
    }

    char room_all_topic[128];
    snprintf(room_all_topic, sizeof(room_all_topic), "%s/room/all", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX);
    err = service_mqtt_subscribe(room_all_topic, floor_mqtt_callback);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "订阅客房广播指令失败: %s", esp_err_to_name(err));
    } else {
        ESP_LOGI(TAG, "已订阅客房广播指令: %s", room_all_topic);
    }

    vTaskDelay(pdMS_TO_TICKS(1000));
    publish_device_online_status();
    publish_health_report();

    vTaskDelete(NULL);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        s_network_ready = true;
        ESP_LOGI(TAG, "网络已连接，IP: %s", ip_address);
        static bool s_auth_task_started = false;
        if (!s_auth_task_started) {
            s_auth_task_started = true;
            xTaskCreate(auth_and_mqtt_task, "auth_and_mqtt", 8192, NULL, 4, NULL);
        }
    } else {
        s_network_ready = false;
        s_reconnect_count++;
        ESP_LOGW(TAG, "网络已断开，楼控进入离线降级模式");
    }
}

// 环境采样与上报任务：只负责采样+上报
void task_floor_sensor_report(void *pvParameters) {
    (void)pvParameters;
    sensor_data_t env_data;

    while (1) {
        vTaskDelay(FLOOR_SENSOR_TASK_PERIOD); // 每半分钟发一次走廊环境数据
        hal_sensors_read_all(&env_data);
        run_floor_local_policy(&env_data);

        if (!s_network_ready) {
            continue;
        }

        /*
         * 楼控装配 + 合并原客房传感器（见 floor_controller/CMakeLists.txt 引脚表）：
         *   MQ2、LDR、DHT11(GPIO20)、NTC(GPIO19)、RD-03 OT2(GPIO16)；雨棚未接。
         * 数据仍双发：floor_* 与 room_*（NVS Room_ID）主题，供后端沿用原组合判据。
         */
        if (env_data.dht_valid) {
            publish_sensor_data("temperature", env_data.temperature, "℃");
            publish_sensor_data("humidity", env_data.humidity, "%");
            // 模拟客房温湿度
            publish_room_sensor_data("temperature", env_data.temperature, "℃");
            publish_room_sensor_data("humidity", env_data.humidity, "%");
        }
        if (env_data.mq2_valid) {
            publish_sensor_data("smoke", env_data.air_quality_adc, "adc");
            // 模拟客房烟雾
            publish_room_sensor_data("smoke", env_data.air_quality_adc, "adc");
        }
        if (env_data.ldr_valid) {
            publish_sensor_data("light", env_data.light_adc, "adc");
            // 模拟客房光照
            publish_room_sensor_data("light", env_data.light_adc, "adc");
        }
        if (env_data.ntc_valid) {
            publish_sensor_data("ntc_temp", env_data.ntc_temp_c, "℃");
            publish_room_sensor_data("ntc_temp", env_data.ntc_temp_c, "℃");
        }
        if (env_data.rd03_valid) {
            publish_sensor_data("human_present", env_data.is_human_present ? 1.0 : 0.0, "bool");
            publish_room_sensor_data("human_present", env_data.is_human_present ? 1.0 : 0.0, "bool");
        }
    }
}

void task_floor_button_events(void *pvParameters) {
    (void)pvParameters;
    bool prev_alarm_pressed = false;

    while (1) {
        bool alarm_pressed = hal_interactive_is_button_pressed(BTN_FLOOR_ALARM);
        if (alarm_pressed && !prev_alarm_pressed) {
            ESP_LOGI(TAG, "楼控按键触发: 报警键");
            floor_trigger_alarm_match_physical_button();
        }
        prev_alarm_pressed = alarm_pressed;
        vTaskDelay(FLOOR_BUTTON_TASK_PERIOD);
    }
}

void task_floor_health_report(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        vTaskDelay(FLOOR_HEALTH_TASK_PERIOD);
        publish_health_report();
    }
}

#if CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE

static void net_test_mqtt_cb(const char *topic, const char *data, int data_len)
{
    ESP_LOGI(TAG, "[NET-TEST] RX topic=%s len=%d", topic, data_len);
    if (data != NULL && data_len > 0) {
        size_t n = (size_t)data_len < 255u ? (size_t)data_len : 255u;
        char buf[256];
        memcpy(buf, data, n);
        buf[n] = '\0';
        ESP_LOGI(TAG, "[NET-TEST] payload: %s", buf);
    }
}

static void net_test_on_network(bool connected, const char *ip_address)
{
    if (connected) {
        ESP_LOGI(TAG, "[NET-TEST] WiFi OK, IP=%s", ip_address ? ip_address : "?");
        esp_err_t err = service_mqtt_start(mqtt_broker_uri, device_id);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "[NET-TEST] MQTT start failed: %s", esp_err_to_name(err));
            return;
        }
        const char *topic = "hotel/net_test/broadcast";
        err = service_mqtt_subscribe(topic, net_test_mqtt_cb);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "[NET-TEST] subscribe failed: %s", esp_err_to_name(err));
        }
        vTaskDelay(pdMS_TO_TICKS(800));
        char pay[160];
        snprintf(pay, sizeof(pay), "{\"from\":\"%s\",\"msg\":\"online\"}", device_id);
        service_mqtt_publish(topic, pay);
    } else {
        ESP_LOGW(TAG, "[NET-TEST] WiFi disconnected");
    }
}

static void net_test_heartbeat_task(void *pvParameters)
{
    (void)pvParameters;
    const char *topic = "hotel/net_test/broadcast";
    char pay[192];
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(15000));
        int64_t us = esp_timer_get_time();
        snprintf(pay, sizeof(pay), "{\"from\":\"%s\",\"uptime_s\":%lld}",
                 device_id, (long long)(us / 1000000));
        service_mqtt_publish(topic, pay);
        ESP_LOGI(TAG, "[NET-TEST] heartbeat sent");
    }
}

#endif /* CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE */

// 主入口
void app_main(void) {
#if CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE
    ESP_LOGW(TAG, "========== NET TEST MODE（无外设：仅配网 + MQTT）==========");
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    load_nvs_string_with_fallback("Floor_ID", current_floor_id, sizeof(current_floor_id), "03");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri),
                                  GLOBAL_MQTT_BROKER_URI);
    snprintf(device_id, sizeof(device_id), "floor_%s", current_floor_id);

    ESP_LOGI(TAG, "[NET-TEST] client_id=%s", device_id);
    ESP_LOGI(TAG, "[NET-TEST] broker=%s", mqtt_broker_uri);
    ESP_LOGI(TAG, "[NET-TEST] topic: hotel/net_test/broadcast");

    ESP_ERROR_CHECK(service_network_provisioning_start(net_test_on_network));
    xTaskCreate(net_test_heartbeat_task, "net_hb", 4096, NULL, 5, NULL);

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(60000));
        ESP_LOGI(TAG, "[NET-TEST] main alive");
    }
#else
    ESP_LOGI(TAG, "========== 🏢 智慧走廊楼控端 启动 ==========");

    // 1. 初始化系统非易失性存储 (NVS)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    service_auth_init();

    // 2. 初始化底层硬件驱动
    hal_actuators_init();
    hal_sensors_init();
    hal_interactive_init();

    // 3. 读取并拼接规范的 Client ID
    load_nvs_string_with_fallback("Floor_ID", current_floor_id, sizeof(current_floor_id), "03");
    load_nvs_string_with_fallback("Room_ID", target_room_id, sizeof(target_room_id), "301");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri), GLOBAL_MQTT_BROKER_URI);
    snprintf(device_id, sizeof(device_id), "floor_%s", current_floor_id);
    snprintf(room_device_id, sizeof(room_device_id), "room_%s", target_room_id);
    
    // 4. 启动网络与配网服务
    service_network_provisioning_start(on_network_status_changed);

    // 5. 创建环境采样上报任务；main 仅保留守护
    xTaskCreate(task_floor_sensor_report, "floor_sensor_task", 4096, NULL, 5, NULL);
    xTaskCreate(task_floor_health_report, "floor_health_task", 4096, NULL, 5, NULL);
    xTaskCreate(task_floor_button_events, "floor_button_task", 3072, NULL, 4, NULL);
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(60000));
    }
#endif /* CONFIG_FLOOR_CONTROLLER_NET_TEST_MODE */
}
