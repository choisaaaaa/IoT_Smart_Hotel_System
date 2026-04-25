#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <strings.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_http_client.h"
#include "nvs_flash.h"
#include "sdkconfig.h"
#include "cJSON.h"

#include "hal_interactive.h"
#include "hal_actuators.h"
#include "hal_audio.h"
#include "service_mqtt.h"
#include "service_network.h"
#include "driver_rc522.h"
#include "card_mifare_payload.h"
#include "global_config.h"
#include "service_auth.h"
#include "voice_session.h"
#include "card_voice_playback.h"
#include "driver_ec11.h"
#include "driver_oled.h"

#ifndef FRONT_DESK_MINIMAL_HW
#define FRONT_DESK_MINIMAL_HW 0
#endif

/*
 * 公网若按「设备号 / 固件版本 / 镜像版本」识别终端：
 * - 前台构建：device_id = front_desk_<后缀>，NVS 键 FrontDesk_ID
 * - 客房主控构建：device_id = room_<房号>，NVS 键 Room_ID（与 room_terminal 一致）
 * 角色由 menuconfig「终端产品角色」决定，改角色后需重编并刷机；后台 devices 须同类型审核。
 */
#ifndef FRONT_DESK_ID_DEFAULT
#define FRONT_DESK_ID_DEFAULT "02"
#endif
#define FRONT_FIRMWARE_VERSION "v1.4.0"

#if CONFIG_TERMINAL_ROLE_ROOM
#define TERMINAL_MQTT_TOPIC_SUFFIX "room"
#define TERMINAL_DEVICE_TYPE_JSON  "room"
#define TERMINAL_REGISTRATION_TYPE "room"
#define TERMINAL_REGISTRATION_NAME "智能客房终端"
#define TERMINAL_BOOT_BANNER_TEXT  "🏠 智慧客房主控"
#define SOS_ALARM_LOCAL_MSG        "客房本地报警键触发"
#else
#define TERMINAL_MQTT_TOPIC_SUFFIX "front_desk"
#define TERMINAL_DEVICE_TYPE_JSON  "front_desk"
#define TERMINAL_REGISTRATION_TYPE "front_desk"
#define TERMINAL_REGISTRATION_NAME "智能前台终端"
#define TERMINAL_BOOT_BANNER_TEXT  "🛎️ 智慧前台管理端"
#define SOS_ALARM_LOCAL_MSG        "前台本地报警键触发"
#endif

static const char *TAG = "FRONT_DESK_MAIN";
#if CONFIG_TERMINAL_ROLE_ROOM
static char device_id[32] = "room_UNKNOWN";
#else
static char device_id[32] = "front_desk_" FRONT_DESK_ID_DEFAULT;
#endif
static char mqtt_broker_uri[128] = GLOBAL_MQTT_BROKER_URI;
static const TickType_t FRONT_HEARTBEAT_TASK_PERIOD = pdMS_TO_TICKS(60000);
static const TickType_t FRONT_BUTTON_TASK_PERIOD = pdMS_TO_TICKS(60); /* 与客房 BUTTON_TASK_PERIOD 一致 */
static const TickType_t FRONT_RC522_TASK_PERIOD = pdMS_TO_TICKS(200);
static const TickType_t FRONT_HEALTH_TASK_PERIOD = pdMS_TO_TICKS(600000);
static const TickType_t FRONT_WIFI_STABILIZE_DELAY = pdMS_TO_TICKS(3000);
static volatile bool s_network_ready = false;
static volatile bool s_peripherals_ready = false;
static volatile bool s_auth_task_started = false;
static uint32_t s_reconnect_count = 0;
static char target_room_id[16] = "301";
/** 与客房一致：楼控 device_id（如 floor_03），用于订阅走廊温湿度 hotel/device/data/{temp|humidity}/... */
static char s_floor_sensor_device_id[40] = "";
static bool s_floor_got_temp = false;
static bool s_floor_got_hum = false;
static float s_floor_ntc_c = 0.f;
static float s_floor_smoke_adc = 0.f;
static bool s_floor_human = false;
static bool s_floor_got_ntc = false;
static bool s_floor_got_smoke = false;
static bool s_floor_got_human = false;
static uint32_t s_command_seq = 1000;
static uint32_t s_call_seq = 1;
static const uint8_t k_default_card_key[6] __attribute__((unused)) = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
static uint8_t s_card_aes_key[16];
static char s_last_card_room_id[16] = "";
/** 仅 MQTT「查卡/验卡」成功时为真，用于 command 回调联动 door_unlock（开卡/清卡不误触发） */
static bool s_front_mqtt_verify_ok_for_door = false;
static uint8_t s_last_uid[10] = {0};
static uint8_t s_last_uid_len = 0;
static bool s_last_uid_valid = false;

/** 单路继电器 CH1：仅演示「空调/门锁」；灯光亮度由 RGB 独立表现，不再用 CH1 当灯 */
static bool s_front_relay_latched_on = false;

static bool is_on_call = false;
static bool s_call_incoming_pending = false;
static char current_call_id[64] = "";
static int s_volume_pct = 60;
/** EC11 / 遥控灯光亮度：仅驱动 RGB，不改变空调继电器 */
static int s_brightness_pct = 80;
static uint8_t s_ac_target_temp = 24;

typedef enum {
    FRONT_SCENE_WELCOME = 0,
    FRONT_SCENE_READING,
    FRONT_SCENE_NIGHT,
    FRONT_SCENE_SLEEP
} front_scene_mode_t;
static front_scene_mode_t s_scene_mode = FRONT_SCENE_WELCOME;

/* PTT（GLOBAL_PTT_BTN_PIN）：仅长按唤醒 Agent，短按无动作 */
static bool s_ptt_prev = false;
static TickType_t s_ptt_press_tick = 0;
static bool s_ptt_long_fired = false;
#define FRONT_PTT_LONG_PRESS_MS   850

/* BTN_ROOM_SOS（GLOBAL_BTN_ROOM_1_PIN）：与客房一致，边沿触发上报 sos_alarm */
static bool s_sos_prev = false;

/** EC11：逻辑与客房端 task_room_ec11_peripheral 对齐（长按 SW 松手切四档；松开后旋转调当前量） */
static bool s_ec11_ready = false;
typedef enum {
    FRONT_EC11_MODE_VOLUME = 0,
    FRONT_EC11_MODE_BRIGHTNESS,
    FRONT_EC11_MODE_AC_TEMP,
    FRONT_EC11_MODE_SCENE
} front_ec11_function_mode_t;
static front_ec11_function_mode_t s_ec11_function_mode = FRONT_EC11_MODE_VOLUME;

#define FRONT_EC11_VOLUME_STEP         5
#define FRONT_EC11_BRIGHTNESS_STEP     5
#define FRONT_EC11_AC_TEMP_STEP        1
#define FRONT_EC11_AC_TEMP_MIN_C       16
#define FRONT_EC11_AC_TEMP_MAX_C       30
#define FRONT_EC11_SW_DEBOUNCE_MS      40
#define FRONT_EC11_MODE_SWITCH_HOLD_MS 650
static const TickType_t EC11_TASK_PERIOD = pdMS_TO_TICKS(10);

/** OLED：与客房 room_oled_* 相同 4 行布局；前台无 DHT 时 Line1 为温湿度占位 */
static const TickType_t FRONT_OLED_REFRESH_PERIOD = pdMS_TO_TICKS(1000);
static char  s_oled_ip_tail[8]   = "---";
static bool  s_oled_net_ok       = false;
static float s_oled_last_temp_c  = 0.f;
static float s_oled_last_hum_pct = 0.f;
static bool  s_oled_env_valid    = false;
static char  s_oled_status_line[22] = "";
static TickType_t s_oled_status_until = 0;

static void publish_room_command(const char *room_id, const char *command_type);
static bool handle_voice_control_command(const char *cmd_type, cJSON *root, const char **result_msg);
static void publish_front_sensor_data(const char *sensor_type, double value, const char *unit);
static void front_apply_light_rgb_from_brightness(void);
static bool apply_front_scene(front_scene_mode_t mode, const char **out_result_msg);
void task_front_ec11_peripheral(void *pvParameters);
void publish_device_heartbeat(void);
static void front_oled_flash_status(const char *msg, uint32_t ttl_ms);
static void front_oled_render_all(void);
static void front_ec11_refresh_oled_mode_line(void);
void task_front_oled_refresh(void *pvParameters);
static void front_floor_env_mqtt_cb(const char *topic, const char *data, int data_len);
static esp_err_t front_desk_run_door_pulse(void);
static void uid_to_hex(const uint8_t *uid, uint8_t uid_len, char *out_hex, size_t out_size);
static bool front_http_rfid_verify(const char *uid_hex, const char *room_number_str);

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
        ESP_LOGD(TAG, "command_value 非 JSON 对象字符串，已忽略");
        return NULL;
    }
    if (out_owned_json != NULL) {
        *out_owned_json = parsed;
    }
    return parsed;
}

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
    if (service_network_read_nvs_string(key, out, out_size) != ESP_OK) {
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

/** 与楼控 floor_controller 一致：payload 为 all 或本机 device_id，或由订阅 topic 尾段推断本机 */
static bool is_front_target_match(const char *target)
{
    if (target == NULL || target[0] == '\0') {
        return false;
    }
    return eq_nocase(target, "all") || eq_nocase(target, device_id);
}

/** 与楼控一致：command_id 可为 JSON number，或 "123" 十进制串 */
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

/** command_type 一般为 string；也允许 number（与楼控联调弱类型对端） */
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

static void publish_front_status_payload(cJSON *root) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/%s/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, TERMINAL_MQTT_TOPIC_SUFFIX, device_id);

    /* 签名：与后端 sortObject+JSON.stringify 一致（键 ASCII 排序） */
    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    free(json_str);
}

static void publish_front_event(const char *event_type, const char *detail) {
    if (!s_network_ready) {
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", TERMINAL_DEVICE_TYPE_JSON);
    cJSON_AddStringToObject(root, "event_type", event_type);
    cJSON_AddStringToObject(root, "detail", detail);
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

/** 与后端 handleSecurityEvent 中 sos_alarm + device_alarms 分支对齐（含 data.room_id / message） */
static void publish_front_sos_alarm_msg(const char *message) {
    if (!s_network_ready || message == NULL) {
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", TERMINAL_DEVICE_TYPE_JSON);
    cJSON_AddStringToObject(root, "event_type", "sos_alarm");
    cJSON_AddStringToObject(root, "level", "critical");

    cJSON *dat = cJSON_CreateObject();
    cJSON_AddStringToObject(dat, "message", message);
    cJSON_AddStringToObject(dat, "room_id", target_room_id);
    cJSON_AddItemToObject(root, "data", dat);

    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(GLOBAL_TOPIC_SECURITY_EVENT, json_str);
    free(json_str);
    cJSON_Delete(root);
    ESP_LOGW(TAG, "已上报 sos_alarm: %s (room=%s)", message, target_room_id);
}

static void publish_front_sos_alarm(void) {
    publish_front_sos_alarm_msg(SOS_ALARM_LOCAL_MSG);
}

/** 与后端 mqtt.service handleSecurityEvent(card_issued) 对齐：data.card_uid 必填 */
static void publish_front_card_issued(const char *uid_hex, const char *room_id_str, const char *booking_id_opt,
                                      const char *card_type_opt) {
    if (!s_network_ready || uid_hex == NULL || uid_hex[0] == '\0') {
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", TERMINAL_DEVICE_TYPE_JSON);
    cJSON_AddStringToObject(root, "event_type", "card_issued");
    cJSON_AddStringToObject(root, "level", "info");

    cJSON *dat = cJSON_CreateObject();
    cJSON_AddStringToObject(dat, "card_uid", uid_hex);
    if (room_id_str != NULL && room_id_str[0] != '\0') {
        cJSON_AddStringToObject(dat, "room_id", room_id_str);
    }
    if (booking_id_opt != NULL && booking_id_opt[0] != '\0') {
        cJSON_AddStringToObject(dat, "booking_id", booking_id_opt);
    }
    if (card_type_opt != NULL && card_type_opt[0] != '\0') {
        cJSON_AddStringToObject(dat, "card_type", card_type_opt);
    }
    cJSON_AddStringToObject(dat, "action", "issue");
    cJSON_AddItemToObject(root, "data", dat);

    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(GLOBAL_TOPIC_SECURITY_EVENT, json_str);
    free(json_str);
    cJSON_Delete(root);
    ESP_LOGI(TAG, "已上报 card_issued: uid=%s room=%s booking=%s type=%s", uid_hex,
             room_id_str ? room_id_str : "", booking_id_opt ? booking_id_opt : "",
             card_type_opt ? card_type_opt : "");
}

/** 与入住退房 WebSocket `card_revoked` 对齐：清卡/注销扇区成功后上报 */
static void publish_front_card_revoked(const char *uid_hex_opt) {
    if (!s_network_ready) {
        return;
    }

    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", TERMINAL_DEVICE_TYPE_JSON);
    cJSON_AddStringToObject(root, "event_type", "card_revoked");
    cJSON_AddStringToObject(root, "level", "info");

    cJSON *dat = cJSON_CreateObject();
    if (uid_hex_opt != NULL && uid_hex_opt[0] != '\0') {
        cJSON_AddStringToObject(dat, "card_uid", uid_hex_opt);
    }
    cJSON_AddStringToObject(dat, "action", "revoke");
    cJSON_AddItemToObject(root, "data", dat);

    cJSON_AddStringToObject(root, "timestamp", timestamp);

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(GLOBAL_TOPIC_SECURITY_EVENT, json_str);
    free(json_str);
    cJSON_Delete(root);
    ESP_LOGI(TAG, "已上报 card_revoked: uid=%s", uid_hex_opt ? uid_hex_opt : "");
}

static void front_read_uid_hex_optional(char *hex, size_t hex_sz) {
    if (hex == NULL || hex_sz == 0) {
        return;
    }
    hex[0] = '\0';
    uint8_t uid[10] = {0};
    uint8_t uid_len = 0;
    if (driver_rc522_read_uid(uid, &uid_len) == ESP_OK && uid_len > 0) {
        uid_to_hex(uid, uid_len, hex, hex_sz);
    }
}

/**
 * MQTT 查卡/验卡：与 RC522 轮询里扇区解密 + /rfid-access/verify 链一致。
 * 演示(仅 UID)模式下与 publish_card_uid_event 一致：按 NVS 目标房号做后台校验。
 */
static bool front_desk_verify_card_for_command(const char **out_msg) {
    static char s_detail[112];
    if (out_msg == NULL) {
        return false;
    }
#if CONFIG_FRONT_DESK_DEMO_CARD_UID_ONLY
    uint8_t uid[10] = {0};
    uint8_t uid_len = 0;
    esp_err_t err = driver_rc522_read_uid(uid, &uid_len);
    if (err != ESP_OK || uid_len == 0) {
        *out_msg = "未检测到卡片";
        return false;
    }
    char uid_hex[32] = {0};
    uid_to_hex(uid, uid_len, uid_hex, sizeof(uid_hex));
    if (target_room_id[0] == '\0') {
        *out_msg = "未配置目标房号(Room_ID)，无法验卡";
        return false;
    }
    if (!s_network_ready) {
        *out_msg = "网络未就绪，无法后台验卡";
        return false;
    }
    if (service_auth_get_state() != AUTH_STATE_APPROVED) {
        *out_msg = "设备未鉴权，无法后台验卡";
        return false;
    }
    char dk[256];
    if (service_auth_get_device_key(dk, sizeof(dk)) != ESP_OK) {
        *out_msg = "无法读取 device_key";
        return false;
    }
    if (!front_http_rfid_verify(uid_hex, target_room_id)) {
        *out_msg = "后台校验未通过（无权进入目标房或未登记）";
        return false;
    }
    copy_str_safe(s_last_card_room_id, sizeof(s_last_card_room_id), target_room_id);
    snprintf(s_detail, sizeof(s_detail), "验卡通过(仅UID)，目标房 %s", target_room_id);
    *out_msg = s_detail;
    return true;
#else
    uint8_t sector_data[16] = {0};
    esp_err_t err = driver_rc522_read_sector(1, k_default_card_key, sector_data);
    if (err != ESP_OK) {
        *out_msg = "未检测到有效房卡";
        return false;
    }
    char room_id[16] = {0};
    if (!card_mifare_parse_sector_room(sector_data, s_card_aes_key, room_id, sizeof(room_id))) {
        *out_msg = "扇区无法解密或非本系统房卡";
        return false;
    }
    uint8_t uid[10] = {0};
    uint8_t uid_len = 0;
    if (driver_rc522_read_uid(uid, &uid_len) != ESP_OK || uid_len == 0) {
        *out_msg = "已读扇区但读 UID 失败";
        return false;
    }
    char uid_hex[32] = {0};
    uid_to_hex(uid, uid_len, uid_hex, sizeof(uid_hex));
    if (s_network_ready && service_auth_get_state() == AUTH_STATE_APPROVED) {
        char dk[256];
        if (service_auth_get_device_key(dk, sizeof(dk)) == ESP_OK) {
            if (!front_http_rfid_verify(uid_hex, room_id)) {
                *out_msg = "扇区可读但后台校验未通过（卡未登记或已失效）";
                return false;
            }
        }
    }
    copy_str_safe(s_last_card_room_id, sizeof(s_last_card_room_id), room_id);
    snprintf(s_detail, sizeof(s_detail), "验卡通过，房号 %s", room_id);
    *out_msg = s_detail;
    return true;
#endif
}

static bool handle_voice_control_command(const char *cmd_type, cJSON *root, const char **result_msg)
{
    if (cmd_type == NULL || result_msg == NULL) {
        return false;
    }

    cJSON *call_id_item = cJSON_GetObjectItem(root, "call_id");
    const char *call_id = (cJSON_IsString(call_id_item) && call_id_item->valuestring != NULL)
                              ? call_id_item->valuestring
                              : NULL;

    if (strcmp(cmd_type, "incoming_call") == 0) {
        s_call_incoming_pending = true;
        is_on_call = false;
        if (call_id != NULL) {
            copy_str_safe(current_call_id, sizeof(current_call_id), call_id);
        }
        *result_msg = "来电状态已设置";
        return true;
    }

    if (strcmp(cmd_type, "accept_call") == 0) {
        s_call_incoming_pending = false;
        is_on_call = true;
        if (call_id != NULL) {
            copy_str_safe(current_call_id, sizeof(current_call_id), call_id);
        }
        if (current_call_id[0] == '\0') {
            snprintf(current_call_id, sizeof(current_call_id), "call_%s_%lu", device_id, (unsigned long)(s_call_seq++));
        }
        *result_msg = "通话已接听";
        return true;
    }

    if (strcmp(cmd_type, "reject_call") == 0 || strcmp(cmd_type, "hangup_call") == 0) {
        s_call_incoming_pending = false;
        is_on_call = false;
        current_call_id[0] = '\0';
        *result_msg = (strcmp(cmd_type, "reject_call") == 0) ? "来电已拒接" : "通话已挂断";
        return true;
    }

    if (strcmp(cmd_type, "agent_reply") == 0) {
        *result_msg = "agent_reply 由音频下行通道处理";
        return true;
    }

    return false;
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

#define FRONT_RFID_VERIFY_RESP_MAX 768

typedef struct {
    char buf[FRONT_RFID_VERIFY_RESP_MAX];
    size_t len;
} front_rfid_verify_resp_t;

static void front_build_rfid_verify_url(char *out, size_t out_len) {
    if (out == NULL || out_len == 0) {
        return;
    }
    char http_api_base[128];
    load_nvs_string_with_fallback("HTTP_API_BASE", http_api_base, sizeof(http_api_base), "");
    char register_url[192];
    esp_err_t ue = service_auth_resolve_register_url(
        mqtt_broker_uri,
        (http_api_base[0] != '\0') ? http_api_base : NULL,
        register_url,
        sizeof(register_url));
    if (ue != ESP_OK) {
        snprintf(register_url, sizeof(register_url), "http://8.134.166.69:9000/api/v1/devices/register");
    }
    char *p = strstr(register_url, "/devices/register");
    if (p != NULL) {
        size_t prefix = (size_t)(p - register_url);
        const char *suffix = "/rfid-access/verify";
        if (prefix + strlen(suffix) + 1 > out_len) {
            snprintf(out, out_len, "http://8.134.166.69:9000/api/v1/rfid-access/verify");
            return;
        }
        memcpy(out, register_url, prefix);
        memcpy(out + prefix, suffix, strlen(suffix) + 1);
        return;
    }
    snprintf(out, out_len, "http://8.134.166.69:9000/api/v1/rfid-access/verify");
}

static esp_err_t front_rfid_verify_http_handler(esp_http_client_event_t *evt) {
    front_rfid_verify_resp_t *r = (front_rfid_verify_resp_t *)evt->user_data;
    if (evt->event_id != HTTP_EVENT_ON_DATA || r == NULL || evt->data == NULL || evt->data_len == 0) {
        return ESP_OK;
    }
    size_t n = (size_t)evt->data_len;
    if (r->len + n >= FRONT_RFID_VERIFY_RESP_MAX) {
        n = FRONT_RFID_VERIFY_RESP_MAX - 1 - r->len;
    }
    if (n > 0) {
        memcpy(r->buf + r->len, evt->data, n);
        r->len += n;
        r->buf[r->len] = '\0';
    }
    return ESP_OK;
}

/**
 * 调用后台 /rfid-access/verify：校验 card_uid 是否为当前酒店有效房卡且有权进入 room_number_str 对应房间。
 * 依赖设备 HTTP 头 x-device-id / x-device-key（与 deviceAuthMiddleware 一致）。
 */
static bool front_http_rfid_verify(const char *uid_hex, const char *room_number_str) {
    if (uid_hex == NULL || uid_hex[0] == '\0' || room_number_str == NULL || room_number_str[0] == '\0') {
        return false;
    }
    if (service_auth_get_state() != AUTH_STATE_APPROVED) {
        return false;
    }
    char device_key[256];
    if (service_auth_get_device_key(device_key, sizeof(device_key)) != ESP_OK) {
        return false;
    }
    char verify_url[192];
    front_build_rfid_verify_url(verify_url, sizeof(verify_url));

    cJSON *body = cJSON_CreateObject();
    if (body == NULL) {
        return false;
    }
    cJSON_AddStringToObject(body, "card_uid", uid_hex);
    cJSON_AddStringToObject(body, "room_number", room_number_str);
    char *post = cJSON_PrintUnformatted(body);
    cJSON_Delete(body);
    if (post == NULL) {
        return false;
    }

    front_rfid_verify_resp_t resp;
    memset(&resp, 0, sizeof(resp));

    esp_http_client_config_t cfg = {
        .url = verify_url,
        .event_handler = front_rfid_verify_http_handler,
        .timeout_ms = 8000,
    };
    esp_http_client_handle_t client = esp_http_client_init(&cfg);
    if (client == NULL) {
        free(post);
        return false;
    }
    esp_http_client_set_user_data(client, &resp);
    esp_http_client_set_method(client, HTTP_METHOD_POST);
    esp_http_client_set_header(client, "Content-Type", "application/json");
    esp_http_client_set_header(client, "x-device-id", device_id);
    esp_http_client_set_header(client, "x-device-key", device_key);
    esp_http_client_set_post_field(client, post, strlen(post));
    esp_err_t err = esp_http_client_perform(client);
    int code = esp_http_client_get_status_code(client);
    esp_http_client_cleanup(client);
    free(post);

    if (err != ESP_OK || code < 200 || code >= 300) {
        ESP_LOGW(TAG, "RFID verify HTTP err=%s code=%d body=%s", esp_err_to_name(err), code, resp.buf);
        return false;
    }

    cJSON *root = cJSON_Parse(resp.buf);
    if (root == NULL) {
        ESP_LOGW(TAG, "RFID verify JSON 解析失败: %s", resp.buf);
        return false;
    }
    cJSON *v = cJSON_GetObjectItem(root, "valid");
    bool ok = false;
    if (v != NULL) {
        if (cJSON_IsBool(v)) {
            ok = cJSON_IsTrue(v);
        } else if (cJSON_IsNumber(v)) {
            ok = (v->valuedouble != 0.0);
        }
    }
    cJSON_Delete(root);
    ESP_LOGI(TAG, "RFID verify: url=%s valid=%d", verify_url, (int)ok);
    return ok;
}

static bool front_is_local_room_device_for(const char *room_for_cmd) {
    if (room_for_cmd == NULL || room_for_cmd[0] == '\0') {
        return false;
    }
    char expected[40];
    snprintf(expected, sizeof(expected), "room_%s", room_for_cmd);
    return strcmp(device_id, expected) == 0;
}

static void front_card_access_granted(const char *room_for_cmd, const char *notice) {
    ESP_LOGI(TAG, "%s", notice);
#if CONFIG_TERMINAL_ROLE_ROOM
    card_voice_play_welcome(s_volume_pct);
#endif
    const bool local_door = front_is_local_room_device_for(room_for_cmd);
#if CONFIG_TERMINAL_ROLE_ROOM
    /* 本机即 room_301 时直接脉冲继电器，避免仅依赖 MQTT 自发自收导致无动作 */
    if (local_door) {
        (void)front_desk_run_door_pulse();
    }
#endif
    if (s_network_ready) {
        publish_front_event("card_verified", notice);
        if (!local_door) {
            publish_room_command(room_for_cmd, "door_unlock");
        }
    }
#if !CONFIG_TERMINAL_ROLE_ROOM
    hal_audio_beep_volume_pct(s_volume_pct);
#endif
}

static void front_card_access_denied(const char *reason_log) {
    ESP_LOGW(TAG, "%s", reason_log);
#if CONFIG_TERMINAL_ROLE_ROOM
    card_voice_play_invalid(s_volume_pct);
#else
    hal_audio_beep_volume_pct(s_volume_pct);
    hal_audio_beep_volume_pct(s_volume_pct);
#endif
}

/** 刷卡成功瞬间播提示音：先于 MQTT/签名，避免网络阻塞导致「读了卡却没声」。音量不低于下限，旋钮设得很小时仍能听见。 */
static void front_desk_beep_card_detected(void) {
    int v = (int)s_volume_pct;
    if (v < 45) {
        v = 55;
    }
    if (v > 100) {
        v = 100;
    }
    esp_err_t e = hal_audio_beep_volume_pct(v);
    if (e != ESP_OK) {
        static TickType_t s_last_beep_fail_log;
        TickType_t now = xTaskGetTickCount();
        if ((now - s_last_beep_fail_log) >= pdMS_TO_TICKS(30000)) {
            s_last_beep_fail_log = now;
            ESP_LOGW(TAG, "刷卡提示音失败: %s（确认 hal_audio 已初始化、I2S 功放接线）", esp_err_to_name(e));
        }
    }
}

static void publish_card_uid_event(const uint8_t *uid, uint8_t uid_len) {
    char uid_hex[32] = {0};
    uid_to_hex(uid, uid_len, uid_hex, sizeof(uid_hex));
    ESP_LOGI(TAG, "RC522 检测到卡片 UID=%s", uid_hex);

    if (!s_network_ready) {
#if CONFIG_TERMINAL_ROLE_ROOM
        ESP_LOGW(TAG, "网络未就绪：跳过刷卡 MQTT 上报 (UID=%s)；仅 UID 模式须联网由后台校验", uid_hex);
#else
        ESP_LOGW(TAG, "网络未就绪，跳过刷卡 MQTT 与验卡 (UID=%s)", uid_hex);
        return;
#endif
    }

    if (s_network_ready) {
        char timestamp[32];
        service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

        cJSON *root = cJSON_CreateObject();
        cJSON_AddStringToObject(root, "device_id", device_id);
        cJSON_AddStringToObject(root, "device_type", TERMINAL_DEVICE_TYPE_JSON);
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

#if CONFIG_FRONT_DESK_DEMO_CARD_UID_ONLY
    /* 仅 UID：必须联网并由后台 rfid_cards 校验通过后才开门（与 /rfid-access/verify 一致） */
    if (uid_len == 0 || target_room_id[0] == '\0') {
        front_card_access_denied("演示(仅UID): 无有效 UID 或未配置 Room_ID");
        return;
    }
    if (!s_network_ready) {
        front_card_access_denied("演示(仅UID): 网络未就绪，无法校验 UID");
        return;
    }
    if (!front_http_rfid_verify(uid_hex, target_room_id)) {
        front_card_access_denied("演示(仅UID): UID 未通过后台校验或无权进入本房");
        return;
    }
    {
        char notice[96];
        snprintf(notice, sizeof(notice), "房卡 UID 已校验，已下发 %s 开门指令", target_room_id);
        front_card_access_granted(target_room_id, notice);
    }
#else
    uint8_t sector_data[16] = {0};
    if (driver_rc522_read_sector(1, k_default_card_key, sector_data) == ESP_OK) {
        char room_id[16] = {0};
        if (card_mifare_parse_sector_room(sector_data, s_card_aes_key, room_id, sizeof(room_id))) {
            if (strcmp(room_id, target_room_id) == 0) {
                bool uid_ok = true;
                if (s_network_ready && service_auth_get_state() == AUTH_STATE_APPROVED) {
                    char dk[256];
                    if (service_auth_get_device_key(dk, sizeof(dk)) == ESP_OK) {
                        uid_ok = front_http_rfid_verify(uid_hex, room_id);
                    }
                    /* 已联网但暂无法读取 device_key 时保留扇区结果，避免注册异常导致永不开门 */
                }
                if (!uid_ok) {
                    front_card_access_denied("扇区房号匹配但 UID 未通过后台校验");
                } else {
                    char notice[96];
                    snprintf(notice, sizeof(notice), "刷卡验证通过，已下发 %s 开门指令", room_id);
                    front_card_access_granted(room_id, notice);
                }
            } else {
                ESP_LOGW(TAG, "房号不匹配 (卡=%s, 本机目标=%s)", room_id, target_room_id);
#if CONFIG_TERMINAL_ROLE_ROOM
                card_voice_play_invalid(s_volume_pct);
#else
                hal_audio_beep_volume_pct(s_volume_pct);
                hal_audio_beep_volume_pct(s_volume_pct);
#endif
            }
        } else {
            ESP_LOGW(TAG, "扇区内容无法解密或非本系统房卡");
#if CONFIG_TERMINAL_ROLE_ROOM
            card_voice_play_invalid(s_volume_pct);
#endif
        }
    } else {
#if CONFIG_TERMINAL_ROLE_ROOM
        card_voice_play_invalid(s_volume_pct);
#endif
    }
#endif /* !CONFIG_FRONT_DESK_DEMO_CARD_UID_ONLY */
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
    snprintf(topic, sizeof(topic), "hotel/health/%s/%s", TERMINAL_MQTT_TOPIC_SUFFIX, device_id);

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", TERMINAL_DEVICE_TYPE_JSON);
    cJSON_AddStringToObject(root, "firmware_version", FRONT_FIRMWARE_VERSION);
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

static void publish_room_command(const char *room_id, const char *command_type) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    char room_device_id[32];
    char timestamp[32];
    snprintf(room_device_id, sizeof(room_device_id), "room_%s", room_id);
    snprintf(topic, sizeof(topic), "%s/room/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, room_device_id);
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddNumberToObject(root, "command_id", (double)(++s_command_seq));
    cJSON_AddStringToObject(root, "device_id", room_device_id);
    cJSON_AddStringToObject(root, "command_type", command_type);
    cJSON_AddStringToObject(root, "created_by", device_id);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    // 语音控制命令在客房端要求携带会话参数，先在前台端预组包，联调时再与后端统一 call_id 生成规则。
    if (strcmp(command_type, "incoming_call") == 0) {
        char call_id[64];
        snprintf(call_id, sizeof(call_id), "call_%s_%lu", device_id, (unsigned long)(s_call_seq++));
        cJSON_AddStringToObject(root, "call_id", call_id);
        cJSON_AddStringToObject(root, "caller_id", device_id);
    } else if (strcmp(command_type, "hangup_call") == 0) {
        // 为保持命令结构一致，挂断命令也附带 call_id 占位，便于后续联调校准。
        char call_id[64];
        snprintf(call_id, sizeof(call_id), "call_%s_latest", device_id);
        cJSON_AddStringToObject(root, "call_id", call_id);
    }

    char signature[65];
    if (service_auth_sign_cjson_object(root, signature) == ESP_OK) {
        cJSON_AddStringToObject(root, "signature", signature);
    }

    char *json_str = cJSON_PrintUnformatted(root);
    service_mqtt_publish(topic, json_str);
    free(json_str);
    cJSON_Delete(root);
}

static void publish_front_command_result(int cmd_id, const char *cmd_type, bool ok, const char *result_msg) {
    if (!s_network_ready) {
        return;
    }
    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *reply = cJSON_CreateObject();
    cJSON_AddStringToObject(reply, "device_id", device_id);
    cJSON_AddNumberToObject(reply, "command_id", cmd_id);
    cJSON_AddStringToObject(reply, "command_type", cmd_type);
    cJSON_AddStringToObject(reply, "status", ok ? "success" : "failed");
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

/**
 * 从 command_value 读取字段：兼容字符串与数字（后端 booking_id、room_number 常为 JSON number）。
 * 与 iot-hotel-backend device.controller room-card、rfid.issuePrivilege 下发格式对齐。
 */
static bool cjson_copy_scalar_string(cJSON *parent, const char *key, char *out, size_t out_sz) {
    if (parent == NULL || key == NULL || out == NULL || out_sz == 0) {
        return false;
    }
    out[0] = '\0';
    cJSON *it = cJSON_GetObjectItem(parent, key);
    if (it == NULL) {
        return false;
    }
    if (cJSON_IsString(it) && it->valuestring != NULL) {
        copy_str_safe(out, out_sz, it->valuestring);
        return out[0] != '\0';
    }
    if (cJSON_IsNumber(it)) {
        snprintf(out, out_sz, "%.0f", it->valuedouble);
        return out[0] != '\0';
    }
    return false;
}

/** 与客房 publish_sensor_data 同 topic：hotel/device/data/{sensor_type}/{device_id} */
static void publish_front_sensor_data(const char *sensor_type, double value, const char *unit) {
    if (!s_network_ready || sensor_type == NULL || unit == NULL) {
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

/** 场景 → RGB：抄自客房 room_scene_to_rgb */
static void front_scene_to_rgb(front_scene_mode_t mode, uint8_t *r, uint8_t *g, uint8_t *b) {
    switch (mode) {
        case FRONT_SCENE_WELCOME: *r = 255; *g = 180; *b =  40; break;
        case FRONT_SCENE_READING: *r = 255; *g = 245; *b = 210; break;
        case FRONT_SCENE_NIGHT:   *r =   0; *g =  20; *b =  80; break;
        case FRONT_SCENE_SLEEP:   *r =   0; *g =   0; *b =   0; break;
        default:                  *r =   0; *g =   0; *b =   0; break;
    }
}

/** 场景仅改 RGB 氛围；空调继电器由 air_on/air_off 单独控制 */
static bool apply_front_scene(front_scene_mode_t mode, const char **out_result_msg) {
    if (out_result_msg == NULL) {
        return false;
    }
    uint8_t led_r = 0;
    uint8_t led_g = 0;
    uint8_t led_b = 0;

    switch (mode) {
        case FRONT_SCENE_WELCOME:
            *out_result_msg = "已切换到迎宾场景";
            break;
        case FRONT_SCENE_READING:
            *out_result_msg = "已切换到阅读场景";
            break;
        case FRONT_SCENE_NIGHT:
            *out_result_msg = "已切换到夜灯场景";
            break;
        case FRONT_SCENE_SLEEP:
            *out_result_msg = "已切换到睡眠场景";
            break;
        default:
            *out_result_msg = "未知场景";
            return false;
    }
    front_scene_to_rgb(mode, &led_r, &led_g, &led_b);

    esp_err_t err = hal_interactive_set_led_color(0, led_r, led_g, led_b);
    if (err != ESP_OK) {
        *out_result_msg = "场景切换失败: RGB 失败";
        return false;
    }

    s_scene_mode = mode;
    return true;
}

/** 灯光亮度：仅 PWM/RGB 表现，不碰空调继电器 CH1 */
static void front_apply_light_rgb_from_brightness(void) {
    ESP_LOGI(TAG, "灯光(RGB)：%d%%", s_brightness_pct);
    if (s_brightness_pct <= 0) {
        (void)hal_interactive_set_led_color(0, 0, 0, 0);
        return;
    }
    uint8_t b = (uint8_t)(s_brightness_pct * 255 / 100);
    (void)hal_interactive_set_led_color(0, b, (uint8_t)((uint16_t)b * 200 / 255), (uint8_t)(b / 2));
}

static const char *front_ec11_mode_label_cn(front_ec11_function_mode_t m) {
    switch (m) {
        case FRONT_EC11_MODE_VOLUME:
            return "音量";
        case FRONT_EC11_MODE_BRIGHTNESS:
            return "灯光亮度";
        case FRONT_EC11_MODE_AC_TEMP:
            return "空调温度";
        case FRONT_EC11_MODE_SCENE:
            return "灯光场景";
        default:
            return "?";
    }
}

/** 与客房 room_scene_label_short 一致（OLED 仅 5×7 ASCII） */
static const char *front_scene_label_short(front_scene_mode_t m) {
    switch (m) {
        case FRONT_SCENE_WELCOME:
            return "WEL";
        case FRONT_SCENE_READING:
            return "RDG";
        case FRONT_SCENE_NIGHT:
            return "NGT";
        case FRONT_SCENE_SLEEP:
            return "SLP";
        default:
            return "?";
    }
}

static void front_ec11_format_mode_line(char *buf, size_t buf_size) {
    if (buf == NULL || buf_size == 0) {
        return;
    }
    switch (s_ec11_function_mode) {
        case FRONT_EC11_MODE_VOLUME:
            snprintf(buf, buf_size, "M:VOL %d%%", s_volume_pct);
            break;
        case FRONT_EC11_MODE_BRIGHTNESS:
            snprintf(buf, buf_size, "M:BRT %d%%", s_brightness_pct);
            break;
        case FRONT_EC11_MODE_AC_TEMP:
            snprintf(buf, buf_size, "M:AC  %uC", (unsigned)s_ac_target_temp);
            break;
        case FRONT_EC11_MODE_SCENE:
            snprintf(buf, buf_size, "M:SCN %s", front_scene_label_short(s_scene_mode));
            break;
        default:
            snprintf(buf, buf_size, "M:?");
            break;
    }
}

static void front_oled_flash_status(const char *msg, uint32_t ttl_ms) {
    if (msg == NULL) {
        return;
    }
    snprintf(s_oled_status_line, sizeof(s_oled_status_line), "%s", msg);
    s_oled_status_until = xTaskGetTickCount() + pdMS_TO_TICKS(ttl_ms);
}

/**
 * 与客房 room_oled_render_all 相同结构：
 * Line0: 目标房号+网态+IP 尾段+场景；Line1: 温湿度+AC（或与楼控 NTC/烟感/人感轮换）；Line2: EC11 档；Line3: 继电器行或指令回显。
 * Line0 用 R<房号> 与客房皮肤一致（表示代客目标房）；Line3 仅 CH1 有效，A/C/D 固定 0。
 */
static void front_oled_render_all(void) {
    char l0[48], l1[48], l2[48], l3[48];

    snprintf(l0, sizeof(l0), "R%.6s %s %.7s %s",
             target_room_id,
             s_oled_net_ok ? "OK" : "--",
             s_oled_ip_tail,
             front_scene_label_short(s_scene_mode));

    const bool floor_extra_any = s_floor_got_ntc || s_floor_got_smoke || s_floor_got_human;
    const bool line1_alt =
        floor_extra_any && (((xTaskGetTickCount() / pdMS_TO_TICKS(2000)) & 1u) != 0);

    if (line1_alt) {
        char nbuf[6];
        char sbuf[6];
        if (s_floor_got_ntc) {
            snprintf(nbuf, sizeof(nbuf), "%.0f", (double)s_floor_ntc_c);
        } else {
            snprintf(nbuf, sizeof(nbuf), "--");
        }
        if (s_floor_got_smoke) {
            snprintf(sbuf, sizeof(sbuf), "%.0f", (double)s_floor_smoke_adc);
        } else {
            snprintf(sbuf, sizeof(sbuf), "--");
        }
        char humark = '?';
        if (s_floor_got_human) {
            humark = s_floor_human ? '1' : '0';
        }
        snprintf(l1, sizeof(l1), "N%s S%s H%c AC%uC", nbuf, sbuf, humark, (unsigned)s_ac_target_temp);
        s_oled_env_valid = false;
    } else if (s_floor_got_temp && s_floor_got_hum) {
        /* 温湿度：楼控 DHT MQTT；仅有其一则另一半显示为 -- */
        s_oled_env_valid = true;
        snprintf(l1, sizeof(l1), "T%.1fC H%.0f%% AC%uC",
                 s_oled_last_temp_c, s_oled_last_hum_pct, (unsigned)s_ac_target_temp);
    } else if (s_floor_got_temp) {
        s_oled_env_valid = false;
        snprintf(l1, sizeof(l1), "T%.1fC H-- AC%uC", s_oled_last_temp_c, (unsigned)s_ac_target_temp);
    } else if (s_floor_got_hum) {
        s_oled_env_valid = false;
        snprintf(l1, sizeof(l1), "T-- H%.0f%% AC%uC", s_oled_last_hum_pct, (unsigned)s_ac_target_temp);
    } else {
        s_oled_env_valid = false;
        snprintf(l1, sizeof(l1), "T --.- H-- AC%uC", (unsigned)s_ac_target_temp);
    }

    front_ec11_format_mode_line(l2, sizeof(l2));

    if (s_oled_status_line[0] != '\0' && xTaskGetTickCount() < s_oled_status_until) {
        snprintf(l3, sizeof(l3), "%s", s_oled_status_line);
    } else {
        if (s_oled_status_line[0] != '\0') {
            s_oled_status_line[0] = '\0';
        }
        snprintf(l3, sizeof(l3), "AC%d A0 C0 D0 Sc:%s",
                 s_front_relay_latched_on ? 1 : 0,
                 front_scene_label_short(s_scene_mode));
    }

    driver_oled_show_4_lines(l0, l1, l2, l3);
}

static void front_ec11_refresh_oled_mode_line(void) {
    front_oled_render_all();
}

void task_front_oled_refresh(void *pvParameters) {
    (void)pvParameters;
    ESP_LOGI(TAG, "OLED 刷新任务启动（1Hz，与客房相同布局）");
    while (1) {
        front_oled_render_all();
        vTaskDelay(FRONT_OLED_REFRESH_PERIOD);
    }
}

void task_front_ec11_peripheral(void *pvParameters) {
    (void)pvParameters;
    static bool s_sw_prev_stable = false;
    static TickType_t s_sw_down_tick = 0;
    static bool s_sw_held = false;
    static TickType_t s_last_ec11_init_try = 0;

    while (1) {
        if (!s_ec11_ready) {
            /* 上电时序或 GPIO 未就绪时首次 init 可能失败，周期性重试 */
            TickType_t nowt = xTaskGetTickCount();
            if ((nowt - s_last_ec11_init_try) >= pdMS_TO_TICKS(3000)) {
                s_last_ec11_init_try = nowt;
                if (GLOBAL_EC11_A_PIN >= 0 && GLOBAL_EC11_B_PIN >= 0) {
                    esp_err_t ec_err = driver_ec11_init(GLOBAL_EC11_A_PIN, GLOBAL_EC11_B_PIN, GLOBAL_EC11_SW_PIN);
                    if (ec_err == ESP_OK) {
                        s_ec11_ready = true;
                        ESP_LOGI(TAG, "EC11 初始化成功（任务内重试）");
                        front_ec11_refresh_oled_mode_line();
                    } else {
                        ESP_LOGW(TAG, "EC11 仍未就绪: %s（检查 A/B/SW 接线与 GPIO）", esp_err_to_name(ec_err));
                    }
                }
            }
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
                if (held >= pdMS_TO_TICKS(FRONT_EC11_SW_DEBOUNCE_MS) &&
                    held >= pdMS_TO_TICKS(FRONT_EC11_MODE_SWITCH_HOLD_MS)) {
                    s_ec11_function_mode =
                        (front_ec11_function_mode_t)((((int)s_ec11_function_mode) + 1) % 4);
                    char detail[48];
                    snprintf(detail, sizeof(detail), "当前:%s", front_ec11_mode_label_cn(s_ec11_function_mode));
                    publish_front_event("front_ec11_mode_switch", detail);
                    ESP_LOGI(TAG, "EC11 长按 SW：%s", front_ec11_mode_label_cn(s_ec11_function_mode));
                    front_ec11_refresh_oled_mode_line();
                }
                s_sw_held = false;
            }
            s_sw_prev_stable = sw_pressed;
        }

        /*
         * 旋转调节不再依赖「SW 未按下」：SW 浮空/常低/误触时原先会永远不调音量亮度。
         * 模式切换仍靠长按 SW 松手判定，与旋转互不冲突。
         */
        if (dir != DRIVER_EC11_DIR_NONE) {
            switch (s_ec11_function_mode) {
                case FRONT_EC11_MODE_VOLUME: {
                    const int prev_vol = s_volume_pct;
                    int step = (dir == DRIVER_EC11_DIR_CW) ? FRONT_EC11_VOLUME_STEP : -FRONT_EC11_VOLUME_STEP;
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
                    publish_front_sensor_data("volume", (double)s_volume_pct, "%");
                    ESP_LOGI(TAG, "前台音量：%d%%", s_volume_pct);
                    front_ec11_refresh_oled_mode_line();
                    break;
                }
                case FRONT_EC11_MODE_BRIGHTNESS: {
                    int step =
                        (dir == DRIVER_EC11_DIR_CW) ? FRONT_EC11_BRIGHTNESS_STEP : -FRONT_EC11_BRIGHTNESS_STEP;
                    s_brightness_pct += step;
                    if (s_brightness_pct < 0) {
                        s_brightness_pct = 0;
                    }
                    if (s_brightness_pct > 100) {
                        s_brightness_pct = 100;
                    }
                    front_apply_light_rgb_from_brightness();
                    driver_ec11_clear_rotation_accumulator();
                    publish_front_sensor_data("light_brightness", (double)s_brightness_pct, "%");
                    ESP_LOGI(TAG, "EC11 灯光亮度: %d%%", s_brightness_pct);
                    front_ec11_refresh_oled_mode_line();
                    break;
                }
                case FRONT_EC11_MODE_AC_TEMP: {
                    int delta =
                        (dir == DRIVER_EC11_DIR_CW) ? FRONT_EC11_AC_TEMP_STEP : -FRONT_EC11_AC_TEMP_STEP;
                    int t = (int)s_ac_target_temp + delta;
                    if (t < FRONT_EC11_AC_TEMP_MIN_C) {
                        t = FRONT_EC11_AC_TEMP_MIN_C;
                    }
                    if (t > FRONT_EC11_AC_TEMP_MAX_C) {
                        t = FRONT_EC11_AC_TEMP_MAX_C;
                    }
                    s_ac_target_temp = (uint8_t)t;
                    driver_ec11_clear_rotation_accumulator();
                    publish_front_sensor_data("ac_target_temp", (double)s_ac_target_temp, "C");
                    ESP_LOGI(TAG, "空调目标温度: %u℃（演示上报，无红外真机）", (unsigned)s_ac_target_temp);
                    front_ec11_refresh_oled_mode_line();
                    break;
                }
                case FRONT_EC11_MODE_SCENE: {
                    front_scene_mode_t next = s_scene_mode;
                    if (dir == DRIVER_EC11_DIR_CW) {
                        next = (front_scene_mode_t)((((int)s_scene_mode) + 1) % 4);
                    } else {
                        next = (front_scene_mode_t)((((int)s_scene_mode) + 3) % 4);
                    }
                    const char *scene_msg = "";
                    bool ok = apply_front_scene(next, &scene_msg);
                    driver_ec11_clear_rotation_accumulator();
                    ESP_LOGI(TAG, "EC11 场景: %s ok=%d", scene_msg, (int)ok);
                    publish_device_heartbeat();
                    front_ec11_refresh_oled_mode_line();
                    break;
                }
                default:
                    break;
            }
        }

        vTaskDelay(EC11_TASK_PERIOD);
    }
}

static esp_err_t front_desk_run_door_pulse(void) {
    esp_err_t err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
    if (err != ESP_OK) {
        return err;
    }
    (void)hal_interactive_set_led_color(0, 255, 180, 40);
    vTaskDelay(pdMS_TO_TICKS(1500));
    err = hal_actuators_set_state(ACTUATOR_RELAY_CH1, s_front_relay_latched_on);
    front_apply_light_rgb_from_brightness();
    return err;
}

/** 与客房 read_int_from_cmd_payload：解析 value / command_value（含字符串数字） */
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
    if (cJSON_IsString(v) && v->valuestring != NULL && v->valuestring[0] != '\0') {
        *out_value = (int)strtol(v->valuestring, NULL, 10);
        return true;
    }
    cJSON *command_value = cJSON_GetObjectItem(root, "command_value");
    if (cJSON_IsNumber(command_value)) {
        *out_value = (int)command_value->valuedouble;
        return true;
    }
    if (cJSON_IsString(command_value) && command_value->valuestring != NULL) {
        *out_value = (int)strtol(command_value->valuestring, NULL, 10);
        return true;
    }
    if (cJSON_IsObject(command_value)) {
        cJSON *inner = cJSON_GetObjectItem(command_value, "value");
        if (cJSON_IsNumber(inner)) {
            *out_value = (int)inner->valuedouble;
            return true;
        }
        if (cJSON_IsString(inner) && inner->valuestring != NULL) {
            *out_value = (int)strtol(inner->valuestring, NULL, 10);
            return true;
        }
    }
    return false;
}

/**
 * 绝对值：value / command_value；
 * 相对调节：管理后台 DeviceMonitor「亮度/音量/空调调大调小」使用 command_delta + command_direction(up|down)。
 */
static bool read_relative_or_absolute_int(cJSON *root, int *io_val, int min_v, int max_v)
{
    if (root == NULL || io_val == NULL) {
        return false;
    }
    if (read_int_from_cmd_payload(root, io_val)) {
        if (*io_val < min_v) {
            *io_val = min_v;
        }
        if (*io_val > max_v) {
            *io_val = max_v;
        }
        return true;
    }
    cJSON *dj = cJSON_GetObjectItem(root, "command_delta");
    int delta = 0;
    if (cJSON_IsNumber(dj)) {
        delta = (int)dj->valuedouble;
    } else if (cJSON_IsString(dj) && dj->valuestring != NULL) {
        delta = (int)strtol(dj->valuestring, NULL, 10);
    } else {
        return false;
    }
    if (delta == 0) {
        return false;
    }
    cJSON *dirj = cJSON_GetObjectItem(root, "command_direction");
    if (!cJSON_IsString(dirj) || dirj->valuestring == NULL) {
        return false;
    }
    int sign = 0;
    if (strcasecmp(dirj->valuestring, "up") == 0) {
        sign = 1;
    } else if (strcasecmp(dirj->valuestring, "down") == 0) {
        sign = -1;
    } else {
        return false;
    }
    int v = *io_val + sign * delta;
    if (v < min_v) {
        v = min_v;
    }
    if (v > max_v) {
        v = max_v;
    }
    *io_val = v;
    return true;
}

/**
 * 前台本地执行「代客房」单路继电器 + RGB 反馈（与 floor_controller 代客 CH1、后端 light/door 指令对齐）。
 * 返回 true 表示 cmd_type 已由本函数处理（无论成功与否）。
 */
static bool try_front_actuator_command(const char *cmd_type, cJSON *root, bool *ok, const char **out_msg) {
    if (cmd_type == NULL || ok == NULL || out_msg == NULL || root == NULL) {
        return false;
    }
    if (strcmp(cmd_type, "light_on") == 0) {
        if (s_brightness_pct <= 0) {
            s_brightness_pct = 80;
        }
        front_apply_light_rgb_from_brightness();
        publish_front_sensor_data("light_brightness", (double)s_brightness_pct, "%");
        front_ec11_refresh_oled_mode_line();
        *ok = true;
        *out_msg = "灯光已打开(RGB)";
        return true;
    }
    if (strcmp(cmd_type, "light_off") == 0) {
        s_brightness_pct = 0;
        front_apply_light_rgb_from_brightness();
        publish_front_sensor_data("light_brightness", (double)s_brightness_pct, "%");
        front_ec11_refresh_oled_mode_line();
        *ok = true;
        *out_msg = "灯光已关闭(RGB)";
        return true;
    }
    if (strcmp(cmd_type, "air_on") == 0) {
        s_front_relay_latched_on = true;
        esp_err_t e = hal_actuators_set_state(ACTUATOR_RELAY_CH1, true);
        *ok = (e == ESP_OK);
        *out_msg = *ok ? "空调(继电器)已开" : "继电器失败";
        return true;
    }
    if (strcmp(cmd_type, "air_off") == 0) {
        s_front_relay_latched_on = false;
        esp_err_t e = hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
        *ok = (e == ESP_OK);
        *out_msg = *ok ? "空调(继电器)已关" : "继电器失败";
        return true;
    }
    if (strcmp(cmd_type, "door_unlock") == 0) {
        esp_err_t e = front_desk_run_door_pulse();
        *ok = (e == ESP_OK);
        *out_msg = *ok ? "执行成功" : "门锁脉冲失败";
        return true;
    }
    if (strcmp(cmd_type, "door_lock") == 0) {
        s_front_relay_latched_on = false;
        esp_err_t e = hal_actuators_set_state(ACTUATOR_RELAY_CH1, false);
        *ok = (e == ESP_OK);
        *out_msg = *ok ? "执行成功" : "继电器失败";
        return true;
    }
    if (strcmp(cmd_type, "door") == 0) {
        cJSON *cv = cJSON_GetObjectItem(root, "command_value");
        const char *vs = NULL;
        if (cJSON_IsString(cv) && cv->valuestring != NULL) {
            vs = cv->valuestring;
        }
        if (vs != NULL && strcmp(vs, "unlock") == 0) {
            esp_err_t e = front_desk_run_door_pulse();
            *ok = (e == ESP_OK);
            *out_msg = *ok ? "执行成功" : "门锁脉冲失败";
            return true;
        }
        return false;
    }
    if (strcmp(cmd_type, "set_light_brightness") == 0 || strcmp(cmd_type, "light_brightness") == 0) {
        int b = s_brightness_pct;
        if (!read_relative_or_absolute_int(root, &b, 0, 100)) {
            *ok = false;
            *out_msg = "缺少亮度参数(value 或 command_delta+direction)";
            return true;
        }
        s_brightness_pct = b;
        front_apply_light_rgb_from_brightness();
        publish_front_sensor_data("light_brightness", (double)s_brightness_pct, "%");
        front_ec11_refresh_oled_mode_line();
        *ok = true;
        *out_msg = "灯光亮度已调整";
        return true;
    }
    if (strcmp(cmd_type, "set_ac_temp") == 0 || strcmp(cmd_type, "ac_set_temp") == 0 || strcmp(cmd_type, "ac_temp") == 0) {
        int t = (int)s_ac_target_temp;
        if (!read_relative_or_absolute_int(root, &t, FRONT_EC11_AC_TEMP_MIN_C, FRONT_EC11_AC_TEMP_MAX_C)) {
            *ok = false;
            *out_msg = "缺少空调温度参数(value 或 command_delta+direction)";
            return true;
        }
        s_ac_target_temp = (uint8_t)t;
        publish_front_sensor_data("ac_target_temp", (double)s_ac_target_temp, "C");
        *ok = true;
        *out_msg = "空调目标温度已调整";
        return true;
    }
    if (strcmp(cmd_type, "set_volume") == 0 || strcmp(cmd_type, "volume_set") == 0 || strcmp(cmd_type, "volume") == 0) {
        int vol = s_volume_pct;
        if (!read_relative_or_absolute_int(root, &vol, 0, 100)) {
            *ok = false;
            *out_msg = "缺少音量参数(value 或 command_delta+direction)";
            return true;
        }
        s_volume_pct = vol;
        hal_audio_set_playback_volume_pct(s_volume_pct);
        publish_front_sensor_data("volume", (double)s_volume_pct, "%");
        front_ec11_refresh_oled_mode_line();
        *ok = true;
        *out_msg = "音量已调整";
        return true;
    }
    const char *scene_msg = "";
    if (strcmp(cmd_type, "scene_welcome") == 0) {
        *ok = apply_front_scene(FRONT_SCENE_WELCOME, &scene_msg);
        *out_msg = scene_msg;
        return true;
    }
    if (strcmp(cmd_type, "scene_reading") == 0) {
        *ok = apply_front_scene(FRONT_SCENE_READING, &scene_msg);
        *out_msg = scene_msg;
        return true;
    }
    if (strcmp(cmd_type, "scene_night") == 0) {
        *ok = apply_front_scene(FRONT_SCENE_NIGHT, &scene_msg);
        *out_msg = scene_msg;
        return true;
    }
    if (strcmp(cmd_type, "scene_sleep") == 0) {
        *ok = apply_front_scene(FRONT_SCENE_SLEEP, &scene_msg);
        *out_msg = scene_msg;
        return true;
    }
    if (strcmp(cmd_type, "scene_next") == 0) {
        front_scene_mode_t next_mode = (front_scene_mode_t)((((int)s_scene_mode) + 1) % 4);
        *ok = apply_front_scene(next_mode, &scene_msg);
        *out_msg = scene_msg;
        return true;
    }
    if (strcmp(cmd_type, "light_scene_welcome") == 0 || strcmp(cmd_type, "scene_home") == 0) {
        *ok = apply_front_scene(FRONT_SCENE_WELCOME, &scene_msg);
        *out_msg = scene_msg;
        return true;
    }
    if (strcmp(cmd_type, "light_scene_reading") == 0) {
        *ok = apply_front_scene(FRONT_SCENE_READING, &scene_msg);
        *out_msg = scene_msg;
        return true;
    }
    if (strcmp(cmd_type, "light_scene_night") == 0) {
        *ok = apply_front_scene(FRONT_SCENE_NIGHT, &scene_msg);
        *out_msg = scene_msg;
        return true;
    }
    if (strcmp(cmd_type, "light_scene_sleep") == 0 || strcmp(cmd_type, "scene_leave") == 0) {
        *ok = apply_front_scene(FRONT_SCENE_SLEEP, &scene_msg);
        *out_msg = scene_msg;
        return true;
    }
    if (strcmp(cmd_type, "broadcast_alarm") == 0 || strcmp(cmd_type, "alarm_broadcast") == 0) {
        bool alarm_ok = true;
        for (int i = 0; i < 3; i++) {
            if (hal_audio_beep_volume_pct(s_volume_pct) != ESP_OK) {
                alarm_ok = false;
            }
        }
        *ok = alarm_ok;
        *out_msg = alarm_ok ? "广播警报音已播放" : "广播警报音播放失败";
        return true;
    }
    if (strcmp(cmd_type, "agent_session_start") == 0) {
#if FRONT_DESK_MINIMAL_HW
        *ok = false;
        *out_msg = "当前为最小硬件（无语音上行），不支持 Agent 会话";
        return true;
#else
        uint32_t win_ms = 120000;
        cJSON *w = cJSON_GetObjectItem(root, "window_ms");
        if (cJSON_IsNumber(w) && w->valuedouble > 0) {
            win_ms = (uint32_t)w->valuedouble;
        }
        voice_session_arm_agent_window(win_ms);
        *ok = true;
        *out_msg = "Agent 语音窗口已开启（按住 PTT 上行）";
        return true;
#endif
    }
    if (strcmp(cmd_type, "agent_session_end") == 0) {
#if FRONT_DESK_MINIMAL_HW
        *ok = false;
        *out_msg = "当前为最小硬件（无语音上行），不支持 Agent 会话";
        return true;
#else
        voice_session_close_agent_window();
        *ok = true;
        *out_msg = "Agent 语音窗口已关闭";
        return true;
#endif
    }
    if (strcmp(cmd_type, "alarm_trigger") == 0 || strcmp(cmd_type, "front_alarm") == 0) {
        publish_front_sos_alarm_msg("云端报警指令触发");
        for (int i = 0; i < 5; i++) {
            (void)hal_audio_beep_volume_pct(s_volume_pct);
        }
        *ok = true;
        *out_msg = "前台报警已触发";
        return true;
    }
    return false;
}

static bool handle_front_card_command(const char *cmd_type, cJSON *root, const char **out_msg) {
    s_front_mqtt_verify_ok_for_door = false;

    cJSON *owned_command_value = NULL;
    cJSON *command_value = parse_command_value_object(root, &owned_command_value);

    /* 网页/设备监控常用别名：清卡=擦除扇区 1 应用块（与 room_card_op action=sync_clear 一致），无需 command_value */
    if (strcmp(cmd_type, "clear_card") == 0) {
#if CONFIG_FRONT_DESK_DEMO_CARD_UID_ONLY
        *out_msg = "演示模式：已跳过擦除扇区（仅 UID 演示）";
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        return true;
#else
        uint8_t zeros[16] = {0};
        char uidhex[32] = {0};
        front_read_uid_hex_optional(uidhex, sizeof(uidhex));
        esp_err_t werr = driver_rc522_write_sector(1, k_default_card_key, zeros);
        if (werr != ESP_OK) {
            ESP_LOGW(TAG, "clear_card 写卡失败: %s", esp_err_to_name(werr));
            *out_msg = "清卡失败，请贴卡";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }
        publish_front_card_revoked(uidhex[0] != '\0' ? uidhex : NULL);
        *out_msg = "清卡完成";
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        return true;
#endif
    }

    /* Web/后端统一走 room_card_op（command_value 为 JSON 字符串或对象），与 emulator/front_desk 一致 */
    if (strcmp(cmd_type, "room_card_op") == 0) {
        if (command_value == NULL) {
            *out_msg = "room_card_op 缺少 command_value";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }

        cJSON *act_item = cJSON_GetObjectItem(command_value, "action");
        const char *action =
            (cJSON_IsString(act_item) && act_item->valuestring != NULL) ? act_item->valuestring : "issue";

        if (strcmp(action, "sync") == 0) {
#if CONFIG_FRONT_DESK_DEMO_CARD_UID_ONLY
            *out_msg = "演示模式已跳过扇区同步";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return true;
#else
            cJSON *ct_item = cJSON_GetObjectItem(command_value, "card_type");
            const char *ctype_str = "guest";
            if (cJSON_IsString(ct_item) && ct_item->valuestring != NULL && ct_item->valuestring[0] != '\0') {
                ctype_str = ct_item->valuestring;
            }
            char room_buf[16] = {0};
            const bool has_room = cjson_copy_scalar_string(command_value, "room_number", room_buf, sizeof(room_buf));

            uint8_t block[16] = {0};
            if (strcmp(ctype_str, "guest") == 0) {
                if (!has_room || room_buf[0] == '\0') {
                    *out_msg = "sync 缺少 room_number";
                    if (owned_command_value != NULL) {
                        cJSON_Delete(owned_command_value);
                    }
                    return false;
                }
                if (!card_mifare_encrypt_room_payload(room_buf, s_card_aes_key, block)) {
                    *out_msg = "sync 房号组包失败";
                    if (owned_command_value != NULL) {
                        cJSON_Delete(owned_command_value);
                    }
                    return false;
                }
            } else {
                if (!card_mifare_encrypt_tag_value_payload("TYPE", ctype_str, s_card_aes_key, block)) {
                    *out_msg = "sync 卡类型组包失败";
                    if (owned_command_value != NULL) {
                        cJSON_Delete(owned_command_value);
                    }
                    return false;
                }
            }
            esp_err_t werr = driver_rc522_write_sector(1, k_default_card_key, block);
            if (werr != ESP_OK) {
                ESP_LOGW(TAG, "room_card_op sync 写卡失败: %s", esp_err_to_name(werr));
                *out_msg = "同步写卡失败，请贴卡";
                if (owned_command_value != NULL) {
                    cJSON_Delete(owned_command_value);
                }
                return false;
            }
            *out_msg = "同步写卡完成";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return true;
#endif
        }
        if (strcmp(action, "sync_clear") == 0) {
#if CONFIG_FRONT_DESK_DEMO_CARD_UID_ONLY
            *out_msg = "演示模式已跳过清空扇区";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return true;
#else
            char uidhex_sc[32] = {0};
            front_read_uid_hex_optional(uidhex_sc, sizeof(uidhex_sc));
            uint8_t zeros[16] = {0};
            esp_err_t werr = driver_rc522_write_sector(1, k_default_card_key, zeros);
            if (werr != ESP_OK) {
                ESP_LOGW(TAG, "room_card_op sync_clear 写卡失败: %s", esp_err_to_name(werr));
                *out_msg = "清空扇区失败，请贴卡";
                if (owned_command_value != NULL) {
                    cJSON_Delete(owned_command_value);
                }
                return false;
            }
            publish_front_card_revoked(uidhex_sc[0] != '\0' ? uidhex_sc : NULL);
            *out_msg = "已清空卡扇区";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return true;
#endif
        }
        if (strcmp(action, "verify") == 0 || strcmp(action, "query") == 0 || strcmp(action, "read") == 0) {
            bool vok = front_desk_verify_card_for_command(out_msg);
            if (vok) {
                s_front_mqtt_verify_ok_for_door = true;
            }
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return vok;
        }
        if (strcmp(action, "revoke") == 0 || strcmp(action, "deactivate") == 0) {
#if CONFIG_FRONT_DESK_DEMO_CARD_UID_ONLY
            *out_msg = "演示模式已跳过注销擦卡";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return true;
#else
            char uidhex_rv[32] = {0};
            front_read_uid_hex_optional(uidhex_rv, sizeof(uidhex_rv));
            uint8_t zeros[16] = {0};
            esp_err_t werr = driver_rc522_write_sector(1, k_default_card_key, zeros);
            if (werr != ESP_OK) {
                ESP_LOGW(TAG, "room_card_op %s 擦卡失败: %s", action, esp_err_to_name(werr));
                *out_msg = "注销擦卡失败，请贴卡";
                if (owned_command_value != NULL) {
                    cJSON_Delete(owned_command_value);
                }
                return false;
            }
            publish_front_card_revoked(uidhex_rv[0] != '\0' ? uidhex_rv : NULL);
            *out_msg = "注销擦卡完成";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return true;
#endif
        }

        if (strcmp(action, "issue") != 0) {
            *out_msg = "未识别的 room_card_op.action";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }

        char room_storage[16] = {0};
        const char *room_for_card = target_room_id;
        if (cjson_copy_scalar_string(command_value, "room_number", room_storage, sizeof(room_storage))) {
            room_for_card = room_storage;
        } else {
            cJSON *rid_item = cJSON_GetObjectItem(command_value, "room_id");
            if (cJSON_IsString(rid_item) && rid_item->valuestring != NULL && rid_item->valuestring[0] != '\0') {
                copy_str_safe(room_storage, sizeof(room_storage), rid_item->valuestring);
                room_for_card = room_storage;
            } else if (cjson_copy_scalar_string(command_value, "room_id", room_storage, sizeof(room_storage))) {
                room_for_card = room_storage;
            }
        }

        cJSON *ct_item = cJSON_GetObjectItem(command_value, "card_type");
        const char *ctype_str = "guest";
        if (cJSON_IsString(ct_item) && ct_item->valuestring != NULL && ct_item->valuestring[0] != '\0') {
            ctype_str = ct_item->valuestring;
        }

        char booking_storage[32] = {0};
        (void)cjson_copy_scalar_string(command_value, "booking_id", booking_storage, sizeof(booking_storage));
        const char *booking_str = (booking_storage[0] != '\0') ? booking_storage : "";

        if (strcmp(ctype_str, "guest") == 0) {
            if (room_for_card == NULL || room_for_card[0] == '\0') {
                *out_msg = "guest 卡缺少 room_number";
                if (owned_command_value != NULL) {
                    cJSON_Delete(owned_command_value);
                }
                return false;
            }
        }

#if CONFIG_FRONT_DESK_DEMO_CARD_UID_ONLY
        {
            uint8_t uid[10] = {0};
            uint8_t uid_len = 0;
            esp_err_t uerr = driver_rc522_read_uid(uid, &uid_len);
            if (uerr != ESP_OK || uid_len == 0) {
                *out_msg = "请贴卡（演示模式读 UID）";
                if (owned_command_value != NULL) {
                    cJSON_Delete(owned_command_value);
                }
                return false;
            }
            char uid_hex[32] = {0};
            uid_to_hex(uid, uid_len, uid_hex, sizeof(uid_hex));
            if (strcmp(ctype_str, "guest") == 0) {
                publish_front_card_issued(uid_hex, room_for_card, booking_str, ctype_str);
                copy_str_safe(s_last_card_room_id, sizeof(s_last_card_room_id), room_for_card);
            } else {
                publish_front_card_issued(uid_hex, "", booking_str, ctype_str);
                s_last_card_room_id[0] = '\0';
            }
            *out_msg = "开卡成功(演示/仅UID)";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return true;
        }
#else
        uint8_t block[16] = {0};
        if (strcmp(ctype_str, "guest") == 0) {
            if (!card_mifare_encrypt_room_payload(room_for_card, s_card_aes_key, block)) {
                *out_msg = "房号无效或过长";
                if (owned_command_value != NULL) {
                    cJSON_Delete(owned_command_value);
                }
                return false;
            }
        } else {
            if (!card_mifare_encrypt_tag_value_payload("TYPE", ctype_str, s_card_aes_key, block)) {
                *out_msg = "卡类型无效或过长";
                if (owned_command_value != NULL) {
                    cJSON_Delete(owned_command_value);
                }
                return false;
            }
        }

        esp_err_t werr = driver_rc522_write_sector(1, k_default_card_key, block);
        if (werr != ESP_OK) {
            ESP_LOGW(TAG, "room_card_op issue 写卡失败: %s", esp_err_to_name(werr));
            *out_msg = "写卡失败，请确认卡片在感应区";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }

        uint8_t uid[10] = {0};
        uint8_t uid_len = 0;
        esp_err_t uerr = driver_rc522_read_uid(uid, &uid_len);
        if (uerr != ESP_OK || uid_len == 0) {
            *out_msg = "写卡成功但读 UID 失败";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }

        char uid_hex[32] = {0};
        uid_to_hex(uid, uid_len, uid_hex, sizeof(uid_hex));

        if (strcmp(ctype_str, "guest") == 0) {
            publish_front_card_issued(uid_hex, room_for_card, booking_str, ctype_str);
            copy_str_safe(s_last_card_room_id, sizeof(s_last_card_room_id), room_for_card);
        } else {
            publish_front_card_issued(uid_hex, "", booking_str, ctype_str);
            s_last_card_room_id[0] = '\0';
        }

        *out_msg = "开卡成功";
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        return true;
#endif
    }

    if (strcmp(cmd_type, "issue_card") == 0 || strcmp(cmd_type, "write_blank_card") == 0) {
        const char *room_id = target_room_id;
        char room_storage[16] = {0};
        char booking_storage[32] = {0};
        if (cJSON_IsObject(command_value)) {
            cJSON *room_item = cJSON_GetObjectItem(command_value, "room_id");
            if (cJSON_IsString(room_item) && room_item->valuestring != NULL) {
                copy_str_safe(room_storage, sizeof(room_storage), room_item->valuestring);
                room_id = room_storage;
            } else if (cjson_copy_scalar_string(command_value, "room_id", room_storage, sizeof(room_storage))) {
                room_id = room_storage;
            } else if (cjson_copy_scalar_string(command_value, "room_number", room_storage, sizeof(room_storage))) {
                room_id = room_storage;
            }
            (void)cjson_copy_scalar_string(command_value, "booking_id", booking_storage, sizeof(booking_storage));
        }
        const char *booking_for_issue = (booking_storage[0] != '\0') ? booking_storage : "";

#if CONFIG_FRONT_DESK_DEMO_CARD_UID_ONLY
        uint8_t uid[10] = {0};
        uint8_t uid_len = 0;
        if (driver_rc522_read_uid(uid, &uid_len) != ESP_OK || uid_len == 0) {
            *out_msg = "请贴卡（演示模式读 UID）";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }
        char uid_hex[32] = {0};
        uid_to_hex(uid, uid_len, uid_hex, sizeof(uid_hex));
        publish_front_card_issued(uid_hex, room_id, booking_for_issue, "guest");
        copy_str_safe(s_last_card_room_id, sizeof(s_last_card_room_id), room_id);
        *out_msg = (strcmp(cmd_type, "write_blank_card") == 0) ? "空白卡登记成功(演示/仅UID)" : "开卡成功(演示/仅UID)";
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        return true;
#else
        uint8_t block[16] = {0};
        if (!card_mifare_encrypt_room_payload(room_id, s_card_aes_key, block)) {
            *out_msg = "房号无效或过长，无法组包";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }

        esp_err_t err = driver_rc522_write_sector(1, k_default_card_key, block);
        if (err != ESP_OK) {
            *out_msg = (strcmp(cmd_type, "write_blank_card") == 0) ? "空白卡写入失败" : "开卡失败";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }
        uint8_t uid[10] = {0};
        uint8_t uid_len = 0;
        if (driver_rc522_read_uid(uid, &uid_len) == ESP_OK && uid_len > 0) {
            char uid_hex[32] = {0};
            uid_to_hex(uid, uid_len, uid_hex, sizeof(uid_hex));
            publish_front_card_issued(uid_hex, room_id, booking_for_issue, "guest");
            copy_str_safe(s_last_card_room_id, sizeof(s_last_card_room_id), room_id);
        }
        *out_msg = (strcmp(cmd_type, "write_blank_card") == 0) ? "空白卡写入成功" : "开卡成功";
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        return true;
#endif
    }

    if (strcmp(cmd_type, "verify_card") == 0 || strcmp(cmd_type, "swipe_card") == 0 ||
        strcmp(cmd_type, "read_card") == 0) {
        bool vok = front_desk_verify_card_for_command(out_msg);
        if (vok) {
            s_front_mqtt_verify_ok_for_door = true;
        }
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        return vok;
    }

    if (owned_command_value != NULL) {
        cJSON_Delete(owned_command_value);
    }
    return false;
}

static void front_desk_command_callback(const char *topic, const char *data, int data_len) {
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        return;
    }

    cJSON *cmd_id_item = cJSON_GetObjectItem(root, "command_id");
    cJSON *device_id_item = cJSON_GetObjectItem(root, "device_id");
    cJSON *cmd_type_item = cJSON_GetObjectItem(root, "command_type");
    cJSON *owned_command_value = NULL;
    (void)parse_command_value_object(root, &owned_command_value);

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
    /* command_id 可选：与楼控一致，缺省 0；若存在须为 number 或十进制串 */
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
    const char *t_tail = topic_tail(topic);
    char topic_suffix[32];
    snprintf(topic_suffix, sizeof(topic_suffix), "/%s/", TERMINAL_MQTT_TOPIC_SUFFIX);
    const bool topic_for_this = (topic != NULL && strstr(topic, topic_suffix) != NULL);

    bool is_for_us = false;
    if (has_device_id) {
        is_for_us = is_front_target_match(payload_device_id);
    } else {
        is_for_us = topic_for_this && is_front_target_match(t_tail);
    }

    ESP_LOGI(TAG, "指令解析: cmd_id=%d cmd_type=%s payload_device_id=%s topic_target=%s match=%d",
             cmd_id,
             cmd_type_str,
             has_device_id ? payload_device_id : "(missing)",
             t_tail,
             is_for_us ? 1 : 0);

    if (!is_for_us) {
        ESP_LOGW(TAG, "忽略非本机指令: payload_target=%s topic_target=%s self=%s",
                 has_device_id ? payload_device_id : "(missing)", t_tail, device_id);
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        cJSON_Delete(root);
        return;
    }

    const char *result_msg = "前台未识别指令";
    const char *cmd_type = cmd_type_str;

    // 拦截语音控制指令（最小状态机），音频内容仍由 voice_downlink_mqtt_cb 处理
    if (strcmp(cmd_type, "incoming_call") == 0 ||
        strcmp(cmd_type, "accept_call") == 0 ||
        strcmp(cmd_type, "reject_call") == 0 ||
        strcmp(cmd_type, "hangup_call") == 0 ||
        strcmp(cmd_type, "agent_reply") == 0) {

        bool ok = handle_voice_control_command(cmd_type, root, &result_msg);
        publish_front_command_result(cmd_id, cmd_type, ok, result_msg);
        front_oled_flash_status(cmd_type, 2000);
        front_oled_render_all();
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        cJSON_Delete(root);
        return;
    }

    bool ok = false;
    if (try_front_actuator_command(cmd_type, root, &ok, &result_msg)) {
        publish_front_command_result(cmd_id, cmd_type, ok, result_msg);
        if (ok) {
            hal_audio_beep_volume_pct(s_volume_pct);
        } else {
            hal_audio_beep_volume_pct(s_volume_pct);
            hal_audio_beep_volume_pct(s_volume_pct);
        }
        front_oled_flash_status(cmd_type, 2000);
        front_oled_render_all();
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        cJSON_Delete(root);
        return;
    }

    ok = handle_front_card_command(cmd_type, root, &result_msg);
    publish_front_command_result(cmd_id, cmd_type, ok, result_msg);

    if (ok && s_front_mqtt_verify_ok_for_door && s_last_card_room_id[0] != '\0') {
        publish_front_event("card_verified", "刷卡验证通过，已自动下发开门指令");
        publish_room_command(s_last_card_room_id, "door_unlock");
        ESP_LOGI(TAG, "刷卡通过，已触发房间开锁: room=%s", s_last_card_room_id);
    }
    s_front_mqtt_verify_ok_for_door = false;

    if (ok) {
        hal_audio_beep_volume_pct(s_volume_pct);
    } else {
        hal_audio_beep_volume_pct(s_volume_pct);
        hal_audio_beep_volume_pct(s_volume_pct);
    }
    front_oled_flash_status(cmd_type, 2000);
    front_oled_render_all();
    if (owned_command_value != NULL) {
        cJSON_Delete(owned_command_value);
    }
    cJSON_Delete(root);
}

static void front_command_result_callback(const char *topic, const char *data, int data_len) {
    (void)topic;
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        return;
    }

    cJSON *device_item = cJSON_GetObjectItem(root, "device_id");
    cJSON *cmd_item = cJSON_GetObjectItem(root, "command_type");
    cJSON *status_item = cJSON_GetObjectItem(root, "status");

    if (cJSON_IsString(device_item) && cJSON_IsString(cmd_item) && cJSON_IsString(status_item)) {
        ESP_LOGI(TAG, "回执: dev=%s cmd=%s status=%s",
                 device_item->valuestring, cmd_item->valuestring, status_item->valuestring);
    }
    cJSON_Delete(root);
}

/** 订阅楼控上报的 DHT 温湿度（与 floor_controller publish_sensor_data topic 一致） */
static void front_floor_env_mqtt_cb(const char *topic, const char *data, int data_len) {
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
    if (strcmp(stype->valuestring, "temperature") == 0) {
        s_oled_last_temp_c = (float)val->valuedouble;
        s_floor_got_temp = true;
    } else if (strcmp(stype->valuestring, "humidity") == 0) {
        s_oled_last_hum_pct = (float)val->valuedouble;
        s_floor_got_hum = true;
    } else if (strcmp(stype->valuestring, "ntc_temp") == 0) {
        s_floor_ntc_c = (float)val->valuedouble;
        s_floor_got_ntc = true;
    } else if (strcmp(stype->valuestring, "smoke") == 0) {
        s_floor_smoke_adc = (float)val->valuedouble;
        s_floor_got_smoke = true;
    } else if (strcmp(stype->valuestring, "human_present") == 0) {
        s_floor_human = (val->valuedouble >= 0.5);
        s_floor_got_human = true;
    }
    cJSON_Delete(root);
}

// --- 辅助组包函数 ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", TERMINAL_DEVICE_TYPE_JSON);
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddStringToObject(root, "firmware_version", FRONT_FIRMWARE_VERSION);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    publish_front_status_payload(root);
    cJSON_Delete(root);
}

// 发布设备心跳 (规范 6.1.2)
void publish_device_heartbeat() {
    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "status", "online");
    cJSON_AddNumberToObject(root, "battery_level", 100);
    cJSON_AddNumberToObject(root, "signal_strength", -50);
    cJSON_AddNumberToObject(root, "uptime", xTaskGetTickCount() * portTICK_PERIOD_MS / 1000);
    cJSON_AddNumberToObject(root, "memory_usage", 100 - (esp_get_free_heap_size() * 100 / 327680)); // 估算
    cJSON_AddBoolToObject(root, "demo_relay_latched_on", s_front_relay_latched_on ? 1 : 0);
    cJSON_AddStringToObject(root, "timestamp", timestamp);

    publish_front_status_payload(root);
    cJSON_Delete(root);
}

static void auth_and_mqtt_task(void *pvParameters) {
    ESP_LOGI(TAG, "开始设备注册/鉴权流程...");

    char http_api_base[128];
    load_nvs_string_with_fallback("HTTP_API_BASE", http_api_base, sizeof(http_api_base), "");
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

    /* hotel_id 须与后台该门店一致（当前为酒店 3） */
    service_auth_perform_registration_blocking(
        register_url,
        3,
        device_id,
        TERMINAL_REGISTRATION_TYPE,
        TERMINAL_REGISTRATION_NAME,
        FRONT_FIRMWARE_VERSION
    );

    ESP_LOGI(TAG, "鉴权通过，启动 MQTT 服务...");
    /* 等 SNTP 校时后再发带 timestamp 的 MQTT，避免后端 ±5 分钟窗口判「已过期」 */
    if (service_network_wait_sntp_sync(20000) != ESP_OK) {
        ESP_LOGW(TAG, "SNTP 未在 20s 内就绪，仍将启动 MQTT（请确认路由器未拦截 NTP）");
    }
    // 启动 MQTT
    service_mqtt_start(mqtt_broker_uri, device_id);
    service_mqtt_subscribe(GLOBAL_TOPIC_DEVICE_COMMAND_RESULT, front_command_result_callback);
    char sub_topic[128];
    snprintf(sub_topic, sizeof(sub_topic), "%s/%s/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, TERMINAL_MQTT_TOPIC_SUFFIX, device_id);
    service_mqtt_subscribe(sub_topic, front_desk_command_callback);
    
    // 延迟一小段以确保 MQTT 连接建立
    vTaskDelay(pdMS_TO_TICKS(1000));
    
    // 发布规范的上线状态
    publish_device_online_status();
    publish_health_report();
    
    // 声光提示：蓝灯常亮，短鸣2声表示上线成功
    hal_interactive_set_led_color(0, 0, 255, 255);
    hal_audio_beep_volume_pct(s_volume_pct);
    hal_audio_beep_volume_pct(s_volume_pct);

#if !FRONT_DESK_MINIMAL_HW
    // 订阅音频下行主题
    voice_session_subscribe_downlink();
#endif

    if (s_floor_sensor_device_id[0] != '\0') {
        char t_temp[160];
        char t_hum[160];
        snprintf(t_temp, sizeof(t_temp), "%s/%s/%s",
                 GLOBAL_TOPIC_DEVICE_DATA_PREFIX, "temperature", s_floor_sensor_device_id);
        snprintf(t_hum, sizeof(t_hum), "%s/%s/%s",
                 GLOBAL_TOPIC_DEVICE_DATA_PREFIX, "humidity", s_floor_sensor_device_id);
        esp_err_t e2 = service_mqtt_subscribe(t_temp, front_floor_env_mqtt_cb);
        if (e2 != ESP_OK) {
            ESP_LOGW(TAG, "订阅楼控温度失败: %s", esp_err_to_name(e2));
        }
        e2 = service_mqtt_subscribe(t_hum, front_floor_env_mqtt_cb);
        if (e2 != ESP_OK) {
            ESP_LOGW(TAG, "订阅楼控湿度失败: %s", esp_err_to_name(e2));
        }
        char t_ntc[160];
        char t_smoke[160];
        char t_human[160];
        snprintf(t_ntc, sizeof(t_ntc), "%s/%s/%s",
                 GLOBAL_TOPIC_DEVICE_DATA_PREFIX, "ntc_temp", s_floor_sensor_device_id);
        snprintf(t_smoke, sizeof(t_smoke), "%s/%s/%s",
                 GLOBAL_TOPIC_DEVICE_DATA_PREFIX, "smoke", s_floor_sensor_device_id);
        snprintf(t_human, sizeof(t_human), "%s/%s/%s",
                 GLOBAL_TOPIC_DEVICE_DATA_PREFIX, "human_present", s_floor_sensor_device_id);
        e2 = service_mqtt_subscribe(t_ntc, front_floor_env_mqtt_cb);
        if (e2 != ESP_OK) {
            ESP_LOGW(TAG, "订阅楼控 NTC 失败: %s", esp_err_to_name(e2));
        }
        e2 = service_mqtt_subscribe(t_smoke, front_floor_env_mqtt_cb);
        if (e2 != ESP_OK) {
            ESP_LOGW(TAG, "订阅楼控 smoke 失败: %s", esp_err_to_name(e2));
        }
        e2 = service_mqtt_subscribe(t_human, front_floor_env_mqtt_cb);
        if (e2 != ESP_OK) {
            ESP_LOGW(TAG, "订阅楼控 human_present 失败: %s", esp_err_to_name(e2));
        }
        ESP_LOGI(TAG, "OLED 楼控数据源: %s (DHT+ntc+smoke+human)", s_floor_sensor_device_id);
    }

    vTaskDelete(NULL);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        s_network_ready = true;
        const char *ip_str = (ip_address != NULL) ? ip_address : "--";
        const char *last_dot = strrchr(ip_str, '.');
        const char *tail = (last_dot != NULL && *(last_dot + 1) != '\0') ? last_dot + 1 : ip_str;
        snprintf(s_oled_ip_tail, sizeof(s_oled_ip_tail), "%s", tail);
        s_oled_net_ok = true;
        ESP_LOGI(TAG, "网络已连接，IP: %s", ip_str);

        if (s_peripherals_ready && !s_auth_task_started) {
            s_auth_task_started = true;
            xTaskCreate(auth_and_mqtt_task, "auth_and_mqtt", 8192, NULL, 4, NULL);
        } else if (!s_peripherals_ready) {
            ESP_LOGI(TAG, "网络已连接，等待外设初始化完成后再启动鉴权/MQTT");
        }
    } else {
        s_network_ready = false;
        s_oled_net_ok = false;
        snprintf(s_oled_ip_tail, sizeof(s_oled_ip_tail), "---");
        s_reconnect_count++;
        ESP_LOGW(TAG, "网络已断开，前台进入离线降级模式");
    }
}

// 心跳任务：只负责周期心跳上报
void task_front_heartbeat(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        vTaskDelay(FRONT_HEARTBEAT_TASK_PERIOD); // 每分钟发一次心跳
        if (!s_network_ready) {
            continue;
        }
        publish_device_heartbeat();
    }
}

void task_front_health_report(void *pvParameters) {
    (void)pvParameters;
    while (1) {
        vTaskDelay(FRONT_HEALTH_TASK_PERIOD);
        publish_health_report();
    }
}

// 按键任务：PTT 长按 → Agent；BTN_ROOM_SOS → sos_alarm（需 CMake 配置 GLOBAL_BTN_ROOM_1_PIN）
void task_front_button_events(void *pvParameters) {
    (void)pvParameters;

    while (1) {
        TickType_t now = xTaskGetTickCount();
        bool ptt_pressed = hal_interactive_is_button_pressed(BTN_ROOM_PTT);

#if !FRONT_DESK_MINIMAL_HW
        if (ptt_pressed && !s_ptt_prev) {
            s_ptt_press_tick = now;
            s_ptt_long_fired = false;
        }
        if (ptt_pressed && s_ptt_prev) {
            if (!s_ptt_long_fired && (now - s_ptt_press_tick >= pdMS_TO_TICKS(FRONT_PTT_LONG_PRESS_MS))) {
                s_ptt_long_fired = true;
                ESP_LOGI(TAG, "GPIO%d PTT 长按: 唤醒 Agent（语音助手）", GLOBAL_PTT_BTN_PIN);
                publish_front_event("agent_wake_requested", "长按 PTT 唤醒语音助手");
                voice_session_arm_agent_window(120000);
            }
        }
#endif
        s_ptt_prev = ptt_pressed;

        bool sos_pressed = hal_interactive_is_button_pressed(BTN_ROOM_SOS);
        if (sos_pressed && !s_sos_prev) {
            front_oled_flash_status("SOS!", 3500);
            publish_front_sos_alarm();
            (void)hal_audio_beep_volume_pct(s_volume_pct);
            (void)hal_audio_beep_volume_pct(s_volume_pct);
            (void)hal_audio_beep_volume_pct(s_volume_pct);
        }
        s_sos_prev = sos_pressed;

        vTaskDelay(FRONT_BUTTON_TASK_PERIOD);
    }
}

// RC522 轮询任务：持续读卡，检测到新卡后上报 UID
void task_front_rc522_poll(void *pvParameters) {
    (void)pvParameters;
    static TickType_t s_last_rc522_err_log = 0;

    ESP_LOGI(TAG, "RC522 轮询任务已启动 (约每 %lums 探测一次)",
             (unsigned long)(FRONT_RC522_TASK_PERIOD * portTICK_PERIOD_MS));

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
#if !CONFIG_TERMINAL_ROLE_ROOM
                front_desk_beep_card_detected();
#endif
                publish_card_uid_event(uid, uid_len);
            }
        } else if (err == ESP_ERR_NOT_FOUND) {
            s_last_uid_valid = false;
            s_last_uid_len = 0;
        } else {
            TickType_t now = xTaskGetTickCount();
            if ((now - s_last_rc522_err_log) >= pdMS_TO_TICKS(8000)) {
                s_last_rc522_err_log = now;
                ESP_LOGW(TAG, "RC522 read_uid 失败: %s（检查接线/是否 Mifare Classic 1K/天线距离）",
                         esp_err_to_name(err));
            }
        }

        vTaskDelay(FRONT_RC522_TASK_PERIOD);
    }
}

// 主入口
void app_main(void) {
    ESP_LOGI(TAG, "========== %s 启动 ==========", TERMINAL_BOOT_BANNER_TEXT);

    // 1. 初始化系统非易失性存储 (NVS)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    
    // 初始化认证组件 (读取 device_key)
    service_auth_init();
    
    // 2. 从 NVS 读取配置（NVS 优先，默认值兜底）
#if CONFIG_TERMINAL_ROLE_ROOM
    char room_num[16] = {0};
    load_nvs_string_with_fallback("Room_ID", room_num, sizeof(room_num), "301");
    snprintf(device_id, sizeof(device_id), "room_%s", room_num);
    copy_str_safe(target_room_id, sizeof(target_room_id), room_num);
#else
    char front_id[16] = {0};
    load_nvs_string_with_fallback("FrontDesk_ID", front_id, sizeof(front_id), FRONT_DESK_ID_DEFAULT);
    snprintf(device_id, sizeof(device_id), "front_desk_%s", front_id);
    load_nvs_string_with_fallback("Room_ID", target_room_id, sizeof(target_room_id), "301");
#endif
    load_nvs_string_with_fallback("Floor_Sensor_Device_Id", s_floor_sensor_device_id,
                                  sizeof(s_floor_sensor_device_id), "floor_03");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri), GLOBAL_MQTT_BROKER_URI);
    load_card_aes_key();

    // 3. 先启动网络与配网服务，让 Wi-Fi 先过电流峰值
    ESP_LOGI(TAG, "优先启动 Wi-Fi，延后初始化外设以降低瞬时负载");
    service_network_provisioning_start(on_network_status_changed);
    vTaskDelay(FRONT_WIFI_STABILIZE_DELAY);

    // 4. Wi-Fi 稳定后再初始化底层硬件驱动（OLED I2C 与客房相同 driver_oled）
    driver_oled_init();
    driver_oled_clear_screen();
    driver_oled_show_text_line(0, "Booting...");
#if !CONFIG_TERMINAL_ROLE_ROOM || CONFIG_TERMINAL_ROOM_ENABLE_RC522
    driver_rc522_init();
#else
    ESP_LOGW(TAG, "客房主控构建：已跳过 RC522（需刷卡时在 menuconfig 打开 TERMINAL_ROOM_ENABLE_RC522）");
#endif
    if (hal_actuators_init() != ESP_OK) {
        ESP_LOGW(TAG, "继电器初始化失败，请检查 GLOBAL_RELAY_CH1_PIN");
    }
    hal_interactive_init();
    hal_audio_init();
    hal_audio_set_playback_volume_pct(s_volume_pct);
    front_apply_light_rgb_from_brightness();

    if (GLOBAL_EC11_A_PIN >= 0 && GLOBAL_EC11_B_PIN >= 0) {
        esp_err_t ec_err = driver_ec11_init(GLOBAL_EC11_A_PIN, GLOBAL_EC11_B_PIN, GLOBAL_EC11_SW_PIN);
        if (ec_err == ESP_OK) {
            s_ec11_ready = true;
            ESP_LOGI(TAG, "EC11 初始化成功");
        } else {
            ESP_LOGW(TAG, "EC11 初始化失败: %s", esp_err_to_name(ec_err));
        }
    }

#if !FRONT_DESK_MINIMAL_HW
    voice_session_init(device_id, (bool*)&s_network_ready, (bool*)&is_on_call, (bool*)&s_call_incoming_pending, current_call_id,
                       sizeof(current_call_id));
#endif

    if (s_ec11_ready) {
        front_ec11_refresh_oled_mode_line();
    } else {
        front_oled_render_all();
    }

    s_peripherals_ready = true;
    if (s_network_ready && !s_auth_task_started) {
        s_auth_task_started = true;
        xTaskCreate(auth_and_mqtt_task, "auth_and_mqtt", 8192, NULL, 4, NULL);
    }

    // 5. 创建任务；main 仅保留守护
    xTaskCreate(task_front_heartbeat, "front_heartbeat_task", 4096, NULL, 5, NULL);
    xTaskCreate(task_front_health_report, "front_health_task", 4096, NULL, 5, NULL);
    xTaskCreate(task_front_button_events, "front_button_task", 3072, NULL, 4, NULL);
#if !CONFIG_TERMINAL_ROLE_ROOM || CONFIG_TERMINAL_ROOM_ENABLE_RC522
    xTaskCreate(task_front_rc522_poll, "front_rc522_task", 4096, NULL, 4, NULL);
#endif
#if !FRONT_DESK_MINIMAL_HW
    xTaskCreate(voice_uplink_task, "voice_task", 12288, NULL, 5, NULL);
    xTaskCreate(task_front_ec11_peripheral, "front_ec11_task", 4096, NULL, 4, NULL);
    xTaskCreate(task_front_oled_refresh, "front_oled_task", 3072, NULL, 3, NULL);
#endif
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(60000));
    }
}
