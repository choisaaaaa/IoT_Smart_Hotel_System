#include "hal_sensors.h"
#include "esp_log.h"
#include "driver_dht11.h"
#include "driver_mq2.h"
#include "driver_ldr.h"
#include "driver_rd03_simple.h"
#include "global_config.h"

static const char *TAG = "HAL_SENSORS";
static bool s_dht11_ready = false;
static bool s_mq2_ready = false;
static bool s_ldr_ready = false;
static bool s_rd03_ready = false;

esp_err_t hal_sensors_init(void) {
    // 杜邦线基线：DHT11 DATA -> GPIO15（与 docs/22、docs/24 对齐）
    esp_err_t err = driver_dht11_init(15);
    if (err == ESP_OK) {
        s_dht11_ready = true;
        ESP_LOGI(TAG, "DHT11 初始化成功: GPIO15");
    } else {
        ESP_LOGW(TAG, "DHT11 初始化失败: %s", esp_err_to_name(err));
    }

    err = driver_mq2_init(GLOBAL_ADC_MQ2_PIN, -1);
    if (err == ESP_OK) {
        s_mq2_ready = true;
        ESP_LOGI(TAG, "MQ2 初始化成功: AO GPIO%d", GLOBAL_ADC_MQ2_PIN);
    } else {
        ESP_LOGW(TAG, "MQ2 初始化失败: %s", esp_err_to_name(err));
    }

    err = driver_ldr_init(GLOBAL_ADC_LDR_PIN);
    if (err == ESP_OK) {
        s_ldr_ready = true;
        ESP_LOGI(TAG, "光敏初始化成功: AO GPIO%d", GLOBAL_ADC_LDR_PIN);
    } else {
        ESP_LOGW(TAG, "光敏初始化失败: %s", esp_err_to_name(err));
    }

    err = driver_rd03_simple_init(GLOBAL_RD03_OT2_PIN);
    if (err == ESP_OK) {
        s_rd03_ready = true;
        ESP_LOGI(TAG, "毫米波 OT2 初始化成功: GPIO%d", GLOBAL_RD03_OT2_PIN);
    } else {
        ESP_LOGW(TAG, "毫米波 OT2 初始化失败: %s", esp_err_to_name(err));
    }

    if (!s_dht11_ready && !s_mq2_ready && !s_ldr_ready && !s_rd03_ready) {
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

    if (s_dht11_ready) {
        driver_dht11_data_t dht = {0};
        if (driver_dht11_read(&dht) == ESP_OK) {
            out_data->temperature = dht.temperature_c;
            out_data->humidity = dht.humidity_percent;
        }
    }

    if (s_mq2_ready) {
        int mq_raw = 0;
        if (driver_mq2_read_raw(&mq_raw) == ESP_OK && mq_raw >= 0) {
            out_data->air_quality_adc = (uint16_t)mq_raw;
        }
    }

    if (s_ldr_ready) {
        int ldr_raw = 0;
        if (driver_ldr_read_raw(&ldr_raw) == ESP_OK && ldr_raw >= 0) {
            out_data->light_adc = (uint16_t)ldr_raw;
        }
    }

    if (s_rd03_ready) {
        bool present = false;
        if (driver_rd03_simple_read(&present) == ESP_OK) {
            out_data->is_human_present = present;
        }
    }

    ESP_LOGI(TAG, "传感器读取完成 T=%.1fC H=%.1f%% MQ2=%u LDR=%u Human=%d",
             out_data->temperature,
             out_data->humidity,
             (unsigned)out_data->air_quality_adc,
             (unsigned)out_data->light_adc,
             out_data->is_human_present ? 1 : 0);
    return ESP_OK;
}
