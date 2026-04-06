#include "service_network.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>

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
