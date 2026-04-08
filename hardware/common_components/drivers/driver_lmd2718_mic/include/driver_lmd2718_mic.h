#pragma once

#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int i2s_port;
    int pin_bclk;
    int pin_ws;
    int pin_din;
    uint32_t sample_rate_hz;
} driver_lmd2718_mic_config_t;

esp_err_t driver_lmd2718_mic_init(const driver_lmd2718_mic_config_t *cfg);
esp_err_t driver_lmd2718_mic_read_pcm(int16_t *out_samples, size_t max_samples, size_t *out_read_samples);

#ifdef __cplusplus
}
#endif
