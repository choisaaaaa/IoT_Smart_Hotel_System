#pragma once

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float r_fixed_ohm;       // 分压固定电阻阻值，例如 10000
    float r_ntc_nominal_ohm; // NTC 标称阻值（25C），例如 10000
    float beta;              // Beta 值，例如 3950
    float t0_kelvin;         // 标称温度 K，常用 298.15 (25C)
} driver_ntc_config_t;

esp_err_t driver_ntc_init(int gpio_num, const driver_ntc_config_t *cfg);
esp_err_t driver_ntc_read_raw(int *out_raw);
esp_err_t driver_ntc_read_temperature_c(float *out_temp_c);

#ifdef __cplusplus
}
#endif
