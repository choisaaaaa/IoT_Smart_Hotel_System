#pragma once
#include "esp_err.h"
#include "esp_log.h"

#ifdef __cplusplus
extern "C" {
#endif

// ==============================================================================
// 统一硬件日志抽象层 (HAL Log)
// 接管系统原生的 ESP_LOG 机制，以实现更规范的输出格式和高级路由功能 (如异常日志 NVS 落盘)
// ==============================================================================

// 初始化硬件日志系统
esp_err_t hal_log_init(void);

// 定义统一日志等级宏 (日常开发均强制使用 HAL_LOG 替代 ESP_LOG)
#define HAL_LOGI(tag, format, ...) ESP_LOGI(tag, format, ##__VA_ARGS__)
#define HAL_LOGW(tag, format, ...) ESP_LOGW(tag, format, ##__VA_ARGS__)
// 针对 Error 级别：除了打印到串口，还会触发 NVS 持久化存储机制，防掉电丢失
#define HAL_LOGE(tag, format, ...) do { \
    ESP_LOGE(tag, format, ##__VA_ARGS__); \
    hal_log_write_fatal_to_nvs(tag, format, ##__VA_ARGS__); \
} while(0)
#define HAL_LOGD(tag, format, ...) ESP_LOGD(tag, format, ##__VA_ARGS__)

// [高级特性占位] 将致命崩溃日志写入 NVS Flash，为重启后的云端现场恢复提供依据
void hal_log_write_fatal_to_nvs(const char* tag, const char* format, ...);

#ifdef __cplusplus
}
#endif
