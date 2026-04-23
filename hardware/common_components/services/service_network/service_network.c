#include "service_network.h"
#include "sdkconfig.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include "esp_sntp.h"

#if !CONFIG_SERVICE_NETWORK_USE_MOCK
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "nvs.h"
#endif

#if CONFIG_SERVICE_NETWORK_USE_MOCK
static const char *TAG = "SERVICE_NETWORK_MOCK";
#else
static const char *TAG = "service_network";
#endif

#if !CONFIG_SERVICE_NETWORK_USE_MOCK

static network_status_cb_t s_net_cb;
static bool s_got_ip;
static char s_ip_str[20];

#if CONFIG_SERVICE_NETWORK_SOFTAP_PROVISIONING

#include "network_provisioning/manager.h"
#include "network_provisioning/scheme_softap.h"
#if CONFIG_SERVICE_NETWORK_PROV_SECURITY_1 || CONFIG_SERVICE_NETWORK_PROV_SECURITY_2
#include "protocomm_security.h"
#endif

#if CONFIG_SERVICE_NETWORK_PROV_SECURITY_2
/* 与 ESP-IDF examples/network/sta2eth 一致：username=wifiprov, password=abcd1234（App「设置」里用户名 + 连接时密码） */
static const char s_prov_sec2_salt[] = {
    0x03, 0x6e, 0xe0, 0xc7, 0xbc, 0xb9, 0xed, 0xa8, 0x4c, 0x9e, 0xac, 0x97, 0xd9, 0x3d, 0xec, 0xf4,
};
static const char s_prov_sec2_verifier[] = {
    0x7c, 0x7c, 0x85, 0x47, 0x65, 0x08, 0x94, 0x6d, 0xd6, 0x36, 0xaf, 0x37, 0xd7, 0xe8, 0x91, 0x43,
    0x78, 0xcf, 0xfd, 0x61, 0x6c, 0x59, 0xd2, 0xf8, 0x39, 0x08, 0x12, 0x72, 0x38, 0xde, 0x9e, 0x24,
    0xa4, 0x70, 0x26, 0x1c, 0xdf, 0xa9, 0x03, 0xc2, 0xb2, 0x70, 0xe7, 0xb1, 0x32, 0x24, 0xda, 0x11,
    0x1d, 0x97, 0x18, 0xdc, 0x60, 0x72, 0x08, 0xcc, 0x9a, 0xc9, 0x0c, 0x48, 0x27, 0xe2, 0xae, 0x89,
    0xaa, 0x16, 0x25, 0xb8, 0x04, 0xd2, 0x1a, 0x9b, 0x3a, 0x8f, 0x37, 0xf6, 0xe4, 0x3a, 0x71, 0x2e,
    0xe1, 0x27, 0x86, 0x6e, 0xad, 0xce, 0x28, 0xff, 0x54, 0x46, 0x60, 0x1f, 0xb9, 0x96, 0x87, 0xdc,
    0x57, 0x40, 0xa7, 0xd4, 0x6c, 0xc9, 0x77, 0x54, 0xdc, 0x16, 0x82, 0xf0, 0xed, 0x35, 0x6a, 0xc4,
    0x70, 0xad, 0x3d, 0x90, 0xb5, 0x81, 0x94, 0x70, 0xd7, 0xbc, 0x65, 0xb2, 0xd5, 0x18, 0xe0, 0x2e,
    0xc3, 0xa5, 0xf9, 0x68, 0xdd, 0x64, 0x7b, 0xb8, 0xb7, 0x3c, 0x9c, 0xfc, 0x00, 0xd8, 0x71, 0x7e,
    0xb7, 0x9a, 0x7c, 0xb1, 0xb7, 0xc2, 0xc3, 0x18, 0x34, 0x29, 0x32, 0x43, 0x3e, 0x00, 0x99, 0xe9,
    0x82, 0x94, 0xe3, 0xd8, 0x2a, 0xb0, 0x96, 0x29, 0xb7, 0xdf, 0x0e, 0x5f, 0x08, 0x33, 0x40, 0x76,
    0x52, 0x91, 0x32, 0x00, 0x9f, 0x97, 0x2c, 0x89, 0x6c, 0x39, 0x1e, 0xc8, 0x28, 0x05, 0x44, 0x17,
    0x3f, 0x68, 0x02, 0x8a, 0x9f, 0x44, 0x61, 0xd1, 0xf5, 0xa1, 0x7e, 0x5a, 0x70, 0xd2, 0xc7, 0x23,
    0x81, 0xcb, 0x38, 0x68, 0xe4, 0x2c, 0x20, 0xbc, 0x40, 0x57, 0x76, 0x17, 0xbd, 0x08, 0xb8, 0x96,
    0xbc, 0x26, 0xeb, 0x32, 0x46, 0x69, 0x35, 0x05, 0x8c, 0x15, 0x70, 0xd9, 0x1b, 0xe9, 0xbe, 0xcc,
    0xa9, 0x38, 0xa6, 0x67, 0xf0, 0xad, 0x50, 0x13, 0x19, 0x72, 0x64, 0xbf, 0x52, 0xc2, 0x34, 0xe2,
    0x1b, 0x11, 0x79, 0x74, 0x72, 0xbd, 0x34, 0x5b, 0xb1, 0xe2, 0xfd, 0x66, 0x73, 0xfe, 0x71, 0x64,
    0x74, 0xd0, 0x4e, 0xbc, 0x51, 0x24, 0x19, 0x40, 0x87, 0x0e, 0x92, 0x40, 0xe6, 0x21, 0xe7, 0x2d,
    0x4e, 0x37, 0x76, 0x2f, 0x2e, 0xe2, 0x68, 0xc7, 0x89, 0xe8, 0x32, 0x13, 0x42, 0x06, 0x84, 0x84,
    0x53, 0x4a, 0xb3, 0x0c, 0x1b, 0x4c, 0x8d, 0x1c, 0x51, 0x97, 0x19, 0xab, 0xae, 0x77, 0xff, 0xdb,
    0xec, 0xf0, 0x10, 0x95, 0x34, 0x33, 0x6b, 0xcb, 0x3e, 0x84, 0x0f, 0xb9, 0xd8, 0x5f, 0xb8, 0xa0,
    0xb8, 0x55, 0x53, 0x3e, 0x70, 0xf7, 0x18, 0xf5, 0xce, 0x7b, 0x4e, 0xbf, 0x27, 0xce, 0xce, 0xa8,
    0xb3, 0xbe, 0x40, 0xc5, 0xc5, 0x32, 0x29, 0x3e, 0x71, 0x64, 0x9e, 0xde, 0x8c, 0xf6, 0x75, 0xa1,
    0xe6, 0xf6, 0x53, 0xc8, 0x31, 0xa8, 0x78, 0xde, 0x50, 0x40, 0xf7, 0x62, 0xde, 0x36, 0xb2, 0xba,
};
static network_prov_security2_params_t s_prov_sec2_params;
#endif /* CONFIG_SERVICE_NETWORK_PROV_SECURITY_2 */

static void build_prov_service_name(char *out, size_t out_sz)
{
    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    snprintf(out, out_sz, "%s%02X%02X%02X",
             CONFIG_SERVICE_NETWORK_PROV_SERVICE_PREFIX, mac[3], mac[4], mac[5]);
}

static const char *prov_ap_password_or_null(void)
{
    const char *p = CONFIG_SERVICE_NETWORK_PROV_AP_PASSWORD;
    if (p == NULL || p[0] == '\0') {
        return NULL;
    }
    if (strlen(p) < 8) {
        ESP_LOGW(TAG, "SoftAP 密码长度不足 8，将使用开放热点（请改 Kconfig 或留空）");
        return NULL;
    }
    return p;
}

#if CONFIG_SERVICE_NETWORK_PROV_SECURITY_1 || CONFIG_SERVICE_NETWORK_PROV_SECURITY_2
static void prov_security_session_log(int32_t event_id)
{
    switch (event_id) {
    case PROTOCOMM_SECURITY_SESSION_SETUP_OK:
        ESP_LOGI(TAG, "配网安全会话已建立");
        break;
    case PROTOCOMM_SECURITY_SESSION_INVALID_SECURITY_PARAMS:
        ESP_LOGE(TAG, "配网安全参数无效");
        break;
    case PROTOCOMM_SECURITY_SESSION_CREDENTIALS_MISMATCH:
        ESP_LOGE(TAG, "PoP 与设备不一致（检查 Security1 的 PoP）");
        break;
    default:
        break;
    }
}
#endif

static void wifi_event_handler_prov(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    (void)arg;

    if (event_base == NETWORK_PROV_EVENT) {
        switch (event_id) {
        case NETWORK_PROV_START:
            ESP_LOGI(TAG, "WiFi Provisioning 已启动（SoftAP）");
            break;
        case NETWORK_PROV_WIFI_CRED_RECV: {
            wifi_sta_config_t *sta = (wifi_sta_config_t *)event_data;
            ESP_LOGI(TAG, "收到路由器凭证 SSID=%s", (const char *)sta->ssid);
            break;
        }
        case NETWORK_PROV_WIFI_CRED_FAIL: {
            network_prov_wifi_sta_fail_reason_t *reason =
                (network_prov_wifi_sta_fail_reason_t *)event_data;
            ESP_LOGE(TAG, "配网后连路由器失败: %s",
                     (*reason == NETWORK_PROV_WIFI_STA_AUTH_ERROR) ? "认证失败" : "找不到 AP");
            break;
        }
        case NETWORK_PROV_WIFI_CRED_SUCCESS:
            ESP_LOGI(TAG, "路由器连接成功（配网流程内）");
            break;
        case NETWORK_PROV_END:
            network_prov_mgr_deinit();
            ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
            ESP_ERROR_CHECK(esp_wifi_start());
            ESP_LOGI(TAG, "配网服务已结束，已切换为 STA 模式");
            break;
        default:
            break;
        }
        return;
    }

#if CONFIG_SERVICE_NETWORK_PROV_SECURITY_1 || CONFIG_SERVICE_NETWORK_PROV_SECURITY_2
    if (event_base == PROTOCOMM_SECURITY_SESSION_EVENT) {
        prov_security_session_log(event_id);
        return;
    }
#endif

    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
        return;
    }

    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        if (s_got_ip && s_net_cb != NULL) {
            s_got_ip = false;
            s_net_cb(false, NULL);
        }
        esp_wifi_connect();
        return;
    }

    if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *e = (ip_event_got_ip_t *)event_data;
        snprintf(s_ip_str, sizeof(s_ip_str), IPSTR, IP2STR(&e->ip_info.ip));
        ESP_LOGI(TAG, "STA got IP: %s", s_ip_str);
        s_got_ip = true;
        if (s_net_cb != NULL) {
            s_net_cb(true, s_ip_str);
        }
    }
}

static esp_err_t provisioning_start_softap(network_status_cb_t cb)
{
    s_net_cb = cb;
    s_got_ip = false;

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();
    esp_netif_create_default_wifi_ap();

    wifi_init_config_t wcfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&wcfg));

    ESP_ERROR_CHECK(esp_event_handler_register(NETWORK_PROV_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler_prov,
                                               NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler_prov, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler_prov, NULL));
#if CONFIG_SERVICE_NETWORK_PROV_SECURITY_1 || CONFIG_SERVICE_NETWORK_PROV_SECURITY_2
    ESP_ERROR_CHECK(esp_event_handler_register(PROTOCOMM_SECURITY_SESSION_EVENT, ESP_EVENT_ANY_ID,
                                               &wifi_event_handler_prov, NULL));
#endif

    network_prov_mgr_config_t prov_cfg = {
        .scheme = network_prov_scheme_softap,
        .scheme_event_handler = NETWORK_PROV_EVENT_HANDLER_NONE,
        .app_event_handler = NETWORK_PROV_EVENT_HANDLER_NONE,
    };
    ESP_ERROR_CHECK(network_prov_mgr_init(prov_cfg));

    bool provisioned = false;
    ESP_ERROR_CHECK(network_prov_mgr_is_wifi_provisioned(&provisioned));

    const char *service_key = prov_ap_password_or_null();

    if (!provisioned) {
        char service_name[40];
        build_prov_service_name(service_name, sizeof(service_name));

#if CONFIG_SERVICE_NETWORK_PROV_SECURITY_2
        s_prov_sec2_params.salt = s_prov_sec2_salt;
        s_prov_sec2_params.salt_len = sizeof(s_prov_sec2_salt);
        s_prov_sec2_params.verifier = s_prov_sec2_verifier;
        s_prov_sec2_params.verifier_len = sizeof(s_prov_sec2_verifier);
        ESP_ERROR_CHECK(network_prov_mgr_start_provisioning(NETWORK_PROV_SECURITY_2, &s_prov_sec2_params,
                                                          service_name, service_key));
        ESP_LOGW(TAG,
                 "配网 Security 2：连热点 \"%s\"%s；App 设置里用户名 wifiprov，连接设备密码 abcd1234（与内嵌 verifier 一致，仅开发）",
                 service_name, service_key ? "（需热点密码）" : "");
#elif CONFIG_SERVICE_NETWORK_PROV_SECURITY_1
        const char *pop = CONFIG_SERVICE_NETWORK_PROV_POP;
        ESP_ERROR_CHECK(
            network_prov_mgr_start_provisioning(NETWORK_PROV_SECURITY_1, pop, service_name, service_key));
        ESP_LOGW(TAG,
                 "配网 Security 1：连热点 \"%s\"%s；App 关「Secured」或选 Security 1，PoP=%s",
                 service_name, service_key ? "（需热点密码）" : "", CONFIG_SERVICE_NETWORK_PROV_POP);
#else
        ESP_ERROR_CHECK(
            network_prov_mgr_start_provisioning(NETWORK_PROV_SECURITY_0, NULL, service_name, service_key));
        ESP_LOGW(TAG,
                 "配网 Security 0：连热点 \"%s\"%s；App 须关闭加密（与固件一致）",
                 service_name, service_key ? "（需热点密码）" : "（开放热点）");
#endif
        ESP_LOGW(TAG,
                 "若目标 WiFi 是本机「个人热点」：同一手机通常无法同时「开热点」又「连板子热点」，请用电脑/平板/第二部手机连板子热点后在 App 里填写热点 SSID/密码；或后续可改 BLE 配网/串口配网。");
    } else {
        ESP_LOGI(TAG, "检测到已配网，直接启动 STA");
        network_prov_mgr_deinit();
        ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
        ESP_ERROR_CHECK(esp_wifi_start());
    }

    setenv("TZ", "CST-8", 1);
    tzset();

    return ESP_OK;
}

#else /* !CONFIG_SERVICE_NETWORK_SOFTAP_PROVISIONING */

static void wifi_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    (void)arg;
    (void)event_data;

    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
        return;
    }

    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        if (s_got_ip && s_net_cb != NULL) {
            s_got_ip = false;
            s_net_cb(false, NULL);
        }
        esp_wifi_connect();
        return;
    }

    if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *e = (ip_event_got_ip_t *)event_data;
        snprintf(s_ip_str, sizeof(s_ip_str), IPSTR, IP2STR(&e->ip_info.ip));
        ESP_LOGI(TAG, "STA got IP: %s", s_ip_str);
        s_got_ip = true;
        if (s_net_cb != NULL) {
            s_net_cb(true, s_ip_str);
        }
    }
}

static esp_err_t provisioning_start_sta_menuconfig(network_status_cb_t cb)
{
    const char *ssid = CONFIG_SERVICE_NETWORK_WIFI_SSID;
    const char *pass = CONFIG_SERVICE_NETWORK_WIFI_PASSWORD;

    if (ssid == NULL || strlen(ssid) == 0) {
        ESP_LOGE(TAG, "WiFi SSID 为空：请在 menuconfig → Service network 中填写手机热点名称后重新编译");
        return ESP_ERR_INVALID_ARG;
    }

    s_net_cb = cb;
    s_got_ip = false;

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));

    wifi_config_t wifi_config = {0};
    strncpy((char *)wifi_config.sta.ssid, ssid, sizeof(wifi_config.sta.ssid) - 1);
    strncpy((char *)wifi_config.sta.password, pass, sizeof(wifi_config.sta.password) - 1);
    if (strlen(pass) == 0) {
        wifi_config.sta.threshold.authmode = WIFI_AUTH_OPEN;
    } else {
        wifi_config.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;
    }

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "WiFi STA 已启动，正在连接 SSID: %s", ssid);
    setenv("TZ", "CST-8", 1);
    tzset();

    return ESP_OK;
}

#endif /* CONFIG_SERVICE_NETWORK_SOFTAP_PROVISIONING */

#endif /* !CONFIG_SERVICE_NETWORK_USE_MOCK */

esp_err_t service_network_provisioning_start(network_status_cb_t cb)
{
#if CONFIG_SERVICE_NETWORK_USE_MOCK
    ESP_LOGI(TAG, "[MOCK] 配网服务启动，跳过真实的 AP/SoftAP 强制导流流程...");

    vTaskDelay(pdMS_TO_TICKS(2000));
    ESP_LOGI(TAG, "[MOCK] 成功“伪造”连接到 SSID: Hotel_Guest_WIFI, 拿到 IP: 192.168.1.100");

    if (cb != NULL) {
        cb(true, "192.168.1.100");
    }

    ESP_LOGI(TAG, "[MOCK] 启动 SNTP 同步...");
    setenv("TZ", "CST-8", 1);
    tzset();

    return ESP_OK;
#else
#if CONFIG_SERVICE_NETWORK_SOFTAP_PROVISIONING
    return provisioning_start_softap(cb);
#else
    return provisioning_start_sta_menuconfig(cb);
#endif
#endif
}

esp_err_t service_network_read_nvs_string(const char *key, char *out_value, size_t max_len)
{
    if (key == NULL || out_value == NULL || max_len == 0) {
        return ESP_ERR_INVALID_ARG;
    }

#if CONFIG_SERVICE_NETWORK_USE_MOCK
    if (strcmp(key, "Room_ID") == 0) {
        strncpy(out_value, "301", max_len - 1);
        out_value[max_len - 1] = '\0';
        ESP_LOGI(TAG, "[MOCK] NVS 虚拟读取: 查找到键值 %s，返回固定房号: 301", key);
        return ESP_OK;
    }
    if (strcmp(key, "Floor_ID") == 0) {
        strncpy(out_value, "03", max_len - 1);
        out_value[max_len - 1] = '\0';
        ESP_LOGI(TAG, "[MOCK] NVS 虚拟读取: 查找到键值 %s，返回固定楼层: 03", key);
        return ESP_OK;
    }
    if (strcmp(key, "FrontDesk_ID") == 0) {
        strncpy(out_value, "01", max_len - 1);
        out_value[max_len - 1] = '\0';
        ESP_LOGI(TAG, "[MOCK] NVS 虚拟读取: 查找到键值 %s，返回固定前台编号: 01", key);
        return ESP_OK;
    }
    if (strcmp(key, "MQTT_BROKER_URI") == 0) {
        strncpy(out_value, "mqtt://8.134.166.69:1883", max_len - 1);
        out_value[max_len - 1] = '\0';
        ESP_LOGI(TAG, "[MOCK] NVS 虚拟读取: 查找到键值 %s，返回固定 Broker 地址", key);
        return ESP_OK;
    }

    ESP_LOGE(TAG, "[MOCK] NVS 虚拟读取: 未找到键值 %s", key);
    return ESP_ERR_NOT_FOUND;
#else
    nvs_handle_t h;
    esp_err_t err = nvs_open("hotel", NVS_READONLY, &h);
    if (err != ESP_OK) {
        return err;
    }
    size_t len = max_len;
    err = nvs_get_str(h, key, out_value, &len);
    nvs_close(h);
    return err;
#endif
}

void service_network_get_iso8601_timestamp(char *out_buffer, size_t max_len)
{
    if (out_buffer == NULL || max_len == 0) {
        return;
    }

    time_t now;
    struct tm timeinfo;
    time(&now);

    if (now < 100000) {
        snprintf(out_buffer, max_len, "2026-04-07T00:00:00.000Z");
        return;
    }

    localtime_r(&now, &timeinfo);
    snprintf(out_buffer, max_len, "%04d-%02d-%02dT%02d:%02d:%02d.000Z",
             timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
             timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
}
