#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "nvs_flash.h"
#include "sdkconfig.h"
#include "cJSON.h"
#include "esp_timer.h"

// 引入底层硬件抽象组件库
#include "driver_rc522.h"
#include "card_mifare_payload.h"
#include "driver_ec11.h"
#include "service_mqtt.h"
#include "hal_actuators.h"
#include "hal_sensors.h"
#include "hal_interactive.h"
#include "hal_audio.h"
#include "voice_session.h"
#include "hal_infrared.h"
#include "driver_oled.h"
#include "service_network.h"
#include "global_config.h"
#include "service_auth.h"

/** 未接灯泡、窗帘电机、门锁、红外空调接收端等时置 1：仅串口日志反馈，不驱动对应 GPIO。外设接好后改为 0。 */
#ifndef ROOM_HARDWARE_LOG_ONLY
#define ROOM_HARDWARE_LOG_ONLY 1
#endif

static const char *TAG = "ROOM_TERMINAL_MAIN";
/** 与向后台注册时的 firmware 字段一致，用于状态/健康上报。 */
#define ROOM_FIRMWARE_VERSION "v1.2.0-smart"
static char current_room_id[16] = "UNKNOWN";
static char device_id[32] = "room_UNKNOWN";
static char mqtt_broker_uri[128] = GLOBAL_MQTT_BROKER_URI;
static bool is_on_call = false;
/** 云端 incoming_call 已下发，等待 GPIO1(PTT) 短按接听 */
static bool s_call_incoming_pending = false;
static char current_call_id[64] = "";
static char remote_id[32] = "";
static volatile bool s_network_ready = false;
static uint32_t s_reconnect_count = 0;

/** 楼控 MQTT 设备号（与楼控 device_id 一致，如 floor_03）；NVS 键 Floor_Sensor_Device_Id，默认 floor_03 */
static char s_floor_sensor_device_id[40] = "";
static portMUX_TYPE s_floor_snap_mux = portMUX_INITIALIZER_UNLOCKED;
/* 楼控侧只装了 MQ2 烟雾传感器（没有 NTC），客房火灾判据只需缓存 MQ2 快照即可 */
static volatile float s_floor_mq2_adc = 0.f;
static volatile int64_t s_floor_mq2_us = 0;
static volatile bool s_floor_got_mq2 = false;
static bool s_room_fire_episode_reported = false;
static uint8_t s_last_uid[10] = {0};
static uint8_t s_last_uid_len = 0;
static bool s_last_uid_valid = false;

typedef enum {
    ROOM_SCENE_WELCOME = 0,
    ROOM_SCENE_READING,
    ROOM_SCENE_NIGHT,
    ROOM_SCENE_SLEEP
} room_scene_mode_t;

typedef struct {
    bool light_on;
    bool air_on;
    bool curtain_open;
    bool door_unlocked;
} room_runtime_state_t;

static room_runtime_state_t s_room_state = {0};
static room_scene_mode_t s_scene_mode = ROOM_SCENE_WELCOME;
static volatile bool s_auto_lock_pending = false;
static TickType_t s_auto_lock_deadline = 0;
static const char *s_last_result_code = NULL;

/* 与前台一致：Classic 扇区数据非“芯片内建密文”；链路 Crypto1 不替代应用层保密。
 * 扇区 1 首块：AES-128-ECB + PKCS#7 的 UTF-8「ROOM:<房号>」（单块 16 字节）；仍兼容旧明文 ROOM: 前缀卡。
 * 认证 Key A = FFFFFFFFFFFF（白卡默认）。密钥：NVS HotelCard_AES128Hex 或 GLOBAL_CARD_AES128_HEX_DEFAULT。 */
static const uint8_t k_default_card_key[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
static uint8_t s_card_aes_key[16];
static uint8_t s_ac_target_temp = 24;
static bool s_ec11_ready = false;

/** EC11：长按 SW（按住后释放，且按下时长达到阈值）在「音量→灯光亮度→空调温度→灯光场景」四档间循环。
 *  仅松开 SW 时旋转：调节当前档（场景档为顺/逆切换灯光场景）。 */
typedef enum {
    ROOM_EC11_MODE_VOLUME = 0,
    ROOM_EC11_MODE_BRIGHTNESS,
    ROOM_EC11_MODE_AC_TEMP,
    ROOM_EC11_MODE_SCENE,
} room_ec11_function_mode_t;

static room_ec11_function_mode_t s_ec11_function_mode = ROOM_EC11_MODE_VOLUME;
static int s_volume_pct = 60;
static int s_brightness_pct = 80;

#define ROOM_EC11_VOLUME_STEP         5
#define ROOM_EC11_BRIGHTNESS_STEP     5
#define ROOM_EC11_AC_TEMP_STEP        1
#define ROOM_EC11_AC_TEMP_MIN_C       16
#define ROOM_EC11_AC_TEMP_MAX_C       30

#define ROOM_EC11_SW_DEBOUNCE_MS      40
/** 释放时按下时长 ≥ 本值则视为「长按」：切下一功能档（四档循环） */
#define ROOM_EC11_MODE_SWITCH_HOLD_MS 650

// PTT(GPIO1=GLOBAL_PTT_BTN_PIN)：短按=来电时接听，通话中再短按=挂断；长按=唤醒 Agent（日志+事件）
static bool s_ptt_prev = false;
static TickType_t s_ptt_press_tick = 0;
static bool s_ptt_long_fired = false;
#define ROOM_PTT_LONG_PRESS_MS   850
#define ROOM_PTT_SHORT_MIN_MS    50

// 统一任务周期配置，避免散落魔法数字
static const TickType_t SENSOR_TASK_PERIOD = pdMS_TO_TICKS(15000);
static const TickType_t BUTTON_TASK_PERIOD = pdMS_TO_TICKS(60);
static const TickType_t AUTO_LOCK_TASK_PERIOD = pdMS_TO_TICKS(200);
static const TickType_t AUTO_LOCK_DELAY = pdMS_TO_TICKS(8000);
static const TickType_t RC522_TASK_PERIOD = pdMS_TO_TICKS(200);
static const TickType_t ROOM_HEARTBEAT_TASK_PERIOD = pdMS_TO_TICKS(60000);
static const TickType_t ROOM_HEALTH_TASK_PERIOD = pdMS_TO_TICKS(600000);
/* EC11 轮询越快，A/B 跳变时清零 SW 消抖越勤，越不易把旋转毛刺当成按下；与 driver_ec11 SW 稳定拍数配套调 */
static const TickType_t EC11_TASK_PERIOD = pdMS_TO_TICKS(10);
/** 红外对射起夜：轮询周期与连续遮挡判定（约 100ms × N） */
static const TickType_t IR_NIGHT_WAKE_TASK_PERIOD = pdMS_TO_TICKS(100);
#define IR_NIGHT_BLOCKED_STREAK          5
#define IR_NIGHT_COOLDOWN_MS             45000
static int s_ir_night_blocked_streak = 0;
static TickType_t s_ir_night_cooldown_until = 0;
#if !CONFIG_ROOM_TERMINAL_NET_TEST_MODE
static const TickType_t MAIN_GUARD_PERIOD = pdMS_TO_TICKS(30000);
#endif
/** OLED 1Hz 整屏重绘；所有业务只更新内存状态变量，不再直接写屏，避免覆盖与闪烁。 */
static const TickType_t OLED_REFRESH_PERIOD = pdMS_TO_TICKS(1000);

/* OLED 显示共享状态（sensor_task / network_cb / EC11 均只写这里，由 oled_task 统一出图） */
static char  s_oled_ip_tail[8]   = "---";   // 例 "131"（IP 最后一段），没网显示 "---"
static bool  s_oled_net_ok       = false;
static float s_oled_last_temp_c  = 0.f;
static float s_oled_last_hum_pct = 0.f;
static bool  s_oled_env_valid    = false;
static char  s_oled_status_line[22] = ""; // Line3 状态/结果回显；空则自动显示继电器+场景
static TickType_t s_oled_status_until = 0; // 回显有效期

/* 前向声明：MQTT 命令处理点位于文件前半，OLED 绘制函数位于文件后半 */
static void room_oled_flash_status(const char *msg, uint32_t ttl_ms);
static void room_apply_brightness_to_light(void);
static void publish_sensor_data(const char *sensor_type, double value, const char *unit);

static bool read_int_from_cmd_payload(cJSON *root, int *out_value)
{
    if (root == NULL || out_value == NULL) {
        return false;
    }
    cJSON *v = cJSON_GetObjectItem(root, "value");
    if (cJSON_IsNumber(v)) {
        *out_value = (int)v->valuedouble;
        return true;
    }
    cJSON *command_value = cJSON_GetObjectItem(root, "command_value");
    if (cJSON_IsNumber(command_value)) {
        *out_value = (int)command_value->valuedouble;
        return true;
    }
    if (cJSON_IsString(command_value) && command_value->valuestring != NULL) {
        *out_value = atoi(command_value->valuestring);
        return true;
    }
    if (cJSON_IsObject(command_value)) {
        cJSON *inner = cJSON_GetObjectItem(command_value, "value");
        if (cJSON_IsNumber(inner)) {
            *out_value = (int)inner->valuedouble;
            return true;
        }
    }
    return false;
}

static bool room_play_alarm_audio_file(void)
{
    /* 通过喇叭播放内置警报音型（短促三连 + 间隔），作为“警报音文件”内置资源实现。 */
    bool ok = true;
    for (int i = 0; i < 3; i++) {
        if (hal_audio_beep_volume_pct(s_volume_pct) != ESP_OK) {
            ok = false;
        }
        vTaskDelay(pdMS_TO_TICKS(90));
    }
    return ok;
}

static void copy_str_safe(char *dst, size_t dst_size, const char *src) {
    if (dst == NULL || dst_size == 0) {
        return;
    }
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
        ESP_LOGW(TAG, "command_value 不是合法 JSON 对象字符串");
        return NULL;
    }
    if (out_owned_json != NULL) {
        *out_owned_json = parsed;
    }
    return parsed;
}

static void publish_room_business_event(const char *event_type, const char *detail, const char *level) {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过业务事件上报: %s", event_type);
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "room");
    cJSON_AddStringToObject(root, "event_type", event_type);
    if (detail != NULL && detail[0] != '\0') {
        cJSON_AddStringToObject(root, "detail", detail);
    }

    cJSON *event_data = cJSON_CreateObject();
    cJSON_AddNumberToObject(event_data, "room_id", atoi(current_room_id));
    cJSON_AddItemToObject(root, "event_data", event_data);

    cJSON_AddStringToObject(root, "level", level);
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

/** 订阅楼控 MQTT 上的 smoke（MQ2 ADC）快照，供客房火灾二重判据使用 */
static void room_floor_sensor_mqtt_cb(const char *topic, const char *data, int data_len) {
    (void)topic;
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        return;
    }
    cJSON *did = cJSON_GetObjectItem(root, "device_id");
    cJSON *stype = cJSON_GetObjectItem(root, "sensor_type");
    cJSON *val = cJSON_GetObjectItem(root, "value");
    if (!cJSON_IsString(did) || did->valuestring == NULL ||
        strcmp(did->valuestring, s_floor_sensor_device_id) != 0) {
        cJSON_Delete(root);
        return;
    }
    if (!cJSON_IsString(stype) || stype->valuestring == NULL || !cJSON_IsNumber(val)) {
        cJSON_Delete(root);
        return;
    }
    if (strcmp(stype->valuestring, "smoke") == 0) {
        int64_t now = esp_timer_get_time();
        portENTER_CRITICAL(&s_floor_snap_mux);
        s_floor_mq2_adc = (float)val->valuedouble;
        s_floor_mq2_us = now;
        s_floor_got_mq2 = true;
        portEXIT_CRITICAL(&s_floor_snap_mux);
    }
    cJSON_Delete(root);
}

/**
 * 客房无本地 MQ2：用「楼控 MQ2 + 房内 NTC」两重与判疑似火灾（非消防认证逻辑）。
 * 早期设计是三重与（额外依赖楼控 NTC），但按当前硬件清单楼控不装 NTC，故退化为两重。
 * 阈值可通过宏调整；楼控 MQ2 数据超过 120s 未更新则本判据不成立。
 */
#define ROOM_FIRE_MQ2_ADC_THRESHOLD       400
#define ROOM_FIRE_NTC_TEMP_C            45.0f
#define ROOM_FIRE_FLOOR_DATA_MAX_AGE_US (120LL * 1000000LL)

static void room_run_fire_suspect_policy(const sensor_data_t *env) {
    if (env == NULL || s_floor_sensor_device_id[0] == '\0') {
        return;
    }
    int64_t now = esp_timer_get_time();
    float mq = 0.f;
    int64_t mqt = 0;
    bool gmq = false;
    portENTER_CRITICAL(&s_floor_snap_mux);
    gmq = s_floor_got_mq2;
    mq = s_floor_mq2_adc;
    mqt = s_floor_mq2_us;
    portEXIT_CRITICAL(&s_floor_snap_mux);

    const bool mq_fresh = gmq && (now - mqt) <= ROOM_FIRE_FLOOR_DATA_MAX_AGE_US;
    const bool smoky = mq_fresh && mq >= (float)ROOM_FIRE_MQ2_ADC_THRESHOLD;
    const bool room_hot = env->ntc_valid && env->ntc_temp_c >= ROOM_FIRE_NTC_TEMP_C;

    if (smoky && room_hot) {
        if (!s_room_fire_episode_reported && s_network_ready) {
            char detail[224];
            snprintf(detail, sizeof(detail),
                     "楼控MQ2ADC=%.0f 房内NTC=%.1f℃(两重与,需人工复核)",
                     (double)mq, (double)env->ntc_temp_c);
            publish_room_business_event("room_fire_suspected", detail, "warning");
            ESP_LOGW(TAG, "客房疑似火灾(两重与): 楼控烟雾+房内NTC超阈");
            s_room_fire_episode_reported = true;
        }
    } else {
        s_room_fire_episode_reported = false;
    }
}

static esp_err_t room_relay_set(actuator_type_t channel, bool on, const char *label_zh) {
#if ROOM_HARDWARE_LOG_ONLY
    ESP_LOGI(TAG, "【%s】%s（未接负载/仅日志）", label_zh, on ? "开" : "关");
    (void)channel;
    return ESP_OK;
#else
    esp_err_t err = hal_actuators_set_state(channel, on);
    ESP_LOGI(TAG, "【%s】%s → hal_actuators %s", label_zh, on ? "开" : "关", esp_err_to_name(err));
    return err;
#endif
}

static void publish_command_result_ex(int cmd_id, const char *cmd_type, bool exec_success, const char *result_msg, const char *result_code) {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过指令回执上报: %s", cmd_type);
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
    if (result_code != NULL && result_code[0] != '\0') {
        cJSON_AddStringToObject(reply, "result_code", result_code);
    }
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

static void publish_room_runtime_status(void) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "room");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddBoolToObject(root, "light_on", s_room_state.light_on);
    cJSON_AddBoolToObject(root, "air_on", s_room_state.air_on);
    cJSON_AddBoolToObject(root, "curtain_open", s_room_state.curtain_open);
    cJSON_AddBoolToObject(root, "door_unlocked", s_room_state.door_unlocked);
    cJSON_AddBoolToObject(root, "is_on_call", is_on_call);
    cJSON_AddBoolToObject(root, "call_incoming_pending", s_call_incoming_pending);
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

/** 合法房卡开门：与 execute_room_command(door_unlock) 一致（CH4 + 自动回锁），对齐前台刷卡后下发 door_unlock */
static bool room_local_door_unlock_via_card(void) {
    esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH4, true, "门锁(CH4)");
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "本地开门失败: %s", esp_err_to_name(err));
        return false;
    }
    s_room_state.door_unlocked = true;
    s_auto_lock_pending = true;
    s_auto_lock_deadline = xTaskGetTickCount() + AUTO_LOCK_DELAY;
    ESP_LOGI(TAG, "刷卡通过，本地开门（对齐前台 door_unlock）");
    publish_room_business_event("room_door_unlock_by_card", "房卡校验通过，本地开门", "info");
    publish_room_runtime_status();
    return true;
}

/**
 * 场景 → 氛围灯颜色映射
 *   WELCOME : 暖橙黄（欢迎、整洁感）
 *   READING : 冷白（偏暖的纯白，便于阅读）
 *   NIGHT   : 暗青蓝（小夜灯，起夜不刺眼）
 *   SLEEP   : 全熄（彻底黑）
 * 亮度已按 330Ω 限流后的可见度微调；共阳/共阴由 hal_interactive 统一处理。
 */
static void room_scene_to_rgb(room_scene_mode_t mode, uint8_t *r, uint8_t *g, uint8_t *b) {
    switch (mode) {
        case ROOM_SCENE_WELCOME: *r = 255; *g = 180; *b =  40; break; // 暖黄
        case ROOM_SCENE_READING: *r = 255; *g = 245; *b = 210; break; // 暖白
        case ROOM_SCENE_NIGHT:   *r =   0; *g =  20; *b =  80; break; // 暗青蓝
        case ROOM_SCENE_SLEEP:   *r =   0; *g =   0; *b =   0; break; // 熄灭
        default:                 *r =   0; *g =   0; *b =   0; break;
    }
}

static bool apply_room_scene(room_scene_mode_t mode, const char **out_result_msg) {
    esp_err_t err = ESP_OK;
    bool main_light = false;
    uint8_t led_r = 0;
    uint8_t led_g = 0;
    uint8_t led_b = 0;

    switch (mode) {
        case ROOM_SCENE_WELCOME:
            main_light = true;
            *out_result_msg = "已切换到迎宾场景";
            break;
        case ROOM_SCENE_READING:
            main_light = true;
            *out_result_msg = "已切换到阅读场景";
            break;
        case ROOM_SCENE_NIGHT:
            main_light = false;
            *out_result_msg = "已切换到夜灯场景";
            break;
        case ROOM_SCENE_SLEEP:
            main_light = false;
            *out_result_msg = "已切换到睡眠场景";
            break;
        default:
            *out_result_msg = "未知场景";
            return false;
    }
    room_scene_to_rgb(mode, &led_r, &led_g, &led_b);

    err = room_relay_set(ACTUATOR_RELAY_CH1, main_light, "主灯(CH1)");
    if (err != ESP_OK) {
        *out_result_msg = "场景切换失败: 主灯控制失败";
        return false;
    }

#if ROOM_HARDWARE_LOG_ONLY
    ESP_LOGI(TAG, "氛围灯（未接外设/仅日志）R=%u G=%u B=%u", (unsigned)led_r, (unsigned)led_g, (unsigned)led_b);
#else
    err = hal_interactive_set_led_color(0, led_r, led_g, led_b);
    if (err != ESP_OK) {
        *out_result_msg = "场景切换失败: 氛围灯控制失败";
        return false;
    }
#endif

    s_room_state.light_on = main_light;
    s_scene_mode = mode;

    return true;
}

/**
 * MQTT 下发的房卡指令：与前台 issue_card / write_blank_card / verify_card / swipe_card 相同加解密与扇区写入逻辑。
 * command_value 可选 JSON 对象字段 room_id；发卡类未写则使用本机 NVS 房号 current_room_id。
 */
static bool room_mqtt_handle_card_command(const char *cmd_type, cJSON *root, const char **out_result_msg) {
    cJSON *owned_command_value = NULL;
    cJSON *command_value = parse_command_value_object(root, &owned_command_value);

    if (strcmp(cmd_type, "issue_card") == 0 || strcmp(cmd_type, "write_blank_card") == 0) {
        const char *room_id = current_room_id;
        if (cJSON_IsObject(command_value)) {
            cJSON *room_item = cJSON_GetObjectItem(command_value, "room_id");
            if (cJSON_IsString(room_item) && room_item->valuestring != NULL) {
                room_id = room_item->valuestring;
            }
        }

        uint8_t block[16] = {0};
        if (!card_mifare_encrypt_room_payload(room_id, s_card_aes_key, block)) {
            *out_result_msg = "房号无效或过长，无法组包";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }

        esp_err_t err = driver_rc522_write_sector(1, k_default_card_key, block);
        if (err != ESP_OK) {
            *out_result_msg = (strcmp(cmd_type, "write_blank_card") == 0) ? "空白卡写入失败" : "开卡失败";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }
        *out_result_msg = (strcmp(cmd_type, "write_blank_card") == 0) ? "空白卡写入成功" : "开卡成功";
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        return true;
    }

    if (strcmp(cmd_type, "verify_card") == 0 || strcmp(cmd_type, "swipe_card") == 0) {
        uint8_t sector_data[16] = {0};
        esp_err_t err = driver_rc522_read_sector(1, k_default_card_key, sector_data);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "非法卡: 未检测到有效房卡 (%s)", esp_err_to_name(err));
            *out_result_msg = "未检测到有效房卡";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }

        char room_id[16] = {0};
        if (card_mifare_parse_sector_room(sector_data, s_card_aes_key, room_id, sizeof(room_id))) {
            if (strcmp(room_id, current_room_id) != 0) {
                ESP_LOGW(TAG, "非法卡: 卡房号=%s 本机=%s（验卡仅允许本房开门）", room_id, current_room_id);
                *out_result_msg = "房号与本机不符";
                if (owned_command_value != NULL) {
                    cJSON_Delete(owned_command_value);
                }
                return false;
            }
            if (!room_local_door_unlock_via_card()) {
                *out_result_msg = "门锁控制失败";
                if (owned_command_value != NULL) {
                    cJSON_Delete(owned_command_value);
                }
                return false;
            }
            *out_result_msg = "刷卡通过";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return true;
        }
        ESP_LOGW(TAG, "非法卡: 扇区内容无法解密或非本系统房卡");
        *out_result_msg = "扇区内容无法解密或非本系统房卡";
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        return false;
    }

    if (owned_command_value != NULL) {
        cJSON_Delete(owned_command_value);
    }
    *out_result_msg = "未识别的房卡指令";
    return false;
}

static bool execute_room_command(const char *cmd_type, cJSON *root, const char **out_result_msg) {
    if (strcmp(cmd_type, "issue_card") == 0 || strcmp(cmd_type, "write_blank_card") == 0 ||
        strcmp(cmd_type, "verify_card") == 0 || strcmp(cmd_type, "swipe_card") == 0) {
        return room_mqtt_handle_card_command(cmd_type, root, out_result_msg);
    }

    if (strcmp(cmd_type, "light_on") == 0) {
        esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH1, true, "主灯(CH1)");
        if (err == ESP_OK) {
            s_room_state.light_on = true;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "灯光控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "light_off") == 0) {
        esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH1, false, "主灯(CH1)");
        if (err == ESP_OK) {
            s_room_state.light_on = false;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "灯光控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "set_light_brightness") == 0 || strcmp(cmd_type, "light_brightness") == 0) {
        int b = s_brightness_pct;
        if (!read_int_from_cmd_payload(root, &b)) {
            *out_result_msg = "缺少亮度参数(value)";
            return false;
        }
        if (b < 0) {
            b = 0;
        }
        if (b > 100) {
            b = 100;
        }
        s_brightness_pct = b;
        room_apply_brightness_to_light();
        publish_sensor_data("light_brightness", (double)s_brightness_pct, "%");
        *out_result_msg = "灯光亮度已调整";
        return true;
    }

    if (strcmp(cmd_type, "air_on") == 0) {
        esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH2, true, "空调/插座(CH2)");
        if (err == ESP_OK) {
            s_room_state.air_on = true;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "空调控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "air_off") == 0) {
        esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH2, false, "空调/插座(CH2)");
        if (err == ESP_OK) {
            s_room_state.air_on = false;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "空调控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "set_ac_temp") == 0 || strcmp(cmd_type, "ac_set_temp") == 0 || strcmp(cmd_type, "ac_temp") == 0) {
        int t = (int)s_ac_target_temp;
        if (!read_int_from_cmd_payload(root, &t)) {
            *out_result_msg = "缺少空调温度参数(value)";
            return false;
        }
        if (t < ROOM_EC11_AC_TEMP_MIN_C) {
            t = ROOM_EC11_AC_TEMP_MIN_C;
        }
        if (t > ROOM_EC11_AC_TEMP_MAX_C) {
            t = ROOM_EC11_AC_TEMP_MAX_C;
        }
        s_ac_target_temp = (uint8_t)t;
        publish_sensor_data("ac_target_temp", (double)s_ac_target_temp, "C");
        *out_result_msg = "空调目标温度已调整";
        return true;
    }

    if (strcmp(cmd_type, "curtain_open") == 0) {
        esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH3, true, "窗帘(CH3)");
        if (err == ESP_OK) {
            s_room_state.curtain_open = true;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "窗帘控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "curtain_close") == 0) {
        esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH3, false, "窗帘(CH3)");
        if (err == ESP_OK) {
            s_room_state.curtain_open = false;
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "窗帘控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "door_unlock") == 0) {
        esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH4, true, "门锁(CH4)");
        if (err == ESP_OK) {
            s_room_state.door_unlocked = true;
            s_auto_lock_pending = true;
            s_auto_lock_deadline = xTaskGetTickCount() + AUTO_LOCK_DELAY;
            s_last_result_code = "door_unlock_ok";
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "门锁控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "door_lock") == 0) {
        esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH4, false, "门锁(CH4)");
        if (err == ESP_OK) {
            s_room_state.door_unlocked = false;
            s_auto_lock_pending = false;
            s_last_result_code = "door_lock_manual";
        }
        *out_result_msg = (err == ESP_OK) ? "执行成功" : "门锁控制失败";
        return (err == ESP_OK);
    }

    if (strcmp(cmd_type, "set_volume") == 0 || strcmp(cmd_type, "volume_set") == 0 || strcmp(cmd_type, "volume") == 0) {
        int vol = s_volume_pct;
        if (!read_int_from_cmd_payload(root, &vol)) {
            *out_result_msg = "缺少音量参数(value)";
            return false;
        }
        if (vol < 0) {
            vol = 0;
        }
        if (vol > 100) {
            vol = 100;
        }
        s_volume_pct = vol;
        hal_audio_set_playback_volume_pct(s_volume_pct);
        publish_sensor_data("volume", (double)s_volume_pct, "%");
        *out_result_msg = "音量已调整";
        return true;
    }

    if (strcmp(cmd_type, "broadcast_alarm") == 0 || strcmp(cmd_type, "alarm_broadcast") == 0) {
        bool ok = room_play_alarm_audio_file();
        *out_result_msg = ok ? "广播警报音已播放" : "广播警报音播放失败";
        return ok;
    }

    if (strcmp(cmd_type, "incoming_call") == 0 || strcmp(cmd_type, "hangup_call") == 0 ||
        strcmp(cmd_type, "answer_call") == 0 || strcmp(cmd_type, "reject_call") == 0 ||
        strcmp(cmd_type, "call_answered") == 0) {
        *out_result_msg = "客房端已禁用通话功能";
        return false;
    }

    if (strcmp(cmd_type, "agent_session_start") == 0) {
        uint32_t win_ms = 120000;
        cJSON *w = cJSON_GetObjectItem(root, "window_ms");
        if (cJSON_IsNumber(w) && w->valuedouble > 0) {
            win_ms = (uint32_t)w->valuedouble;
        }
        voice_session_arm_agent_window(win_ms);
        *out_result_msg = "Agent 语音窗口已开启（按住 PTT 上行）";
        return true;
    }

    if (strcmp(cmd_type, "agent_session_end") == 0) {
        voice_session_close_agent_window();
        *out_result_msg = "Agent 语音窗口已关闭";
        return true;
    }

    if (strcmp(cmd_type, "scene_welcome") == 0) {
        return apply_room_scene(ROOM_SCENE_WELCOME, out_result_msg);
    }

    if (strcmp(cmd_type, "scene_reading") == 0) {
        return apply_room_scene(ROOM_SCENE_READING, out_result_msg);
    }

    if (strcmp(cmd_type, "scene_night") == 0) {
        return apply_room_scene(ROOM_SCENE_NIGHT, out_result_msg);
    }

    if (strcmp(cmd_type, "scene_sleep") == 0) {
        return apply_room_scene(ROOM_SCENE_SLEEP, out_result_msg);
    }

    if (strcmp(cmd_type, "scene_next") == 0) {
        room_scene_mode_t next_mode = (room_scene_mode_t)((((int)s_scene_mode) + 1) % 4);
        return apply_room_scene(next_mode, out_result_msg);
    }

    if (strcmp(cmd_type, "light_scene_welcome") == 0 || strcmp(cmd_type, "scene_home") == 0) {
        return apply_room_scene(ROOM_SCENE_WELCOME, out_result_msg);
    }
    if (strcmp(cmd_type, "light_scene_reading") == 0) {
        return apply_room_scene(ROOM_SCENE_READING, out_result_msg);
    }
    if (strcmp(cmd_type, "light_scene_night") == 0) {
        return apply_room_scene(ROOM_SCENE_NIGHT, out_result_msg);
    }
    if (strcmp(cmd_type, "light_scene_sleep") == 0 || strcmp(cmd_type, "scene_leave") == 0) {
        return apply_room_scene(ROOM_SCENE_SLEEP, out_result_msg);
    }

    *out_result_msg = "未识别的指令或设备故障";
    return false;
}

// --- 辅助组包函数 (规范化数据上报) ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过上线状态上报");
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "room");
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddStringToObject(root, "firmware_version", ROOM_FIRMWARE_VERSION);
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
static void publish_sensor_data(const char *sensor_type, double value, const char *unit) {
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

static void load_card_aes_key(void) {
    char hex[40] = {0};
    if (service_network_read_nvs_string("HotelCard_AES128Hex", hex, sizeof(hex)) == ESP_OK &&
        card_mifare_parse_hex_key(hex, s_card_aes_key)) {
        ESP_LOGI(TAG, "房卡扇区密文 AES-128 密钥已从 NVS HotelCard_AES128Hex 加载");
        return;
    }
    if (card_mifare_parse_hex_key(GLOBAL_CARD_AES128_HEX_DEFAULT, s_card_aes_key)) {
        ESP_LOGW(TAG, "房卡 AES 使用 global_config 默认密钥，生产环境请写入 NVS");
    }
}

static void room_try_verify_card_sector(const char *uid_hex) {
    uint8_t sector[16] = {0};
    esp_err_t e = driver_rc522_read_sector(1, k_default_card_key, sector);
    if (e != ESP_OK) {
        ESP_LOGW(TAG, "非法卡: 无法读取扇区1或认证失败 (%s)", esp_err_to_name(e));
        publish_room_business_event("room_card_sector_read_fail", "无法读取扇区1或认证失败", "warning");
        return;
    }

    char card_room[16] = {0};
    if (!card_mifare_parse_sector_room(sector, s_card_aes_key, card_room, sizeof(card_room))) {
        ESP_LOGW(TAG, "非法卡: 扇区内容无法解密或非本系统房卡");
        publish_room_business_event("room_card_payload_invalid", "扇区内容无法解密或非本系统房卡", "warning");
        return;
    }

    char detail[64];
    snprintf(detail, sizeof(detail), "uid=%s card_room=%s", uid_hex != NULL ? uid_hex : "", card_room);
    if (strcmp(card_room, current_room_id) == 0) {
        publish_room_business_event("room_card_verified", detail, "info");
        ESP_LOGI(TAG, "房卡校验通过: 与本房一致 (%s)", card_room);
        (void)room_local_door_unlock_via_card();
    } else {
        ESP_LOGW(TAG, "非法卡: 房号不匹配 卡=%s 本房=%s", card_room, current_room_id);
        publish_room_business_event("room_card_mismatch", detail, "warning");
    }
}

static void uid_to_hex(const uint8_t *uid, uint8_t uid_len, char *out_hex, size_t out_size) {
    if (out_hex == NULL || out_size == 0) {
        return;
    }
    out_hex[0] = '\0';
    if (uid == NULL || uid_len == 0) {
        return;
    }

    size_t pos = 0;
    for (uint8_t i = 0; i < uid_len; i++) {
        if (pos + 2 >= out_size) {
            break;
        }
        int written = snprintf(out_hex + pos, out_size - pos, "%02X", uid[i]);
        if (written <= 0) {
            break;
        }
        pos += (size_t)written;
    }
}

static void publish_card_uid_event(const uint8_t *uid, uint8_t uid_len) {
    char uid_hex[32] = {0};
    uid_to_hex(uid, uid_len, uid_hex, sizeof(uid_hex));
    ESP_LOGI(TAG, "RC522 检测到卡片 UID=%s", uid_hex);

    room_try_verify_card_sector(uid_hex);

    if (!s_network_ready) {
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "room");
    cJSON_AddStringToObject(root, "event_type", "card_uid_detected");
    cJSON_AddStringToObject(root, "card_uid", uid_hex);
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
    snprintf(topic, sizeof(topic), "hotel/health/room/%s", device_id);

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "room");
    cJSON_AddStringToObject(root, "firmware_version", ROOM_FIRMWARE_VERSION);
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

static void publish_device_heartbeat(void) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddNumberToObject(root, "battery_level", 100);
    cJSON_AddNumberToObject(root, "signal_strength", -50);
    cJSON_AddNumberToObject(root, "uptime", xTaskGetTickCount() * portTICK_PERIOD_MS / 1000);
    cJSON_AddNumberToObject(root, "memory_usage", 100 - (esp_get_free_heap_size() * 100 / 327680));
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

static void publish_security_event(const char *event_type, const char *level) {
    if (!s_network_ready) {
        ESP_LOGW(TAG, "网络未就绪，跳过安防事件上报");
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "event_type", event_type);
    
    cJSON *event_data = cJSON_CreateObject();
    cJSON_AddNumberToObject(event_data, "room_id", atoi(current_room_id));
    cJSON_AddItemToObject(root, "event_data", event_data);

    cJSON_AddStringToObject(root, "level", level);
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

// 上报门禁类安全事件 (规范 4.2.5)
void publish_security_door_event() {
    publish_security_event("door_open", "info");
}

// --- 业务回调函数 ---

// MQTT 消息接收回调 (处理云端指令，规范 4.2.3 和 4.2.4)
void hotel_mqtt_callback(const char *topic, const char *data, int data_len) {
    (void)topic;
    ESP_LOGI(TAG, "==== 收到云端 MQTT 指令 ====");
    
    // 解析 JSON
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        ESP_LOGE(TAG, "JSON 解析失败，不符合规范格式");
        return;
    }

    cJSON *cmd_id_item = cJSON_GetObjectItem(root, "command_id");
    cJSON *device_id_item = cJSON_GetObjectItem(root, "device_id");
    cJSON *cmd_type_item = cJSON_GetObjectItem(root, "command_type");
    cJSON *owned_command_value = NULL;
    parse_command_value_object(root, &owned_command_value);

    if (!cJSON_IsNumber(cmd_id_item) || !cJSON_IsString(device_id_item) || !cJSON_IsString(cmd_type_item)) {
        ESP_LOGW(TAG, "云端指令缺少 command_id/device_id/command_type 字段");
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        cJSON_Delete(root);
        return;
    }

    if (strcmp(device_id_item->valuestring, device_id) != 0) {
        ESP_LOGW(TAG, "忽略非本机指令: target=%s self=%s", device_id_item->valuestring, device_id);
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        cJSON_Delete(root);
        return;
    }

    if (cJSON_IsNumber(cmd_id_item) && cJSON_IsString(cmd_type_item)) {
        int cmd_id = cmd_id_item->valueint;
        const char *cmd_type = cmd_type_item->valuestring;
        const char *result_msg = "未识别的指令或设备故障";

        ESP_LOGI(TAG, "执行指令: %s (ID: %d)", cmd_type, cmd_id);

        s_last_result_code = NULL;
        bool exec_success = execute_room_command(cmd_type, root, &result_msg);
        publish_command_result_ex(cmd_id, cmd_type, exec_success, result_msg, s_last_result_code);
        s_last_result_code = NULL;
        publish_room_runtime_status();
        
        // OLED 界面反馈（客房已无独立蜂鸣模块，声音反馈由音频 DAC 承担）
        // 临时在状态行回显命令类型，2 秒后自动恢复为默认状态
        room_oled_flash_status(cmd_type, 2000);
    }
    if (owned_command_value != NULL) {
        cJSON_Delete(owned_command_value);
    }
    cJSON_Delete(root);
}

static void auth_and_mqtt_task(void *pvParameters) {
    ESP_LOGI(TAG, "开始设备注册/鉴权流程...");

    /* 与 Web 管理端访问的「同一套后端」对齐：默认同 MQTT 主机 :9000；本地联调可设 NVS HTTP_API_BASE */
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

    // 如果是新设备，阻塞等待审核通过
    service_auth_perform_registration_blocking(
        register_url,
        3,  // hotel_id，与后台门店账号一致（酒店 3）
        device_id,
        "room",
        "智能客房终端",
        ROOM_FIRMWARE_VERSION
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
    
    // 订阅房间专属控制指令 (规范 11.4)
    char sub_topic[128];
    snprintf(sub_topic, sizeof(sub_topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, device_id);
    err = service_mqtt_subscribe(sub_topic, hotel_mqtt_callback);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "订阅客房指令失败: %s", esp_err_to_name(err));
    }

    err = voice_session_subscribe_downlink();
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "订阅音频下行失败: %s", esp_err_to_name(err));
    }

    if (s_floor_sensor_device_id[0] != '\0') {
        char t_mq2[160];
        char t_ntc[160];
        snprintf(t_mq2, sizeof(t_mq2), "%s/%s/%s", GLOBAL_TOPIC_DEVICE_DATA_PREFIX, "air_quality_adc",
                 s_floor_sensor_device_id);
        snprintf(t_ntc, sizeof(t_ntc), "%s/%s/%s", GLOBAL_TOPIC_DEVICE_DATA_PREFIX, "ntc_temp_c",
                 s_floor_sensor_device_id);
        esp_err_t e2 = service_mqtt_subscribe(t_mq2, room_floor_sensor_mqtt_cb);
        if (e2 != ESP_OK) {
            ESP_LOGW(TAG, "订阅楼控烟雾数据失败: %s", esp_err_to_name(e2));
        }
        e2 = service_mqtt_subscribe(t_ntc, room_floor_sensor_mqtt_cb);
        if (e2 != ESP_OK) {
            ESP_LOGW(TAG, "订阅楼控NTC数据失败: %s", esp_err_to_name(e2));
        }
        ESP_LOGI(TAG, "已订阅楼控环境: %s / %s", t_mq2, t_ntc);
    }

    // 延迟一小段以确保 MQTT 连接建立后再发送状态
    vTaskDelay(pdMS_TO_TICKS(1000));
    
    // 发布规范的上线状态
    publish_device_online_status();
    publish_health_report();
    
    vTaskDelete(NULL);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        s_network_ready = true;
        const char *ip_str = (ip_address != NULL) ? ip_address : "--";
        // 提取 IP 最后一段，OLED 只有 128 宽，显示末段足以定位 (同网段)
        const char *last_dot = strrchr(ip_str, '.');
        const char *tail = (last_dot != NULL && *(last_dot + 1) != '\0') ? last_dot + 1 : ip_str;
        snprintf(s_oled_ip_tail, sizeof(s_oled_ip_tail), "%s", tail);
        s_oled_net_ok = true;
        ESP_LOGI(TAG, "网络已连接，IP: %s", ip_str);
        
        static bool s_auth_task_started = false;
        if (!s_auth_task_started) {
            s_auth_task_started = true;
            xTaskCreate(auth_and_mqtt_task, "auth_and_mqtt", 8192, NULL, 4, NULL);
        }
    } else {
        s_network_ready = false;
        s_oled_net_ok = false;
        snprintf(s_oled_ip_tail, sizeof(s_oled_ip_tail), "---");
        s_reconnect_count++;
        ESP_LOGW(TAG, "网络已断开，进入离线降级模式");
    }
}

// --- 独立业务任务 (FreeRTOS) ---

// 定_时传感器采集任务
void task_sensor_monitor(void *pvParameters) {
    (void)pvParameters;
    ESP_LOGI(TAG, "传感器监控任务启动...");
    sensor_data_t env_data;
    
    while(1) {
        vTaskDelay(SENSOR_TASK_PERIOD); // 每15秒采一次，避免刷屏

        hal_sensors_read_all(&env_data);
        room_run_fire_suspect_policy(&env_data);

        if (env_data.dht_valid) {
            s_oled_last_temp_c = env_data.temperature;
            s_oled_last_hum_pct = env_data.humidity;
            s_oled_env_valid = true;
        }

        if (!s_network_ready) {
            continue;
        }

        /*
         * 客房实际装配的传感器（以硬件清单为准，2026-04）：
         *   - DHT11 温湿度
         *   - NTC 热敏电阻
         *   - RD03 毫米波人体雷达
         * 因此只上报这三类，MQ2 / LDR 在客房上不存在，HAL 即使读到浮空 ADC 也忽略，
         * 避免 "light/smoke 永远有个飘忽值" 成为假数据。
         */
        if (env_data.dht_valid) {
            publish_sensor_data("temperature", env_data.temperature, "℃");
            publish_sensor_data("humidity", env_data.humidity, "%");
        }
        if (env_data.ntc_valid) {
            publish_sensor_data("ntc_temp_c", (double)env_data.ntc_temp_c, "C");
        }
        if (env_data.rd03_valid) {
            publish_sensor_data("human_present", env_data.is_human_present ? 1.0 : 0.0, "bool");
        }
    }
}

// --- 语音通话 / Agent：上行与下行在 voice_session.c ---

void task_room_auto_lock(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        if (s_auto_lock_pending) {
            TickType_t now = xTaskGetTickCount();
            if (now >= s_auto_lock_deadline) {
                esp_err_t err = room_relay_set(ACTUATOR_RELAY_CH4, false, "门锁(CH4)");
                s_auto_lock_pending = false;
                if (err == ESP_OK) {
                    s_room_state.door_unlocked = false;
                    publish_command_result_ex(0, "door_lock", true, "门锁自动回锁完成", "door_lock_auto");
                    publish_security_event("door_auto_locked", "info");
                    publish_room_runtime_status();
                    ESP_LOGI(TAG, "门锁自动回锁完成");
                } else {
                    ESP_LOGW(TAG, "门锁自动回锁失败: %s", esp_err_to_name(err));
                }
            }
        }
        vTaskDelay(AUTO_LOCK_TASK_PERIOD);
    }
}

void task_room_button_events(void *pvParameters) {
    (void)pvParameters;
    bool prev_scene_pressed = false;
    bool prev_sos_pressed = false;

    while (1) {
        TickType_t now = xTaskGetTickCount();
        bool ptt_pressed = hal_interactive_is_button_pressed(BTN_ROOM_PTT);

        if (ptt_pressed && !s_ptt_prev) {
            s_ptt_press_tick = now;
            s_ptt_long_fired = false;
        }
        if (ptt_pressed && s_ptt_prev) {
            if (!s_ptt_long_fired && (now - s_ptt_press_tick >= pdMS_TO_TICKS(ROOM_PTT_LONG_PRESS_MS))) {
                s_ptt_long_fired = true;
                ESP_LOGI(TAG, "GPIO%d PTT 长按: 唤醒 Agent（语音助手）", GLOBAL_PTT_BTN_PIN);
                publish_room_business_event("agent_wake_requested", "长按 PTT 唤醒语音助手", "info");
                voice_session_arm_agent_window(120000);
            }
        }
        if (!ptt_pressed && s_ptt_prev) {
            TickType_t held = now - s_ptt_press_tick;
            if (!s_ptt_long_fired && held >= pdMS_TO_TICKS(ROOM_PTT_SHORT_MIN_MS)) {
                ESP_LOGI(TAG, "GPIO%d PTT 短按: 当前仅保留 Agent 长按唤醒，通话功能已禁用", GLOBAL_PTT_BTN_PIN);
                publish_room_business_event("room_ptt_short_idle", "通话功能已禁用", "info");
            }
        }
        s_ptt_prev = ptt_pressed;

        bool scene_pressed = hal_interactive_is_button_pressed(BTN_ROOM_SCENE);
        bool sos_pressed = hal_interactive_is_button_pressed(BTN_ROOM_SOS);

        if (scene_pressed && !prev_scene_pressed) {
            const char *scene_msg = "场景切换";
            room_scene_mode_t next_mode = (room_scene_mode_t)((((int)s_scene_mode) + 1) % 4);
            bool ok = apply_room_scene(next_mode, &scene_msg);
            ESP_LOGI(TAG, "本地场景按键触发: %s (ok=%d)", scene_msg, (int)ok);
            publish_room_runtime_status();
        }

        if (sos_pressed && !prev_sos_pressed) {
            publish_security_event("room_sos_pressed", "critical");
        }

        prev_scene_pressed = scene_pressed;
        prev_sos_pressed = sos_pressed;
        vTaskDelay(BUTTON_TASK_PERIOD);
    }
}

static const char *room_ec11_mode_label_cn(room_ec11_function_mode_t m) {
    switch (m) {
        case ROOM_EC11_MODE_VOLUME:
            return "音量";
        case ROOM_EC11_MODE_BRIGHTNESS:
            return "灯光亮度";
        case ROOM_EC11_MODE_AC_TEMP:
            return "空调温度";
        case ROOM_EC11_MODE_SCENE:
            return "灯光场景";
        default:
            return "?";
    }
}

/**
 * 场景短标签：OLED 5×7 字模只支持 ASCII，中文会显示成 "...."。
 * 用 3 字母缩写兼顾屏幕宽度与可读性：
 *   WEL=Welcome  RDG=Reading  NGT=Night  SLP=Sleep
 */
static const char *room_scene_label_short(room_scene_mode_t m) {
    switch (m) {
        case ROOM_SCENE_WELCOME:
            return "WEL";
        case ROOM_SCENE_READING:
            return "RDG";
        case ROOM_SCENE_NIGHT:
            return "NGT";
        case ROOM_SCENE_SLEEP:
            return "SLP";
        default:
            return "?";
    }
}

/**
 * 生成 EC11 当前档 OLED 文本（仅生成字符串，不直接写屏；写屏交给 oled_task）。
 * buf_size 建议 >= 22。
 */
static void room_ec11_format_mode_line(char *buf, size_t buf_size) {
    if (buf == NULL || buf_size == 0) {
        return;
    }
    switch (s_ec11_function_mode) {
        case ROOM_EC11_MODE_VOLUME:
            snprintf(buf, buf_size, "M:VOL %d%%", s_volume_pct);
            break;
        case ROOM_EC11_MODE_BRIGHTNESS:
            snprintf(buf, buf_size, "M:BRT %d%%", s_brightness_pct);
            break;
        case ROOM_EC11_MODE_AC_TEMP:
            snprintf(buf, buf_size, "M:AC  %uC", (unsigned)s_ac_target_temp);
            break;
        case ROOM_EC11_MODE_SCENE:
            snprintf(buf, buf_size, "M:SCN %s", room_scene_label_short(s_scene_mode));
            break;
        default:
            snprintf(buf, buf_size, "M:?");
            break;
    }
}

/**
 * 在 Line3 临时显示一条状态（命令执行结果等），持续 ttl_ms；到期后由 oled_task 回退到默认继电器+场景行。
 */
static void room_oled_flash_status(const char *msg, uint32_t ttl_ms) {
    if (msg == NULL) {
        return;
    }
    snprintf(s_oled_status_line, sizeof(s_oled_status_line), "%s", msg);
    s_oled_status_until = xTaskGetTickCount() + pdMS_TO_TICKS(ttl_ms);
}

/**
 * 4 行整屏重绘（一次性 flush，避免逐行刷新闪烁）：
 *   Line0: "R<房号> <网络> <IP 末段> <场景>" 例 "R301 OK 131 WEL"
 *   Line1: 温湿度 + 空调目标温度              例 "T24.1C H51% AC24C"
 *   Line2: EC11 当前档 + 数值                 例 "M:VOL 60%"
 *   Line3: 4 路继电器 + 场景 / 或临时命令回显 例 "L1 A0 C0 D0 Sc:WEL"
 * 由 1Hz 的 oled_task 及 EC11 即时事件调用。
 */
static void room_oled_render_all(void) {
    /* 128px 宽 OLED 一约 16 字符/行，但 GCC -Wformat-truncation 会按最坏长度估算；
     * 行缓冲略放大，避免 snprintf 被判“可能越界/截断”在 -Werror 下直接失败。 */
    char l0[48], l1[48], l2[48], l3[48];

    /* 房号最长 15 字符，但 128px OLED 一行装不下；按屏幕约束截断，避免 -Wformat-truncation */
    snprintf(l0, sizeof(l0), "R%.6s %s %.7s %s",
             current_room_id,
             s_oled_net_ok ? "OK" : "--",
             s_oled_ip_tail,
             room_scene_label_short(s_scene_mode));

    if (s_oled_env_valid) {
        snprintf(l1, sizeof(l1), "T%.1fC H%.0f%% AC%uC",
                 s_oled_last_temp_c, s_oled_last_hum_pct, (unsigned)s_ac_target_temp);
    } else {
        snprintf(l1, sizeof(l1), "T --.- H-- AC%uC", (unsigned)s_ac_target_temp);
    }

    room_ec11_format_mode_line(l2, sizeof(l2));

    if (s_oled_status_line[0] != '\0' && xTaskGetTickCount() < s_oled_status_until) {
        snprintf(l3, sizeof(l3), "%s", s_oled_status_line);
    } else {
        if (s_oled_status_line[0] != '\0') {
            s_oled_status_line[0] = '\0';
        }
        snprintf(l3, sizeof(l3), "L%d A%d C%d D%d Sc:%s",
                 s_room_state.light_on ? 1 : 0,
                 s_room_state.air_on ? 1 : 0,
                 s_room_state.curtain_open ? 1 : 0,
                 s_room_state.door_unlocked ? 1 : 0,
                 room_scene_label_short(s_scene_mode));
    }

    driver_oled_show_4_lines(l0, l1, l2, l3);
}

/* 兼容旧调用点：EC11 旋转/按键即时反馈时直接整屏重绘，不等 1Hz 周期 */
static void room_ec11_refresh_oled_mode_line(void) {
    room_oled_render_all();
}

static void room_apply_brightness_to_light(void) {
    ESP_LOGI(TAG, "主灯亮度：%d%%", s_brightness_pct);
    s_room_state.light_on = (s_brightness_pct > 0);
#if !ROOM_HARDWARE_LOG_ONLY
    bool on = s_brightness_pct > 0;
    esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, on);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "主灯继电器驱动失败: %s", esp_err_to_name(err));
    }
    uint8_t b = (uint8_t)((s_brightness_pct <= 0) ? 0 : (s_brightness_pct * 255 / 100));
    (void)hal_interactive_set_led_color(0, b, (uint8_t)((uint16_t)b * 200 / 255), (uint8_t)(b / 2));
#endif
}

void task_room_ec11_peripheral(void *pvParameters) {
    (void)pvParameters;
    static bool s_sw_prev_stable = false;
    static TickType_t s_sw_down_tick = 0;
    static bool s_sw_held = false;

    while (1) {
        if (!s_ec11_ready) {
            vTaskDelay(pdMS_TO_TICKS(200));
            continue;
        }

        driver_ec11_direction_t dir = DRIVER_EC11_DIR_NONE;
        if (driver_ec11_poll(&dir, NULL) != ESP_OK) {
            vTaskDelay(EC11_TASK_PERIOD);
            continue;
        }

        TickType_t now = xTaskGetTickCount();
        const bool sw_pressed = driver_ec11_sw_stable_pressed();

        if (GLOBAL_EC11_SW_PIN >= 0) {
            if (sw_pressed && !s_sw_prev_stable) {
                s_sw_down_tick = now;
                s_sw_held = true;
            }
            if (!sw_pressed && s_sw_prev_stable && s_sw_held) {
                TickType_t held = now - s_sw_down_tick;
                if (held >= pdMS_TO_TICKS(ROOM_EC11_SW_DEBOUNCE_MS) &&
                    held >= pdMS_TO_TICKS(ROOM_EC11_MODE_SWITCH_HOLD_MS)) {
                    s_ec11_function_mode = (room_ec11_function_mode_t)((((int)s_ec11_function_mode) + 1) % 4);
                    char detail[48];
                    snprintf(detail, sizeof(detail), "当前:%s", room_ec11_mode_label_cn(s_ec11_function_mode));
                    publish_room_business_event("room_ec11_mode_switch", detail, "info");
                    ESP_LOGI(TAG, "EC11 长按 SW：%s", room_ec11_mode_label_cn(s_ec11_function_mode));
                    room_ec11_refresh_oled_mode_line();
                }
                s_sw_held = false;
            }
            s_sw_prev_stable = sw_pressed;
        }

        /* 按住 SW 时不处理旋转，避免与长按切档语义冲突；仅松手后旋钮调节当前档 */
        if (dir != DRIVER_EC11_DIR_NONE && !sw_pressed) {
            switch (s_ec11_function_mode) {
                case ROOM_EC11_MODE_VOLUME: {
                    const int prev_vol = s_volume_pct;
                    int step = (dir == DRIVER_EC11_DIR_CW) ? ROOM_EC11_VOLUME_STEP : -ROOM_EC11_VOLUME_STEP;
                    s_volume_pct += step;
                    if (s_volume_pct < 0) {
                        s_volume_pct = 0;
                    }
                    if (s_volume_pct > 100) {
                        s_volume_pct = 100;
                    }
                    if (s_volume_pct != prev_vol) {
                        hal_audio_set_playback_volume_pct(s_volume_pct);
                        if (hal_audio_beep_volume_pct(s_volume_pct) != ESP_OK) {
                            ESP_LOGD(TAG, "音量档位提示音未播放（音频未就绪或 I2S 忙）");
                        }
                    }
                    driver_ec11_clear_rotation_accumulator();
                    publish_sensor_data("volume", (double)s_volume_pct, "%");
#if ROOM_HARDWARE_LOG_ONLY
                    ESP_LOGI(TAG, "音量：%d%%（未接外设/仅日志）", s_volume_pct);
#else
                    ESP_LOGI(TAG, "音量：%d%%", s_volume_pct);
#endif
                    room_ec11_refresh_oled_mode_line();
                    break;
                }
                case ROOM_EC11_MODE_BRIGHTNESS: {
                    int step = (dir == DRIVER_EC11_DIR_CW) ? ROOM_EC11_BRIGHTNESS_STEP : -ROOM_EC11_BRIGHTNESS_STEP;
                    s_brightness_pct += step;
                    if (s_brightness_pct < 0) {
                        s_brightness_pct = 0;
                    }
                    if (s_brightness_pct > 100) {
                        s_brightness_pct = 100;
                    }
                    room_apply_brightness_to_light();
                    publish_sensor_data("light_brightness", (double)s_brightness_pct, "%");
                    ESP_LOGI(TAG, "EC11 灯光亮度: %d%%", s_brightness_pct);
                    room_ec11_refresh_oled_mode_line();
                    break;
                }
                case ROOM_EC11_MODE_AC_TEMP: {
                    int delta = (dir == DRIVER_EC11_DIR_CW) ? ROOM_EC11_AC_TEMP_STEP : -ROOM_EC11_AC_TEMP_STEP;
                    int t = (int)s_ac_target_temp + delta;
                    if (t < ROOM_EC11_AC_TEMP_MIN_C) {
                        t = ROOM_EC11_AC_TEMP_MIN_C;
                    }
                    if (t > ROOM_EC11_AC_TEMP_MAX_C) {
                        t = ROOM_EC11_AC_TEMP_MAX_C;
                    }
                    s_ac_target_temp = (uint8_t)t;
                    publish_sensor_data("ac_target_temp", (double)s_ac_target_temp, "C");
                    ESP_LOGI(TAG, "空调目标温度: %u℃（继电器模拟，无红外真机）", (unsigned)s_ac_target_temp);
                    room_ec11_refresh_oled_mode_line();
                    break;
                }
                case ROOM_EC11_MODE_SCENE: {
                    room_scene_mode_t next = s_scene_mode;
                    if (dir == DRIVER_EC11_DIR_CW) {
                        next = (room_scene_mode_t)((((int)s_scene_mode) + 1) % 4);
                    } else {
                        next = (room_scene_mode_t)((((int)s_scene_mode) + 3) % 4);
                    }
                    const char *scene_msg = "";
                    bool ok = apply_room_scene(next, &scene_msg);
                    ESP_LOGI(TAG, "EC11 场景: %s ok=%d", scene_msg, (int)ok);
                    publish_room_runtime_status();
                    room_ec11_refresh_oled_mode_line();
                    break;
                }
                default:
                    break;
            }
        }

        vTaskDelay(EC11_TASK_PERIOD);
    }
}

void task_room_rc522_poll(void *pvParameters) {
    (void)pvParameters;

    while (1) {
        uint8_t uid[10] = {0};
        uint8_t uid_len = 0;
        esp_err_t err = driver_rc522_read_uid(uid, &uid_len);

        if (err == ESP_OK && uid_len > 0) {
            bool is_new_card = (!s_last_uid_valid) ||
                               (uid_len != s_last_uid_len) ||
                               (memcmp(uid, s_last_uid, uid_len) != 0);
            if (is_new_card) {
                memcpy(s_last_uid, uid, uid_len);
                s_last_uid_len = uid_len;
                s_last_uid_valid = true;
                publish_card_uid_event(uid, uid_len);
            }
        } else if (err == ESP_ERR_NOT_FOUND) {
            s_last_uid_valid = false;
            s_last_uid_len = 0;
        }

        vTaskDelay(RC522_TASK_PERIOD);
    }
}

void task_room_heartbeat(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        vTaskDelay(ROOM_HEARTBEAT_TASK_PERIOD);
        publish_device_heartbeat();
    }
}

void task_room_health_report(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        vTaskDelay(ROOM_HEALTH_TASK_PERIOD);
        publish_health_report();
    }
}

/**
 * 红外对射起夜：TX 发短载波，RX（解调头）收不到则视为光束被遮挡 → 起夜。
 * 去抖后打日志、上报业务事件，并切换到夜灯场景（弱氛围 + 主灯关）。
 */
void task_room_ir_night_wake(void *pvParameters) {
    (void)pvParameters;
    ESP_LOGI(TAG, "红外起夜检测任务启动（对射遮挡判起夜）");
    while (1) {
        vTaskDelay(IR_NIGHT_WAKE_TASK_PERIOD);
        bool obstructed = false;
        if (hal_infrared_barrier_poll(&obstructed) != ESP_OK) {
            continue;
        }
        TickType_t now = xTaskGetTickCount();
        if (now < s_ir_night_cooldown_until) {
            if (!obstructed) {
                s_ir_night_blocked_streak = 0;
            }
            continue;
        }
        if (obstructed) {
            s_ir_night_blocked_streak++;
        } else {
            s_ir_night_blocked_streak = 0;
        }
        if (s_ir_night_blocked_streak < IR_NIGHT_BLOCKED_STREAK) {
            continue;
        }
        s_ir_night_blocked_streak = 0;
        s_ir_night_cooldown_until = now + pdMS_TO_TICKS(IR_NIGHT_COOLDOWN_MS);
        ESP_LOGI(TAG, "检测到起夜：红外对射被遮挡（接收端未收到载波），开启起夜灯（夜灯场景）");
        publish_room_business_event("room_night_wake_ir", "红外对射遮挡", "info");
        const char *scene_msg = "";
        (void)apply_room_scene(ROOM_SCENE_NIGHT, &scene_msg);
        publish_room_runtime_status();
        ESP_LOGI(TAG, "起夜灯场景: %s", scene_msg);
    }
}

/**
 * 1Hz 重绘 4 行 OLED：
 *   Line0: "R<房号> <网络> <IP 末段> <场景>"    例 "R301 OK 131 WEL"
 *   Line1: "T24.1C H51% AC24C"                环境温湿度 + 空调目标温度
 *   Line2: "M:VOL 60%" / "M:SCN WEL" ...       EC11 当前档 + 数值
 *   Line3: 4 路继电器 + 场景，或临时命令回显
 */
void task_room_oled_refresh(void *pvParameters) {
    (void)pvParameters;
    ESP_LOGI(TAG, "OLED 刷新任务启动（1Hz 整屏重绘）");
    while (1) {
        room_oled_render_all();
        vTaskDelay(OLED_REFRESH_PERIOD);
    }
}

#if CONFIG_ROOM_TERMINAL_NET_TEST_MODE

/** 多块板互通测试：统一订阅/发布同一 topic，串口可看到彼此 payload */
static void net_test_mqtt_cb(const char *topic, const char *data, int data_len)
{
    ESP_LOGI(TAG, "[联调模式] 收到消息 topic=%s len=%d", topic, data_len);
    if (data != NULL && data_len > 0) {
        size_t n = (size_t)data_len < 255u ? (size_t)data_len : 255u;
        char buf[256];
        memcpy(buf, data, n);
        buf[n] = '\0';
        ESP_LOGI(TAG, "[联调模式] 消息内容: %s", buf);
    }
}

static void net_test_on_network(bool connected, const char *ip_address)
{
    if (connected) {
        ESP_LOGI(TAG, "[联调模式] WiFi 已连接，IP=%s", ip_address ? ip_address : "?");
        esp_err_t err = service_mqtt_start(mqtt_broker_uri, device_id);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "[联调模式] MQTT 启动失败: %s", esp_err_to_name(err));
            return;
        }
        const char *topic = "hotel/net_test/broadcast";
        err = service_mqtt_subscribe(topic, net_test_mqtt_cb);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "[联调模式] 订阅失败: %s", esp_err_to_name(err));
        }
        vTaskDelay(pdMS_TO_TICKS(800));
        char pay[160];
        snprintf(pay, sizeof(pay), "{\"from\":\"%s\",\"msg\":\"online\"}", device_id);
        service_mqtt_publish(topic, pay);
    } else {
        ESP_LOGW(TAG, "[联调模式] WiFi 已断开");
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
        ESP_LOGI(TAG, "[联调模式] 心跳已发送");
    }
}

#endif /* CONFIG_ROOM_TERMINAL_NET_TEST_MODE */

// 主入口
void app_main(void)
{
#if CONFIG_ROOM_TERMINAL_NET_TEST_MODE
    ESP_LOGW(TAG, "========== 联调模式（无外设：仅配网 + MQTT）==========");
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    load_nvs_string_with_fallback("Room_ID", current_room_id, sizeof(current_room_id), "301");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri),
                                  GLOBAL_MQTT_BROKER_URI);
    snprintf(device_id, sizeof(device_id), "room_%s", current_room_id);

    ESP_LOGI(TAG, "[联调模式] client_id=%s", device_id);
    ESP_LOGI(TAG, "[联调模式] broker=%s", mqtt_broker_uri);
    ESP_LOGI(TAG, "[联调模式] topic=hotel/net_test/broadcast");

    ESP_ERROR_CHECK(service_network_provisioning_start(net_test_on_network));
    xTaskCreate(net_test_heartbeat_task, "net_hb", 4096, NULL, 5, NULL);

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(60000));
        ESP_LOGI(TAG, "[联调模式] 主循环保活");
    }
#else
    ESP_LOGI(TAG, "========== 🏨 智慧客房边缘控制终端 启动 ==========");

    // 1. 初始化系统非易失性存储 (NVS)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    
    load_card_aes_key();

    // 初始化认证组件 (读取 device_key)
    service_auth_init();

    // 2. 初始化所有的底层硬件驱动模块 (串行 + 间隔上电，避免瞬时电流峰值触发 BOD)
    //    每个外设上电会有瞬时浪涌（音频功放/LED/SPI/I2S/GPIO 上拉等），
    //    集中初始化时累计电流可能拉低 3.3V 触发 Brownout，
    //    因此这里改为"一个一个启动 + 50~80ms 缓冲延迟"。
    ESP_LOGI(TAG, "--- 硬件底层驱动加载 (顺序错峰) ---");

    #define ROOM_PERIPH_GAP_MS    60   /* 普通外设间隔 */
    #define ROOM_PERIPH_GAP_BIG   120  /* 含功放/电流尖峰外设间隔 */

    ESP_LOGI(TAG, "[boot] 1/8 OLED");
    driver_oled_init();
    vTaskDelay(pdMS_TO_TICKS(ROOM_PERIPH_GAP_MS));

    ESP_LOGI(TAG, "[boot] 2/8 RC522");
    driver_rc522_init();
    vTaskDelay(pdMS_TO_TICKS(ROOM_PERIPH_GAP_MS));

    ESP_LOGI(TAG, "[boot] 3/8 actuators (继电器/驱动)");
    hal_actuators_init();
    vTaskDelay(pdMS_TO_TICKS(ROOM_PERIPH_GAP_MS));

    ESP_LOGI(TAG, "[boot] 4/8 sensors");
    hal_sensors_init();
    vTaskDelay(pdMS_TO_TICKS(ROOM_PERIPH_GAP_MS));

    ESP_LOGI(TAG, "[boot] 5/8 interactive (RGB/按键/蜂鸣)");
    hal_interactive_init();
    vTaskDelay(pdMS_TO_TICKS(ROOM_PERIPH_GAP_MS));

    ESP_LOGI(TAG, "[boot] 6/8 audio (I2S/MIC/功放)");
    hal_audio_init();
    /* 功放上电浪涌较大，先延迟再设置音量，避免与下一个外设的初始化叠加 */
    vTaskDelay(pdMS_TO_TICKS(ROOM_PERIPH_GAP_BIG));
    hal_audio_set_playback_volume_pct(s_volume_pct);
    vTaskDelay(pdMS_TO_TICKS(ROOM_PERIPH_GAP_MS));

    ESP_LOGI(TAG, "[boot] 7/8 infrared");
    hal_infrared_init();
    vTaskDelay(pdMS_TO_TICKS(ROOM_PERIPH_GAP_MS));

    ESP_LOGI(TAG, "[boot] 8/8 EC11");
    if (GLOBAL_EC11_A_PIN >= 0 && GLOBAL_EC11_B_PIN >= 0) {
        esp_err_t ec_err = driver_ec11_init(GLOBAL_EC11_A_PIN, GLOBAL_EC11_B_PIN, GLOBAL_EC11_SW_PIN);
        if (ec_err == ESP_OK) {
            s_ec11_ready = true;
            ESP_LOGI(TAG, "EC11 初始化成功");
        } else {
            ESP_LOGW(TAG, "EC11 初始化失败: %s", esp_err_to_name(ec_err));
        }
    } else {
        ESP_LOGW(TAG, "EC11 未配置有效 A/B 脚，跳过");
    }
    vTaskDelay(pdMS_TO_TICKS(ROOM_PERIPH_GAP_MS));

    driver_oled_clear_screen();
    // OLED 仅支持 5x7 ASCII 字模；中文会渲染为 "...."，统一用英文占位到 oled_task 接管
    driver_oled_show_text_line(0, "Booting...");

    // 3. 从 NVS 读取当前房号，严格拼接规范的 Client ID
    load_nvs_string_with_fallback("Room_ID", current_room_id, sizeof(current_room_id), "301");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri), GLOBAL_MQTT_BROKER_URI);
    snprintf(device_id, sizeof(device_id), "room_%s", current_room_id);
    load_nvs_string_with_fallback("Floor_Sensor_Device_Id", s_floor_sensor_device_id,
                                  sizeof(s_floor_sensor_device_id), "floor_03");

    voice_session_init(device_id, &s_network_ready, &is_on_call, &s_call_incoming_pending, current_call_id,
                       sizeof(current_call_id));

    char boot_msg[32];
    snprintf(boot_msg, sizeof(boot_msg), "R%s Waiting WiFi", current_room_id);
    driver_oled_show_text_line(0, boot_msg);
    if (s_ec11_ready) {
        room_ec11_refresh_oled_mode_line();
    }
    // 启动时给一轮初始渲染（网络未连前提示等待），之后交给 oled_task 1Hz 接管
    room_oled_render_all();

    // 4. 启动网络与配网服务
    //    Wi-Fi PA 启动瞬间是全板第二大电流尖峰（仅次于音频功放出声时）。
    //    在硬件外设全部完成 + OLED 渲染后再起 Wi-Fi，并给 200ms 让 LDO 稳定。
    ESP_LOGI(TAG, "--- 启动网络服务 ---");
    vTaskDelay(pdMS_TO_TICKS(150));
    service_network_provisioning_start(on_network_status_changed);
    /* Wi-Fi 初始化和扫描会在后台拉电流，给主线 200ms 缓冲再去创建任务 */
    vTaskDelay(pdMS_TO_TICKS(200));

    // 5. 挂载持续运行的业务逻辑任务 (错峰创建，避免大量任务同帧抢 CPU+外设)
    ESP_LOGI(TAG, "--- 挂载 FreeRTOS 任务 (错峰创建) ---");
    #define ROOM_TASK_GAP_MS  40

    // sensor_task: 只负责采集+上报
    xTaskCreatePinnedToCore(task_sensor_monitor, "sensor_task", 4096, NULL, 5, NULL, 1);
    vTaskDelay(pdMS_TO_TICKS(ROOM_TASK_GAP_MS));

    // voice_task: 电话连续上行 + Agent 窗口内按住 PTT 上行；下行见 voice_downlink_mqtt_cb
    /* voice_task 栈较大且会占用 I2S，单独留 80ms 让其平稳进入 idle 等待 */
    xTaskCreate(voice_uplink_task, "voice_task", 12288, NULL, 5, NULL);
    vTaskDelay(pdMS_TO_TICKS(80));

    // auto_lock_task: 门锁自动回锁守护
    xTaskCreate(task_room_auto_lock, "room_auto_lock_task", 3072, NULL, 4, NULL);
    vTaskDelay(pdMS_TO_TICKS(ROOM_TASK_GAP_MS));

    // button_task: 客房场景/SOS 按键业务
    xTaskCreate(task_room_button_events, "room_button_task", 3072, NULL, 4, NULL);
    vTaskDelay(pdMS_TO_TICKS(ROOM_TASK_GAP_MS));

    // ec11_task: 长按 SW 松手切四档(音量→亮度→空调温→场景)；仅松手后旋转调当前量
    xTaskCreate(task_room_ec11_peripheral, "room_ec11_task", 4096, NULL, 4, NULL);
    vTaskDelay(pdMS_TO_TICKS(ROOM_TASK_GAP_MS));

    // rc522_task: RC522 常驻轮询，检测房卡 UID
    xTaskCreate(task_room_rc522_poll, "room_rc522_task", 4096, NULL, 4, NULL);
    vTaskDelay(pdMS_TO_TICKS(ROOM_TASK_GAP_MS));

    // heartbeat_task: 客房状态心跳
    xTaskCreate(task_room_heartbeat, "room_heartbeat_task", 4096, NULL, 4, NULL);
    vTaskDelay(pdMS_TO_TICKS(ROOM_TASK_GAP_MS));

    // health_task: 客房健康上报
    xTaskCreate(task_room_health_report, "room_health_task", 4096, NULL, 4, NULL);
    vTaskDelay(pdMS_TO_TICKS(ROOM_TASK_GAP_MS));

    // ir_night: 红外对射遮挡判起夜，开夜灯场景
    xTaskCreate(task_room_ir_night_wake, "room_ir_night", 3072, NULL, 4, NULL);
    vTaskDelay(pdMS_TO_TICKS(ROOM_TASK_GAP_MS));

    // oled_task: 1Hz 重绘 4 行固定布局；业务只写内存状态
    xTaskCreate(task_room_oled_refresh, "room_oled_task", 3072, NULL, 3, NULL);
    vTaskDelay(pdMS_TO_TICKS(ROOM_TASK_GAP_MS));

    ESP_LOGI(TAG, "--- 所有任务已挂载完成 ---");

    // 6. main 仅做守护，不注入模拟业务动作，避免干扰真实联调
    while (1) {
        vTaskDelay(MAIN_GUARD_PERIOD);
        ESP_LOGI(TAG, "主循环保活: room=%s net=%d", current_room_id, (int)s_network_ready);
    }
#endif /* CONFIG_ROOM_TERMINAL_NET_TEST_MODE */
}
