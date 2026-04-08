#include "hal_audio.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>

static const char *TAG = "HAL_AUDIO_MOCK";

esp_err_t hal_audio_init(void) {
    ESP_LOGI(TAG, "[MOCK] 音频 I2S(INMP441) 与 DAC(PAM8403) 驱动初始化完毕");
    // TODO: 硬件到位后配置 I2S_NUM_0 录音和 DAC/PWM 音频输出
    return ESP_OK;
}

esp_err_t hal_audio_record_chunk(uint8_t *buffer, size_t max_len, size_t *out_read_len) {
    if (buffer == NULL || out_read_len == NULL) return ESP_ERR_INVALID_ARG;

    // 模拟录制 1024 字节的数据，故意延迟 100ms 假装在采样
    size_t mock_len = (max_len > 1024) ? 1024 : max_len;
    vTaskDelay(pdMS_TO_TICKS(100)); 
    
    // 随便填充点数据（如全 0x80 代表静音的 8bit PCM，或随机噪声）
    memset(buffer, 0x80, mock_len);
    *out_read_len = mock_len;

    ESP_LOGI(TAG, "[MOCK] 录音采样完成，成功读取 %zu Bytes (Push-to-Talk激活中...)", mock_len);
    // TODO: 硬件到位后替换为 i2s_read()
    return ESP_OK;
}

esp_err_t hal_audio_play_chunk(const uint8_t *data, size_t len) {
    if (data == NULL || len == 0) return ESP_ERR_INVALID_ARG;

    ESP_LOGI(TAG, "[MOCK] 收到后端音频流 %zu Bytes，开始交由 DAC 功放播放...", len);
    // 模拟播放消耗的时间
    vTaskDelay(pdMS_TO_TICKS(len / 8)); // 粗略模拟 8kHz 的耗时
    
    // TODO: 硬件到位后替换为 dac_output_voltage() 或 i2s_write()
    return ESP_OK;
}
