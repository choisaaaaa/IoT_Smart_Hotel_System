#include "hal_audio.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "driver_inmp441.h"
#include "driver_pam8403.h"
#include "global_config.h"

static const char *TAG = "HAL_AUDIO";
static bool s_audio_ready = false;
static int16_t s_pcm_buf[512];

esp_err_t hal_audio_init(void) {
    driver_inmp441_config_t mic_cfg = {
        .i2s_port = 0,
        .pin_bclk = GLOBAL_I2S_BCLK_PIN,
        .pin_ws = GLOBAL_I2S_WS_PIN,
        .pin_din = GLOBAL_I2S_DIN_PIN,
        .sample_rate_hz = 8000,
    };
    esp_err_t err = driver_inmp441_init(&mic_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "INMP441 初始化失败: %s", esp_err_to_name(err));
        return err;
    }

    // PAM8403 常见无 EN 引脚，传 -1 仅做逻辑启用。
    err = driver_pam8403_init(-1);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "PAM8403 初始化失败: %s", esp_err_to_name(err));
        return err;
    }

    s_audio_ready = true;
    ESP_LOGI(TAG, "音频驱动初始化完成（INMP441 + PAM8403）");
    return ESP_OK;
}

esp_err_t hal_audio_record_chunk(uint8_t *buffer, size_t max_len, size_t *out_read_len) {
    if (buffer == NULL || out_read_len == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!s_audio_ready) {
        return ESP_ERR_INVALID_STATE;
    }

    size_t max_samples = (max_len < 512) ? max_len : 512;
    size_t read_samples = 0;
    esp_err_t err = driver_inmp441_read_pcm(s_pcm_buf, max_samples, &read_samples);
    if (err != ESP_OK) {
        return err;
    }

    // 将 int16 PCM 简单压缩为 unsigned PCM8，供现有链路使用。
    for (size_t i = 0; i < read_samples; i++) {
        int32_t v = (int32_t)s_pcm_buf[i] >> 8;   // -128..127
        v += 128;                                 // 0..255
        if (v < 0) v = 0;
        if (v > 255) v = 255;
        buffer[i] = (uint8_t)v;
    }
    *out_read_len = read_samples;
    return ESP_OK;
}

esp_err_t hal_audio_play_chunk(const uint8_t *data, size_t len) {
    if (data == NULL || len == 0) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!s_audio_ready) {
        return ESP_ERR_INVALID_STATE;
    }
    return driver_pam8403_play_pcm8(data, len);
}
