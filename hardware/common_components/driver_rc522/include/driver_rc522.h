#pragma once

#include "esp_err.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// 初始化 RC522 (I2C接口)
esp_err_t driver_rc522_init(void);

// 验证并读取特定加密扇区的数据
esp_err_t driver_rc522_read_sector(uint8_t sector_num, const uint8_t *key, uint8_t *out_data);

// 格式化并写入加密数据至特定扇区（供前台发卡端使用）
esp_err_t driver_rc522_write_sector(uint8_t sector_num, const uint8_t *key, const uint8_t *data);

#ifdef __cplusplus
}
#endif
