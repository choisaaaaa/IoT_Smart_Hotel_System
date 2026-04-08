#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t driver_buzzer_active_init(int gpio_num, bool active_high);
esp_err_t driver_buzzer_active_on(void);
esp_err_t driver_buzzer_active_off(void);
esp_err_t driver_buzzer_active_beep(uint8_t count, uint32_t duration_ms, uint32_t gap_ms);

#ifdef __cplusplus
}
#endif
