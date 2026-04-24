#include "hal_sensors.h"
#include "esp_log.h"
#include "driver_dht11.h"
#include "driver_mq2.h"
#include "driver_ldr.h"
#include "driver_ntc.h"
#include "driver_rd03_simple.h"
#include "global_config.h"

static const char *TAG = "HAL_SENSORS";
static bool s_dht11_ready = false;
static bool s_mq2_ready = false;
static bool s_ldr_ready = false;
static bool s_rd03_ready = false;
static bool s_ntc_ready = false;

static const driver_ntc_config_t k_ntc_default_10k = {
    .r_fixed_ohm = 10000.0f,
    .r_ntc_nominal_ohm = 10000.0f,
    .beta = 3950.0f,
    .t0_kelvin = 298.15f,
};

esp_err_t hal_sensors_init(void) {
    esp_err_t err = ESP_OK;

    if (GLOBAL_DHT11_PIN >= 0) {
        if (GLOBAL_DHT11_PIN == GLOBAL_ADC_MQ2_PIN || GLOBAL_DHT11_PIN == GLOBAL_ADC_LDR_PIN ||
            (GLOBAL_ADC_NTC_PIN >= 0 && GLOBAL_DHT11_PIN == GLOBAL_ADC_NTC_PIN)) {
            ESP_LOGW(TAG, "DHT11 GPIO%d 与 ADC/NTC 引脚冲突，请检查引脚映射", GLOBAL_DHT11_PIN);
        }
        err = driver_dht11_init(GLOBAL_DHT11_PIN);
        if (err == ESP_OK) {
            s_dht11_ready = true;
            ESP_LOGI(TAG, "DHT11 初始化成功: GPIO%d", GLOBAL_DHT11_PIN);
        } else {
            ESP_LOGW(TAG, "DHT11 初始化失败: %s", esp_err_to_name(err));
        }
    } else {
        ESP_LOGI(TAG, "DHT11 未接线（GLOBAL_DHT11_PIN<0），跳过");
    }

    if (GLOBAL_ADC_MQ2_PIN >= 0) {
        err = driver_mq2_init(GLOBAL_ADC_MQ2_PIN, -1);
        if (err == ESP_OK) {
            s_mq2_ready = true;
            ESP_LOGI(TAG, "MQ2 初始化成功: AO GPIO%d", GLOBAL_ADC_MQ2_PIN);
        } else {
            ESP_LOGW(TAG, "MQ2 初始化失败: %s", esp_err_to_name(err));
        }
    } else {
        ESP_LOGI(TAG, "MQ2 未接线（GLOBAL_ADC_MQ2_PIN<0），跳过");
    }

    if (GLOBAL_ADC_LDR_PIN >= 0) {
        err = driver_ldr_init(GLOBAL_ADC_LDR_PIN);
        if (err == ESP_OK) {
            s_ldr_ready = true;
            ESP_LOGI(TAG, "光敏初始化成功: AO GPIO%d", GLOBAL_ADC_LDR_PIN);
        } else {
            ESP_LOGW(TAG, "光敏初始化失败: %s", esp_err_to_name(err));
        }
    } else {
        ESP_LOGI(TAG, "光敏未接线（GLOBAL_ADC_LDR_PIN<0），跳过");
    }

    if (GLOBAL_RD03_OT2_PIN >= 0) {
        err = driver_rd03_simple_init(GLOBAL_RD03_OT2_PIN);
        if (err == ESP_OK) {
            s_rd03_ready = true;
            ESP_LOGI(TAG, "毫米波 OT2 初始化成功: GPIO%d", GLOBAL_RD03_OT2_PIN);
        } else {
            ESP_LOGW(TAG, "毫米波 OT2 初始化失败: %s", esp_err_to_name(err));
        }
    } else {
        ESP_LOGI(TAG, "毫米波 OT2 未启用（GLOBAL_RD03_OT2_PIN < 0）");
    }

    if (GLOBAL_ADC_NTC_PIN >= 0) {
        if ((GLOBAL_ADC_MQ2_PIN >= 0 && GLOBAL_ADC_NTC_PIN == GLOBAL_ADC_MQ2_PIN) ||
            (GLOBAL_ADC_LDR_PIN >= 0 && GLOBAL_ADC_NTC_PIN == GLOBAL_ADC_LDR_PIN)) {
            ESP_LOGW(TAG, "NTC GPIO%d 与 MQ2/LDR ADC 脚冲突", GLOBAL_ADC_NTC_PIN);
        }
        err = driver_ntc_init(GLOBAL_ADC_NTC_PIN, &k_ntc_default_10k);
        if (err == ESP_OK) {
            s_ntc_ready = true;
            ESP_LOGI(TAG, "NTC 初始化成功: GPIO%d (10k/B3950)", GLOBAL_ADC_NTC_PIN);
        } else {
            ESP_LOGW(TAG, "NTC 初始化失败: %s", esp_err_to_name(err));
        }
    } else {
        ESP_LOGI(TAG, "NTC 未接线（GLOBAL_ADC_NTC_PIN<0），跳过");
    }

    if (!s_dht11_ready && !s_mq2_ready && !s_ldr_ready && !s_rd03_ready && !s_ntc_ready) {
        ESP_LOGE(TAG, "所有传感器初始化失败");
        return ESP_FAIL;
    }
    return ESP_OK;
}

esp_err_t hal_sensors_read_all(sensor_data_t *out_data) {
    if (out_data == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    out_data->temperature = 0.0f;
    out_data->humidity = 0.0f;
    out_data->air_quality_adc = 0;
    out_data->light_adc = 0;
    out_data->is_human_present = false;
    out_data->dht_valid = false;
    out_data->mq2_valid = false;
    out_data->ldr_valid = false;
    out_data->rd03_valid = false;
    out_data->ntc_valid = false;
    out_data->ntc_temp_c = 0.0f;

    if (s_dht11_ready) {
        driver_dht11_data_t dht = {0};
        if (driver_dht11_read(&dht) == ESP_OK) {
            out_data->temperature = dht.temperature_c;
            out_data->humidity = dht.humidity_percent;
            out_data->dht_valid = true;
        } else {
            ESP_LOGW(TAG, "DHT11 读取失败，本轮不上报温湿度");
        }
    }

    if (s_mq2_ready) {
        int mq_raw = 0;
        if (driver_mq2_read_raw(&mq_raw) == ESP_OK && mq_raw >= 0) {
            out_data->air_quality_adc = (uint16_t)mq_raw;
            out_data->mq2_valid = true;
        }
    }

    if (s_ldr_ready) {
        int ldr_raw = 0;
        if (driver_ldr_read_raw(&ldr_raw) == ESP_OK && ldr_raw >= 0) {
            out_data->light_adc = (uint16_t)ldr_raw;
            out_data->ldr_valid = true;
        }
    }

    if (s_rd03_ready) {
        bool present = false;
        if (driver_rd03_simple_read(&present) == ESP_OK) {
            out_data->is_human_present = present;
            out_data->rd03_valid = true;
        }
    }

    if (s_ntc_ready) {
        float t = 0.0f;
        if (driver_ntc_read_temperature_c(&t) == ESP_OK) {
            out_data->ntc_temp_c = t;
            out_data->ntc_valid = true;
        }
    }

    if (s_rd03_ready) {
        ESP_LOGI(TAG, "传感器读取完成 T=%.1fC H=%.1f%% MQ2=%u LDR=%u NTC=%.1f(valid=%d) Human=%d",
                 out_data->temperature,
                 out_data->humidity,
                 (unsigned)out_data->air_quality_adc,
                 (unsigned)out_data->light_adc,
                 (double)out_data->ntc_temp_c,
                 out_data->ntc_valid ? 1 : 0,
                 out_data->is_human_present ? 1 : 0);
    } else {
        ESP_LOGI(TAG, "传感器读取完成 T=%.1fC H=%.1f%% MQ2=%u LDR=%u NTC=%.1f(valid=%d)",
                 out_data->temperature,
                 out_data->humidity,
                 (unsigned)out_data->air_quality_adc,
                 (unsigned)out_data->light_adc,
                 (double)out_data->ntc_temp_c,
                 out_data->ntc_valid ? 1 : 0);
    }
    return ESP_OK;
}
