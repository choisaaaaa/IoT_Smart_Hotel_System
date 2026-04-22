#pragma once

#include "esp_err.h"
#include "esp_adc/adc_oneshot.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t driver_adc_shared_acquire(adc_unit_t unit_id, adc_oneshot_unit_handle_t *out_handle);
esp_err_t driver_adc_shared_release(adc_unit_t unit_id);

#ifdef __cplusplus
}
#endif
