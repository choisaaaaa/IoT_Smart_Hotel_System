#pragma once

#include "esp_err.h"
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// 初始化 RC522 (I2C接口)
esp_err_t driver_rc522_init(void);

// 验证并读取特定加密扇区的数据
esp_err_t driver_rc522_read_sector(uint8_t sector_num, const uint8_t *key, uint8_t *out_data);

// 格式化并写入加密数据至特定扇区（供前台发卡端使用）
esp_err_t driver_rc522_write_sector(uint8_t sector_num, const uint8_t *key, const uint8_t *data);

// 预开发辅助接口：用于无实物联调阶段的刷卡模拟
esp_err_t driver_rc522_mock_present_card(const uint8_t *data, uint16_t data_len);
esp_err_t driver_rc522_mock_clear_card(void);
bool driver_rc522_mock_has_card(void);

#ifdef __cplusplus
}
#endif
