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

#include "hal_interactive.h"
#include "hal_audio.h"
#include "service_mqtt.h"
#include "service_network.h"
#include "driver_rc522.h"
#include "card_mifare_payload.h"
#include "global_config.h"
#include "service_auth.h"
#include "voice_session.h"

/*
 * 公网若按「设备号 / 固件版本 / 镜像版本」识别终端，换身份时请改下面两处，
 * 并在后台登记新的 device_id（格式 front_desk_<后缀>）。也可不写死：配网后在 NVS
 * 写入键 FrontDesk_ID 覆盖默认后缀（与 hotel 命名空间一致，由 service_network 读写）。
 */
#ifndef FRONT_DESK_ID_DEFAULT
#define FRONT_DESK_ID_DEFAULT "02"
#endif
#define FRONT_FIRMWARE_VERSION "v1.2.0"

static const char *TAG = "FRONT_DESK_MAIN";
static char device_id[32] = "front_desk_" FRONT_DESK_ID_DEFAULT;
static char mqtt_broker_uri[128] = GLOBAL_MQTT_BROKER_URI;
static const TickType_t FRONT_HEARTBEAT_TASK_PERIOD = pdMS_TO_TICKS(60000);
static const TickType_t FRONT_BUTTON_TASK_PERIOD = pdMS_TO_TICKS(50);
static const TickType_t FRONT_RC522_TASK_PERIOD = pdMS_TO_TICKS(200);
static const TickType_t FRONT_HEALTH_TASK_PERIOD = pdMS_TO_TICKS(600000);
static const TickType_t FRONT_WIFI_STABILIZE_DELAY = pdMS_TO_TICKS(3000);
static volatile bool s_network_ready = false;
static volatile bool s_peripherals_ready = false;
static volatile bool s_auth_task_started = false;
static uint32_t s_reconnect_count = 0;
static char target_room_id[16] = "301";
static uint32_t s_command_seq = 1000;
static uint32_t s_call_seq = 1;
static const uint8_t k_default_card_key[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
static uint8_t s_card_aes_key[16];
static char s_last_card_room_id[16] = "";
static uint8_t s_last_uid[10] = {0};
static uint8_t s_last_uid_len = 0;
static bool s_last_uid_valid = false;

static bool is_on_call = false;
static bool s_call_incoming_pending = false;
static char current_call_id[64] = "";
static uint8_t s_volume_pct = 60;

#include "driver_ec11.h"

// EC11 状态变量
static bool s_ec11_ready = false;
typedef enum {
    FRONT_EC11_MODE_VOLUME = 0,
    FRONT_EC11_MODE_BRIGHTNESS, // 预留，前台可能不需要
    FRONT_EC11_MODE_AC_TEMP,    // 预留
    FRONT_EC11_MODE_SCENE       // 预留
} front_ec11_function_mode_t;
static front_ec11_function_mode_t s_ec11_function_mode = FRONT_EC11_MODE_VOLUME;

#define FRONT_EC11_VOLUME_STEP 5
#define FRONT_EC11_SW_DEBOUNCE_MS 50
#define FRONT_EC11_MODE_SWITCH_HOLD_MS 800
#define EC11_TASK_PERIOD pdMS_TO_TICKS(20)

void task_front_ec11_peripheral(void *pvParameters) {
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
                if (held >= pdMS_TO_TICKS(FRONT_EC11_SW_DEBOUNCE_MS) &&
                    held >= pdMS_TO_TICKS(FRONT_EC11_MODE_SWITCH_HOLD_MS)) {
                    s_ec11_function_mode = (front_ec11_function_mode_t)((((int)s_ec11_function_mode) + 1) % 4);
                    ESP_LOGI(TAG, "EC11 长按 SW：切换模式 %d", (int)s_ec11_function_mode);
                }
                s_sw_held = false;
            }
            s_sw_prev_stable = sw_pressed;
        }

        /* 按住 SW 时不处理旋转，避免与长按切档语义冲突；仅松手后旋钮调节当前档 */
        if (dir != DRIVER_EC11_DIR_NONE && !sw_pressed) {
            switch (s_ec11_function_mode) {
                case FRONT_EC11_MODE_VOLUME: {
                    const int prev_vol = s_volume_pct;
                    int step = (dir == DRIVER_EC11_DIR_CW) ? FRONT_EC11_VOLUME_STEP : -FRONT_EC11_VOLUME_STEP;
                    int new_vol = s_volume_pct + step;
                    if (new_vol < 0) new_vol = 0;
                    if (new_vol > 100) new_vol = 100;
                    s_volume_pct = new_vol;
                    
                    if (s_volume_pct != prev_vol) {
                        hal_audio_set_playback_volume_pct(s_volume_pct);
                        if (hal_audio_beep_volume_pct(s_volume_pct) != ESP_OK) {
                            ESP_LOGD(TAG, "音量档位提示音未播放（音频未就绪或 I2S 忙）");
                        }
                        ESP_LOGI(TAG, "前台音量：%d%%", s_volume_pct);
                    }
                    driver_ec11_clear_rotation_accumulator();
                    break;
                }
                default:
                    // 其他模式前台暂不处理，或者可以用来控制前台灯光等
                    driver_ec11_clear_rotation_accumulator();
                    break;
            }
        }
        vTaskDelay(EC11_TASK_PERIOD);
    }
}

static void publish_room_command(const char *room_id, const char *command_type);
static bool handle_voice_control_command(const char *cmd_type, cJSON *root, const char **result_msg);

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

static void publish_front_status_payload(cJSON *root) {
    if (!s_network_ready) {
        return;
    }

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/front_desk/%s", GLOBAL_TOPIC_DEVICE_STATUS_PREFIX, device_id);

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
    cJSON_AddStringToObject(root, "device_type", "front_desk");
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

static void publish_card_uid_event(const uint8_t *uid, uint8_t uid_len) {
    if (!s_network_ready) {
        return;
    }

    char uid_hex[32] = {0};
    char timestamp[32];
    uid_to_hex(uid, uid_len, uid_hex, sizeof(uid_hex));
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "front_desk");
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
    ESP_LOGI(TAG, "RC522 检测到卡片 UID=%s", uid_hex);

    // 模拟客房端刷卡开门
    uint8_t sector_data[16] = {0};
    if (driver_rc522_read_sector(1, k_default_card_key, sector_data) == ESP_OK) {
        char room_id[16] = {0};
        if (card_mifare_parse_sector_room(sector_data, s_card_aes_key, room_id, sizeof(room_id))) {
            if (strcmp(room_id, target_room_id) == 0) {
                ESP_LOGI(TAG, "前台模拟刷卡: 验证通过，下发开门指令到 room_%s", room_id);
                publish_front_event("card_verified", "前台模拟刷卡验证通过，已下发开门指令");
                publish_room_command(room_id, "door_unlock");
                hal_audio_beep_volume_pct(s_volume_pct);
            } else {
                ESP_LOGW(TAG, "前台模拟刷卡: 房号不匹配 (卡=%s, 目标=%s)", room_id, target_room_id);
                hal_audio_beep_volume_pct(s_volume_pct);
                hal_audio_beep_volume_pct(s_volume_pct);
            }
        } else {
            ESP_LOGW(TAG, "前台模拟刷卡: 扇区内容无法解密");
        }
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
    snprintf(topic, sizeof(topic), "hotel/health/front_desk/%s", device_id);

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "front_desk");
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

static bool handle_front_card_command(const char *cmd_type, cJSON *root, const char **out_msg) {
    cJSON *owned_command_value = NULL;
    cJSON *command_value = parse_command_value_object(root, &owned_command_value);
    if (strcmp(cmd_type, "issue_card") == 0 || strcmp(cmd_type, "write_blank_card") == 0) {
        const char *room_id = target_room_id;
        if (cJSON_IsObject(command_value)) {
            cJSON *room_item = cJSON_GetObjectItem(command_value, "room_id");
            if (cJSON_IsString(room_item)) {
                room_id = room_item->valuestring;
            }
        }

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
        *out_msg = (strcmp(cmd_type, "write_blank_card") == 0) ? "空白卡写入成功" : "开卡成功";
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
            *out_msg = "未检测到有效房卡";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return false;
        }

        char room_id[16] = {0};
        if (card_mifare_parse_sector_room(sector_data, s_card_aes_key, room_id, sizeof(room_id))) {
            copy_str_safe(s_last_card_room_id, sizeof(s_last_card_room_id), room_id);
            *out_msg = "刷卡通过";
            if (owned_command_value != NULL) {
                cJSON_Delete(owned_command_value);
            }
            return true;
        }
        ESP_LOGW(TAG, "非法卡: 扇区内容无法解密或非本系统房卡");
        *out_msg = "扇区内容无法解密或非本系统房卡";
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        return false;
    }

    if (strcmp(cmd_type, "alarm_trigger") == 0 || strcmp(cmd_type, "front_alarm") == 0) {
        publish_front_event("front_alarm_triggered", "前台报警指令触发");
        (void)hal_audio_beep_volume_pct(s_volume_pct);
        (void)hal_audio_beep_volume_pct(s_volume_pct);
        (void)hal_audio_beep_volume_pct(s_volume_pct);
        (void)hal_audio_beep_volume_pct(s_volume_pct);
        (void)hal_audio_beep_volume_pct(s_volume_pct);
        if (owned_command_value != NULL) {
            cJSON_Delete(owned_command_value);
        }
        *out_msg = "前台报警已触发";
        return true;
    }

    if (owned_command_value != NULL) {
        cJSON_Delete(owned_command_value);
    }
    return false;
}

static void front_desk_command_callback(const char *topic, const char *data, int data_len) {
    (void)topic;
    cJSON *root = cJSON_ParseWithLength(data, data_len);
    if (root == NULL) {
        return;
    }

    cJSON *cmd_id_item = cJSON_GetObjectItem(root, "command_id");
    cJSON *device_id_item = cJSON_GetObjectItem(root, "device_id");
    cJSON *cmd_type_item = cJSON_GetObjectItem(root, "command_type");
    if (!cJSON_IsNumber(cmd_id_item) || !cJSON_IsString(device_id_item) || !cJSON_IsString(cmd_type_item)) {
        ESP_LOGW(TAG, "指令字段缺失: 需要 command_id/device_id/command_type");
        cJSON_Delete(root);
        return;
    }
    if (strcmp(device_id_item->valuestring, device_id) != 0) {
        ESP_LOGW(TAG, "忽略非本机指令: target=%s self=%s", device_id_item->valuestring, device_id);
        cJSON_Delete(root);
        return;
    }

    const char *result_msg = "前台未识别指令";
    const char *cmd_type = cmd_type_item->valuestring;
    
    // 拦截语音控制指令（最小状态机），音频内容仍由 voice_downlink_mqtt_cb 处理
    if (strcmp(cmd_type, "incoming_call") == 0 ||
        strcmp(cmd_type, "accept_call") == 0 ||
        strcmp(cmd_type, "reject_call") == 0 ||
        strcmp(cmd_type, "hangup_call") == 0 ||
        strcmp(cmd_type, "agent_reply") == 0) {

        bool ok = handle_voice_control_command(cmd_type, root, &result_msg);
        publish_front_command_result(cmd_id_item->valueint, cmd_type, ok, result_msg);
        cJSON_Delete(root);
        return;
    }

    bool ok = handle_front_card_command(cmd_type, root, &result_msg);
    publish_front_command_result(cmd_id_item->valueint, cmd_type_item->valuestring, ok, result_msg);

    if (ok && (strcmp(cmd_type, "verify_card") == 0 || strcmp(cmd_type, "swipe_card") == 0) && s_last_card_room_id[0] != '\0') {
        publish_front_event("card_verified", "刷卡验证通过，已自动下发开门指令");
        publish_room_command(s_last_card_room_id, "door_unlock");
        ESP_LOGI(TAG, "刷卡通过，已触发房间开锁: room=%s", s_last_card_room_id);
    }

    if (ok) {
        hal_audio_beep_volume_pct(s_volume_pct);
    } else {
        hal_audio_beep_volume_pct(s_volume_pct);
        hal_audio_beep_volume_pct(s_volume_pct);
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

// --- 辅助组包函数 ---

// 发布设备上线状态 (规范 6.1.1)
void publish_device_online_status() {
    char timestamp[32];
    service_network_get_iso8601_timestamp(timestamp, sizeof(timestamp));

    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "device_id", device_id);
    cJSON_AddStringToObject(root, "device_type", "front_desk");
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

    // 前台设备注册：hotel_id 须与后台该门店一致（当前为酒店 3）
    service_auth_perform_registration_blocking(
        register_url,
        3,
        device_id,
        "front_desk",
        "智能前台终端",
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
    snprintf(sub_topic, sizeof(sub_topic), "%s/front_desk/%s", GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX, device_id);
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

    // 订阅音频下行主题
    voice_session_subscribe_downlink();

    vTaskDelete(NULL);
}

// 网络连接状态回调
void on_network_status_changed(bool connected, const char* ip_address) {
    if (connected) {
        s_network_ready = true;
        ESP_LOGI(TAG, "网络已连接，IP: %s", ip_address);

        if (s_peripherals_ready && !s_auth_task_started) {
            s_auth_task_started = true;
            xTaskCreate(auth_and_mqtt_task, "auth_and_mqtt", 8192, NULL, 4, NULL);
        } else if (!s_peripherals_ready) {
            ESP_LOGI(TAG, "网络已连接，等待外设初始化完成后再启动鉴权/MQTT");
        }
    } else {
        s_network_ready = false;
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

// 按键事件任务：前台按钮触发事件与下行控制
void task_front_button_events(void *pvParameters) {
    (void)pvParameters;
    bool prev_clear_pressed = false;
    bool prev_broadcast_pressed = false;

    while (1) {
        // 暂时注释掉按钮检测，因为引脚可能重新分配给 EC11 和 Agent 按钮
        /*
        bool clear_pressed = hal_interactive_is_button_pressed(BTN_FRONT_CLEAR);
        bool broadcast_pressed = hal_interactive_is_button_pressed(BTN_FRONT_BROADCAST);

        if (clear_pressed && !prev_clear_pressed) {
            ESP_LOGI(TAG, "前台按键触发: 清除键");
            publish_front_event("front_clear_pressed", "前台消音/解除按钮触发");
            publish_room_command(target_room_id, "broadcast_alarm");
            hal_audio_beep_volume_pct(s_volume_pct);
        }

        if (broadcast_pressed && !prev_broadcast_pressed) {
            ESP_LOGI(TAG, "前台按键触发: 广播键");
            publish_front_event("front_broadcast_pressed", "前台广播按钮触发");
            publish_room_command(target_room_id, "broadcast_alarm");
            hal_audio_beep_volume_pct(s_volume_pct);
            hal_audio_beep_volume_pct(s_volume_pct);
        }

        prev_clear_pressed = clear_pressed;
        prev_broadcast_pressed = broadcast_pressed;
        */
        vTaskDelay(FRONT_BUTTON_TASK_PERIOD);
    }
}

// RC522 轮询任务：持续读卡，检测到新卡后上报 UID
void task_front_rc522_poll(void *pvParameters) {
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
                hal_audio_beep_volume_pct(s_volume_pct);
            }
        } else if (err == ESP_ERR_NOT_FOUND) {
            s_last_uid_valid = false;
            s_last_uid_len = 0;
        }

        vTaskDelay(FRONT_RC522_TASK_PERIOD);
    }
}

// 主入口
void app_main(void) {
    ESP_LOGI(TAG, "========== 🛎️ 智慧前台管理端 启动 ==========");

    // 1. 初始化系统非易失性存储 (NVS)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    
    // 初始化认证组件 (读取 device_key)
    service_auth_init();
    
    // 2. 从 NVS 读取配置（NVS 优先，默认值兜底）
    char front_id[16] = {0};
    load_nvs_string_with_fallback("FrontDesk_ID", front_id, sizeof(front_id), FRONT_DESK_ID_DEFAULT);
    snprintf(device_id, sizeof(device_id), "front_desk_%s", front_id);
    load_nvs_string_with_fallback("Room_ID", target_room_id, sizeof(target_room_id), "301");
    load_nvs_string_with_fallback("MQTT_BROKER_URI", mqtt_broker_uri, sizeof(mqtt_broker_uri), GLOBAL_MQTT_BROKER_URI);
    load_card_aes_key();

    // 3. 先启动网络与配网服务，让 Wi-Fi 先过电流峰值
    ESP_LOGI(TAG, "优先启动 Wi-Fi，延后初始化外设以降低瞬时负载");
    service_network_provisioning_start(on_network_status_changed);
    vTaskDelay(FRONT_WIFI_STABILIZE_DELAY);

    // 4. Wi-Fi 稳定后再初始化底层硬件驱动
    driver_rc522_init();
    hal_interactive_init();
    hal_audio_init();
    hal_audio_set_playback_volume_pct(s_volume_pct);
    
    if (GLOBAL_EC11_A_PIN >= 0 && GLOBAL_EC11_B_PIN >= 0) {
        esp_err_t ec_err = driver_ec11_init(GLOBAL_EC11_A_PIN, GLOBAL_EC11_B_PIN, GLOBAL_EC11_SW_PIN);
        if (ec_err == ESP_OK) {
            s_ec11_ready = true;
            ESP_LOGI(TAG, "EC11 初始化成功");
        } else {
            ESP_LOGW(TAG, "EC11 初始化失败: %s", esp_err_to_name(ec_err));
        }
    }

    voice_session_init(device_id, (bool*)&s_network_ready, (bool*)&is_on_call, (bool*)&s_call_incoming_pending, current_call_id,
                       sizeof(current_call_id));

    s_peripherals_ready = true;
    if (s_network_ready && !s_auth_task_started) {
        s_auth_task_started = true;
        xTaskCreate(auth_and_mqtt_task, "auth_and_mqtt", 8192, NULL, 4, NULL);
    }

    // 5. 创建任务；main 仅保留守护
    xTaskCreate(task_front_heartbeat, "front_heartbeat_task", 4096, NULL, 5, NULL);
    xTaskCreate(task_front_health_report, "front_health_task", 4096, NULL, 5, NULL);
    xTaskCreate(task_front_button_events, "front_button_task", 3072, NULL, 4, NULL);
    xTaskCreate(task_front_rc522_poll, "front_rc522_task", 4096, NULL, 4, NULL);
    xTaskCreate(voice_uplink_task, "voice_task", 12288, NULL, 5, NULL);
    xTaskCreate(task_front_ec11_peripheral, "front_ec11_task", 4096, NULL, 4, NULL);
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(60000));
    }
}
