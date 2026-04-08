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
    int pin_dout;
    uint32_t sample_rate_hz;
} driver_ns4168_config_t;

esp_err_t driver_ns4168_init(const driver_ns4168_config_t *cfg);
esp_err_t driver_ns4168_play_pcm(const int16_t *samples, size_t sample_count);

#ifdef __cplusplus
}
#endif
