#include "hal_log.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "nvs.h"
#include <string.h>
#include <stdarg.h>
#include <stdio.h>

static const char *TAG = "HAL_LOG";

esp_err_t hal_log_init(void) {
    // 此处可接管 vprintf 或设置系统级的默认 log formatter，如：
    // esp_log_set_vprintf(...)
    // 强制加入系统剩余堆内存 (Heap) 或任务名称信息
    ESP_LOGI(TAG, "Hardware Abstraction Layer Log System Initialized.");
    return ESP_OK;
}

void hal_log_write_fatal_to_nvs(const char* tag, const char* format, ...) {
    // 桩代码实现（Mock）：演示崩溃日志持久化落盘机制
    // 生产环境中，此处会打开专门的 NVS 分区保存日志。待下一次系统重启后上报云端。
    
    char buffer[128];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    // TODO: 实现真正的 NVS 存储记录逻辑，并实现环形队列避免写爆 Flash
    ESP_LOGW("HAL_LOG_NVS", "[MOCK NVS WRITE] Flash Dump Saved: [%s] %s", tag, buffer);
}
