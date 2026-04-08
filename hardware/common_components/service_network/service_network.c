#include "service_network.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include "esp_sntp.h"

static const char *TAG = "SERVICE_NETWORK_MOCK";

esp_err_t service_network_provisioning_start(network_status_cb_t cb) {
    ESP_LOGI(TAG, "[MOCK] 配网服务启动，跳过真实的 AP/SoftAP 强制导流流程...");
    
    // 模拟连网需要 2 秒的时间
    vTaskDelay(pdMS_TO_TICKS(2000));
    ESP_LOGI(TAG, "[MOCK] 成功“伪造”连接到 SSID: Hotel_Guest_WIFI, 拿到 IP: 192.168.1.100");

    // 调用传进来的回调函数，告诉业务层我们“连上网”了
    if (cb != NULL) {
        cb(true, "192.168.1.100");
    }

    // 启动 NTP 时间同步 (Mock阶段不实际联网，仅打印日志并设置一个假时间)
    ESP_LOGI(TAG, "[MOCK] 启动 SNTP 同步...");
    setenv("TZ", "CST-8", 1); // 设置为中国标准时间
    tzset();
    
    // TODO: 硬件到位后替换为真实的 wifi_provisioning (SoftAP+Web) 以及 esp_wifi_start() 注册事件循环
    return ESP_OK;
}

esp_err_t service_network_read_nvs_string(const char* key, char* out_value, size_t max_len) {
    if (key == NULL || out_value == NULL) return ESP_ERR_INVALID_ARG;

    // 假设业务层想读取 "Room_ID"
    if (strcmp(key, "Room_ID") == 0) {
        strncpy(out_value, "301", max_len);
        ESP_LOGI(TAG, "[MOCK] NVS 虚拟读取: 查找到键值 %s，返回固定房号: 301", key);
        return ESP_OK;
    }

    ESP_LOGE(TAG, "[MOCK] NVS 虚拟读取: 未找到键值 %s", key);
    // TODO: 硬件到位后替换为 nvs_open() 和 nvs_get_str()
    return ESP_ERR_NOT_FOUND;
}

void service_network_get_iso8601_timestamp(char* out_buffer, size_t max_len) {
    if (out_buffer == NULL || max_len == 0) return;
    
    time_t now;
    struct tm timeinfo;
    time(&now);
    
    // 在纯 Mock 阶段，如果没有真实的 RTC 时间，我们返回一个固定的伪造时间
    // 实际量产代码中这里会使用 localtime_r 并且获取真实的毫秒
    if (now < 100000) {
        // 如果时间尚未同步（比如刚开机），返回规范示例文档里的写死时间，防止后端报错
        snprintf(out_buffer, max_len, "2026-04-07T00:00:00.000Z");
        return;
    }
    
    localtime_r(&now, &timeinfo);
    
    // 构造 ISO8601 格式: YYYY-MM-DDTHH:mm:ss.sssZ
    // (此处简化处理毫秒为000)
    snprintf(out_buffer, max_len, "%04d-%02d-%02dT%02d:%02d:%02d.000Z",
             timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
             timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
}
