#pragma once

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    DRIVER_RELAY_ACTIVE_HIGH = 0,
    DRIVER_RELAY_ACTIVE_LOW = 1,
} driver_relay_active_level_t;

esp_err_t driver_relay_init(int gpio_num, driver_relay_active_level_t active_level, bool default_on);
esp_err_t driver_relay_set(bool on);
esp_err_t driver_relay_toggle(void);
esp_err_t driver_relay_get(bool *out_on);

#ifdef __cplusplus
}
#endif
