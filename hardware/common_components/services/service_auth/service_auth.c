#include "service_auth.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "esp_log.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "esp_http_client.h"
#include "cJSON.h"
#include "psa/crypto.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "SERVICE_AUTH";
static service_auth_state_t g_auth_state = AUTH_STATE_UNREGISTERED;
static char g_device_key[65] = {0}; // 64 hex chars + 1 null

/*
 * NVS 持久化约定：
 *   namespace "storage"
 *     - "device_key" : 审核通过后下发的原始 device_key（hex 字符串）
 *     - "hotel_id"   : 审核通过时携带的 hotel_id（int32），用来检测
 *                      硬件代码里写死的 hotel_id 是否被人工改动，
 *                      若不一致会主动清掉 device_key 强制重新注册。
 *
 * 这样三端（room/floor/front_desk）的 main.c 只要把 perform_registration
 * 里传入的 hotel_id 改掉、重新烧录，设备启动时就会自动回到 pending 状态
 * 等待后台重新审核，从而完成"搬迁到另一家酒店"。
 */
static const char kNvsNamespace[]       = "storage";
static const char kNvsKeyDeviceKey[]    = "device_key";
static const char kNvsKeyHotelId[]      = "hotel_id";

/* 本轮 registration 要写入 NVS 的 hotel_id，由 perform_registration_blocking 设置 */
static int g_pending_hotel_id = 0;

/** 注册接口响应体缓冲（esp_http_client 的 ON_DATA 缓冲区通常不以 \\0 结尾，且可能分片） */
typedef struct {
    char *data;
    size_t len;
} service_auth_resp_buf_t;

#define SERVICE_AUTH_REGISTER_RESP_MAX 8192

static void service_auth_resp_buf_free(service_auth_resp_buf_t *buf) {
    if (buf == NULL) {
        return;
    }
    free(buf->data);
    buf->data = NULL;
    buf->len = 0;
}

static void service_auth_parse_register_json(const char *json_str) {
    if (json_str == NULL || json_str[0] == '\0') {
        return;
    }
    cJSON *json = cJSON_Parse(json_str);
    if (json == NULL) {
        ESP_LOGW(TAG, "register JSON parse failed");
        return;
    }
    cJSON *data = cJSON_GetObjectItem(json, "data");
    if (data != NULL) {
        cJSON *status = cJSON_GetObjectItem(data, "audit_status");
        if (status && cJSON_IsString(status) && status->valuestring) {
            if (strcmp(status->valuestring, "approved") == 0) {
                cJSON *key = cJSON_GetObjectItem(data, "device_key");
                if (key && cJSON_IsString(key) && key->valuestring && key->valuestring[0] != '\0') {
                    ESP_LOGI(TAG, "Audit Approved! Saving device_key...");
                    strncpy(g_device_key, key->valuestring, sizeof(g_device_key) - 1);
                    g_device_key[sizeof(g_device_key) - 1] = '\0';

                    nvs_handle_t my_handle;
                    if (nvs_open(kNvsNamespace, NVS_READWRITE, &my_handle) == ESP_OK) {
                        nvs_set_str(my_handle, kNvsKeyDeviceKey, g_device_key);
                        /* 把本次注册采用的 hotel_id 一并落盘，作为后续一致性校验依据 */
                        if (g_pending_hotel_id > 0) {
                            nvs_set_i32(my_handle, kNvsKeyHotelId, (int32_t)g_pending_hotel_id);
                        }
                        nvs_commit(my_handle);
                        nvs_close(my_handle);
                        ESP_LOGI(TAG, "Device key & hotel_id(%d) successfully saved to NVS",
                                 g_pending_hotel_id);
                    }
                    g_auth_state = AUTH_STATE_APPROVED;
                } else {
                    ESP_LOGW(TAG, "Audit approved but no device_key in JSON. Waiting...");
                }
            } else if (strcmp(status->valuestring, "pending") == 0) {
                ESP_LOGI(TAG, "Device is pending audit by Admin...");
                g_auth_state = AUTH_STATE_PENDING;
            } else if (strcmp(status->valuestring, "rejected") == 0) {
                ESP_LOGW(TAG, "Device audit rejected!");
                g_auth_state = AUTH_STATE_REJECTED;
            }
        }
    }
    cJSON_Delete(json);
}

esp_err_t service_auth_init(void) {
    ESP_LOGI(TAG, "Initializing Service Auth");
    
    // 初始化 NVS 确保存储可用
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);

    nvs_handle_t my_handle;
    err = nvs_open(kNvsNamespace, NVS_READONLY, &my_handle);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "NVS open failed or no device_key found (err: %s)", esp_err_to_name(err));
        g_auth_state = AUTH_STATE_UNREGISTERED;
        return ESP_OK; // It's fine if not found
    }

    size_t required_size = sizeof(g_device_key);
    err = nvs_get_str(my_handle, kNvsKeyDeviceKey, g_device_key, &required_size);
    if (err == ESP_OK && strlen(g_device_key) > 0) {
        int32_t stored_hotel_id = 0;
        esp_err_t hid_err = nvs_get_i32(my_handle, kNvsKeyHotelId, &stored_hotel_id);
        if (hid_err == ESP_OK) {
            ESP_LOGI(TAG, "Device key found in NVS! hotel_id=%d, key prefix: %.8s...",
                     (int)stored_hotel_id, g_device_key);
        } else {
            ESP_LOGW(TAG, "Device key found but hotel_id missing in NVS (legacy). Will verify on register.");
        }
        g_auth_state = AUTH_STATE_APPROVED;
    } else {
        ESP_LOGW(TAG, "No device_key found in NVS.");
        g_auth_state = AUTH_STATE_UNREGISTERED;
    }
    nvs_close(my_handle);

    return ESP_OK;
}

/**
 * 读取 NVS 中上次成功注册时保存的 hotel_id
 * @return ESP_OK 表示读到了（值写进 *out），其它返回表示不存在
 */
static esp_err_t service_auth_load_stored_hotel_id(int32_t *out) {
    if (out == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    nvs_handle_t h;
    esp_err_t err = nvs_open(kNvsNamespace, NVS_READONLY, &h);
    if (err != ESP_OK) {
        return err;
    }
    err = nvs_get_i32(h, kNvsKeyHotelId, out);
    nvs_close(h);
    return err;
}

/**
 * 清除本机保存的 device_key 与 hotel_id，用于"搬迁到另一个酒店"时强制走一次重注册。
 * 调用后下次 service_auth_perform_registration_blocking 会重新发 HTTP 注册请求。
 */
static void service_auth_clear_registration(void) {
    nvs_handle_t h;
    if (nvs_open(kNvsNamespace, NVS_READWRITE, &h) == ESP_OK) {
        nvs_erase_key(h, kNvsKeyDeviceKey);
        nvs_erase_key(h, kNvsKeyHotelId);
        nvs_commit(h);
        nvs_close(h);
    }
    memset(g_device_key, 0, sizeof(g_device_key));
    g_auth_state = AUTH_STATE_UNREGISTERED;
}

service_auth_state_t service_auth_get_state(void) {
    return g_auth_state;
}

static void trim_trailing_slash(char *s) {
    if (s == NULL) {
        return;
    }
    size_t n = strlen(s);
    while (n > 0 && (s[n - 1] == '/' || s[n - 1] == ' ')) {
        s[n - 1] = '\0';
        n--;
    }
}

esp_err_t service_auth_resolve_register_url(
    const char *mqtt_broker_uri,
    const char *http_api_base_opt,
    char *out,
    size_t out_len) {
    if (out == NULL || out_len < 64) {
        return ESP_ERR_INVALID_ARG;
    }
    if (http_api_base_opt != NULL && http_api_base_opt[0] != '\0') {
        char base[160];
        strncpy(base, http_api_base_opt, sizeof(base) - 1);
        base[sizeof(base) - 1] = '\0';
        trim_trailing_slash(base);
        if (base[0] == '\0') {
            return service_auth_resolve_register_url(mqtt_broker_uri, NULL, out, out_len);
        }
        int w = snprintf(out, out_len, "%s/api/v1/devices/register", base);
        if (w < 0 || (size_t)w >= out_len) {
            return ESP_ERR_NO_MEM;
        }
        return ESP_OK;
    }

    const char *def_host = "8.134.166.69";
    char host[128];
    if (mqtt_broker_uri == NULL || mqtt_broker_uri[0] == '\0') {
        snprintf(host, sizeof(host), "%s", def_host);
    } else {
        const char *p = mqtt_broker_uri;
        if (strncmp(p, "mqtt://", 7) == 0) {
            p += 7;
        } else if (strncmp(p, "mqtts://", 8) == 0) {
            p += 8;
        } else {
            snprintf(host, sizeof(host), "%s", def_host);
            int w = snprintf(out, out_len, "http://%s:9000/api/v1/devices/register", host);
            if (w < 0 || (size_t)w >= out_len) {
                return ESP_ERR_NO_MEM;
            }
            return ESP_OK;
        }
        const char *at = strchr(p, '@');
        if (at != NULL) {
            p = at + 1;
        }
        size_t i = 0;
        while (*p != '\0' && *p != ':' && *p != '/' && i < sizeof(host) - 1) {
            host[i++] = *p++;
        }
        host[i] = '\0';
        if (i == 0) {
            snprintf(host, sizeof(host), "%s", def_host);
        }
    }
    int w = snprintf(out, out_len, "http://%s:9000/api/v1/devices/register", host);
    if (w < 0 || (size_t)w >= out_len) {
        return ESP_ERR_NO_MEM;
    }
    return ESP_OK;
}

esp_err_t service_auth_get_device_key(char* out_key, size_t max_len) {
    if (g_auth_state != AUTH_STATE_APPROVED) {
        return ESP_ERR_INVALID_STATE;
    }
    if (out_key == NULL || max_len <= strlen(g_device_key)) {
        return ESP_ERR_INVALID_ARG;
    }
    strcpy(out_key, g_device_key);
    return ESP_OK;
}

static service_auth_resp_buf_t *service_auth_get_resp_buf(esp_http_client_handle_t client) {
    void *p = NULL;
    if (client == NULL) {
        return NULL;
    }
    if (esp_http_client_get_user_data(client, &p) != ESP_OK || p == NULL) {
        return NULL;
    }
    return (service_auth_resp_buf_t *)p;
}

static esp_err_t _http_event_handler(esp_http_client_event_t *evt) {
    service_auth_resp_buf_t *resp = service_auth_get_resp_buf(evt->client);

    switch (evt->event_id) {
        case HTTP_EVENT_ON_DATA:
            if (evt->data == NULL || evt->data_len == 0 || resp == NULL) {
                break;
            }
            ESP_LOGI(TAG, "HTTP chunk: %u bytes", (unsigned)evt->data_len);
            if (resp->len + evt->data_len >= SERVICE_AUTH_REGISTER_RESP_MAX) {
                ESP_LOGW(TAG, "register response exceeds %d bytes, drop", SERVICE_AUTH_REGISTER_RESP_MAX);
                break;
            }
            {
                char *n = (char *)realloc(resp->data, resp->len + evt->data_len + 1);
                if (n == NULL) {
                    ESP_LOGE(TAG, "realloc response buffer failed");
                    break;
                }
                memcpy(n + resp->len, evt->data, evt->data_len);
                resp->len += evt->data_len;
                n[resp->len] = '\0';
                resp->data = n;
            }
            break;
        case HTTP_EVENT_ON_FINISH:
            if (resp != NULL && resp->data != NULL && resp->len > 0) {
                ESP_LOGI(TAG, "HTTP body complete, %u bytes", (unsigned)resp->len);
                service_auth_parse_register_json(resp->data);
            }
            break;
        case HTTP_EVENT_ERROR:
            if (resp != NULL) {
                service_auth_resp_buf_free(resp);
            }
            break;
        default:
            break;
    }
    return ESP_OK;
}

esp_err_t service_auth_perform_registration_blocking(
    const char* api_url,
    int hotel_id,
    const char* device_id,
    const char* device_type,
    const char* device_name,
    const char* firmware_version
) {
    /* 记下本次要注册的 hotel_id，稍后审核通过时随 device_key 一起写入 NVS */
    g_pending_hotel_id = hotel_id;

    if (g_auth_state == AUTH_STATE_APPROVED) {
        int32_t stored_hotel_id = 0;
        esp_err_t hid_err = service_auth_load_stored_hotel_id(&stored_hotel_id);
        if (hid_err == ESP_OK && (int)stored_hotel_id == hotel_id) {
            ESP_LOGI(TAG, "Device already approved for hotel_id=%d, skipping registration.", hotel_id);
            return ESP_OK;
        }
        if (hid_err == ESP_OK) {
            ESP_LOGW(TAG,
                     "Configured hotel_id=%d differs from stored hotel_id=%d. Clearing NVS and re-registering...",
                     hotel_id, (int)stored_hotel_id);
        } else {
            ESP_LOGW(TAG,
                     "Legacy device_key in NVS without hotel_id. Clearing and re-registering against hotel_id=%d...",
                     hotel_id);
        }
        service_auth_clear_registration();
    }

    char post_data[512];
    snprintf(post_data, sizeof(post_data), 
        "{\"hotel_id\":%d, \"device_id\":\"%s\", \"device_type\":\"%s\", \"device_name\":\"%s\", \"firmware_version\":\"%s\"}", 
        hotel_id, device_id, device_type, device_name, firmware_version);

    while (g_auth_state != AUTH_STATE_APPROVED) {
        ESP_LOGI(TAG, "Sending HTTP POST registration request to %s", api_url);

        service_auth_resp_buf_t resp_buf = {NULL, 0};

        esp_http_client_config_t config = {
            .url = api_url,
            .event_handler = _http_event_handler,
            .timeout_ms = 5000,
        };
        esp_http_client_handle_t client = esp_http_client_init(&config);
        
        if (client == NULL) {
            ESP_LOGE(TAG, "Failed to initialize HTTP client");
            service_auth_resp_buf_free(&resp_buf);
            vTaskDelay(pdMS_TO_TICKS(10000));
            continue;
        }

        esp_http_client_set_user_data(client, &resp_buf);

        esp_http_client_set_method(client, HTTP_METHOD_POST);
        esp_http_client_set_header(client, "Content-Type", "application/json");
        esp_http_client_set_post_field(client, post_data, strlen(post_data));

        esp_err_t err = esp_http_client_perform(client);
        int status_code = 0;
        if (err == ESP_OK) {
            status_code = esp_http_client_get_status_code(client);
            ESP_LOGI(TAG, "HTTP POST Status = %d", status_code);
            if (status_code == 429 && resp_buf.data != NULL) {
                ESP_LOGW(TAG, "服务端限流(429)，响应片段: %.*s",
                         (int)(resp_buf.len < 160 ? resp_buf.len : 160), resp_buf.data);
            }
        } else {
            ESP_LOGE(TAG, "HTTP POST request failed: %s", esp_err_to_name(err));
        }

        esp_http_client_cleanup(client);
        service_auth_resp_buf_free(&resp_buf);

        if (g_auth_state == AUTH_STATE_APPROVED) {
            ESP_LOGI(TAG, "Successfully registered and approved! Exiting loop.");
            break;
        }

        /* 429/503 时拉长间隔，避免打爆服务端限流 */
        uint32_t wait_ms = 15000;
        if (status_code == 429 || status_code == 503) {
            wait_ms = 120000;
            ESP_LOGW(TAG, "因 HTTP %d 退避等待 %u 秒后再轮询", status_code, (unsigned)(wait_ms / 1000));
        }
        ESP_LOGI(TAG, "Waiting %u ms before next polling...", (unsigned)wait_ms);
        vTaskDelay(pdMS_TO_TICKS(wait_ms));
    }

    return ESP_OK;
}

// 辅助函数：将字节转为十六进制字符串
static void bytes_to_hex(const unsigned char *src, size_t src_len, char *dst) {
    for (size_t i = 0; i < src_len; i++) {
        sprintf(dst + (i * 2), "%02x", src[i]);
    }
    dst[src_len * 2] = '\0';
}

esp_err_t service_auth_sign_payload(const char* payload, char* out_signature) {
    if (g_auth_state != AUTH_STATE_APPROVED || strlen(g_device_key) == 0) {
        ESP_LOGE(TAG, "Cannot sign payload: device_key is missing or not approved");
        return ESP_ERR_INVALID_STATE;
    }
    if (payload == NULL || out_signature == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    // HMAC-SHA256：Mbed TLS 4 起 MD 层不再支持 HMAC，改用 PSA MAC API
    const size_t key_len = strlen(g_device_key);
    const psa_algorithm_t alg = PSA_ALG_HMAC(PSA_ALG_SHA_256);
    psa_key_attributes_t attr = PSA_KEY_ATTRIBUTES_INIT;
    psa_set_key_usage_flags(&attr, PSA_KEY_USAGE_SIGN_MESSAGE);
    psa_set_key_algorithm(&attr, alg);
    psa_set_key_type(&attr, PSA_KEY_TYPE_HMAC);
    psa_set_key_bits(&attr, (psa_key_bits_t)(key_len * 8));
    psa_set_key_lifetime(&attr, PSA_KEY_LIFETIME_VOLATILE);

    mbedtls_svc_key_id_t key_id;
    psa_status_t pstat = psa_import_key(
        &attr, (const uint8_t *)g_device_key, key_len, &key_id);
    psa_reset_key_attributes(&attr);
    if (pstat != PSA_SUCCESS) {
        ESP_LOGE(TAG, "psa_import_key failed: %d", (int)pstat);
        return ESP_FAIL;
    }

    unsigned char mac[32];
    size_t mac_len = 0;
    pstat = psa_mac_compute(
        key_id, alg, (const uint8_t *)payload, strlen(payload), mac, sizeof(mac), &mac_len);
    psa_destroy_key(key_id);
    if (pstat != PSA_SUCCESS) {
        ESP_LOGE(TAG, "psa_mac_compute failed: %d", (int)pstat);
        return ESP_FAIL;
    }

    // Convert MAC to hex string
    bytes_to_hex(mac, sizeof(mac), out_signature);
    
    ESP_LOGD(TAG, "Generated HMAC signature: %s", out_signature);
    return ESP_OK;
}

/* ---------- MQTT 签名：与后端 Node.js sortObject + JSON.stringify 一致 ---------- */

static int cmp_cjson_child_key(const void *a, const void *b)
{
    const cJSON *ca = *(const cJSON *const *)a;
    const cJSON *cb = *(const cJSON *const *)b;
    const char *sa = (ca != NULL && ca->string != NULL) ? ca->string : "";
    const char *sb = (cb != NULL && cb->string != NULL) ? cb->string : "";
    return strcmp(sa, sb);
}

static cJSON *dup_sorted_recursive(const cJSON *src)
{
    if (src == NULL) {
        return NULL;
    }
    if (cJSON_IsNumber(src) || cJSON_IsString(src) || cJSON_IsBool(src) || cJSON_IsNull(src)) {
        return cJSON_Duplicate((cJSON *)src, 1);
    }
    if (cJSON_IsArray(src)) {
        cJSON *arr = cJSON_CreateArray();
        if (arr == NULL) {
            return NULL;
        }
        const cJSON *it = NULL;
        cJSON_ArrayForEach(it, (cJSON *)src)
        {
            cJSON *ni = dup_sorted_recursive(it);
            if (ni == NULL) {
                cJSON_Delete(arr);
                return NULL;
            }
            cJSON_AddItemToArray(arr, ni);
        }
        return arr;
    }
    if (cJSON_IsObject(src)) {
        int n = 0;
        for (cJSON *c = ((cJSON *)src)->child; c != NULL; c = c->next) {
            n++;
        }
        if (n <= 0) {
            return cJSON_CreateObject();
        }
        cJSON **slots = (cJSON **)calloc((size_t)n, sizeof(cJSON *));
        if (slots == NULL) {
            return NULL;
        }
        int ix = 0;
        for (cJSON *c = ((cJSON *)src)->child; c != NULL; c = c->next) {
            slots[ix++] = c;
        }
        qsort(slots, (size_t)n, sizeof(cJSON *), cmp_cjson_child_key);
        cJSON *out = cJSON_CreateObject();
        if (out == NULL) {
            free(slots);
            return NULL;
        }
        for (int i = 0; i < n; i++) {
            cJSON *child = slots[i];
            if (child == NULL || child->string == NULL) {
                continue;
            }
            cJSON *nv = dup_sorted_recursive(child);
            if (nv == NULL) {
                cJSON_Delete(out);
                free(slots);
                return NULL;
            }
            cJSON_AddItemToObject(out, child->string, nv);
        }
        free(slots);
        return out;
    }
    return cJSON_Duplicate((cJSON *)src, 1);
}

esp_err_t service_auth_sign_cjson_object(const struct cJSON *root, char *out_signature)
{
    if (out_signature == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    out_signature[0] = '\0';
    if (root == NULL || !cJSON_IsObject((cJSON *)root)) {
        return ESP_ERR_INVALID_ARG;
    }

    cJSON *dup = cJSON_Duplicate((cJSON *)root, 1);
    if (dup == NULL) {
        return ESP_ERR_NO_MEM;
    }
    cJSON_DeleteItemFromObject(dup, "signature");

    cJSON *sorted = dup_sorted_recursive(dup);
    cJSON_Delete(dup);
    if (sorted == NULL) {
        return ESP_ERR_NO_MEM;
    }

    char *canonical = cJSON_PrintUnformatted(sorted);
    cJSON_Delete(sorted);
    if (canonical == NULL) {
        return ESP_ERR_NO_MEM;
    }

    esp_err_t e = service_auth_sign_payload(canonical, out_signature);
    free(canonical);
    return e;
}
