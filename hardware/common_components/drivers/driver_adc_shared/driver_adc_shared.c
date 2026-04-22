#include "driver_adc_shared.h"

typedef struct {
    adc_oneshot_unit_handle_t handle;
    uint16_t ref_count;
} adc_shared_slot_t;

static adc_shared_slot_t s_adc_slots[2] = {0};

static int unit_to_index(adc_unit_t unit_id)
{
    if (unit_id == ADC_UNIT_1) {
        return 0;
    }
    if (unit_id == ADC_UNIT_2) {
        return 1;
    }
    return -1;
}

esp_err_t driver_adc_shared_acquire(adc_unit_t unit_id, adc_oneshot_unit_handle_t *out_handle)
{
    if (out_handle == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    int idx = unit_to_index(unit_id);
    if (idx < 0) {
        return ESP_ERR_INVALID_ARG;
    }

    if (s_adc_slots[idx].handle == NULL) {
        adc_oneshot_unit_init_cfg_t unit_cfg = {
            .unit_id = unit_id,
        };
        esp_err_t err = adc_oneshot_new_unit(&unit_cfg, &s_adc_slots[idx].handle);
        if (err != ESP_OK) {
            return err;
        }
    }

    s_adc_slots[idx].ref_count++;
    *out_handle = s_adc_slots[idx].handle;
    return ESP_OK;
}

esp_err_t driver_adc_shared_release(adc_unit_t unit_id)
{
    int idx = unit_to_index(unit_id);
    if (idx < 0) {
        return ESP_ERR_INVALID_ARG;
    }

    if (s_adc_slots[idx].ref_count == 0) {
        return ESP_ERR_INVALID_STATE;
    }

    s_adc_slots[idx].ref_count--;
    if (s_adc_slots[idx].ref_count == 0 && s_adc_slots[idx].handle != NULL) {
        esp_err_t err = adc_oneshot_del_unit(s_adc_slots[idx].handle);
        if (err != ESP_OK) {
            return err;
        }
        s_adc_slots[idx].handle = NULL;
    }
    return ESP_OK;
}
