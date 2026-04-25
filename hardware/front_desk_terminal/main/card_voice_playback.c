#include "card_voice_playback.h"
#include "hal_audio.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>

static const char *TAG = "CARD_VOICE";

static int clamp_vol(int v)
{
    if (v < 45) {
        v = 55;
    }
    if (v > 100) {
        v = 100;
    }
    return v;
}

#if HAS_CARD_VOICE_PCM
extern const uint8_t welcome_card_pcm_start[] asm("_binary_welcome_card_pcm_start");
extern const uint8_t welcome_card_pcm_end[] asm("_binary_welcome_card_pcm_end");
extern const uint8_t invalid_card_pcm_start[] asm("_binary_invalid_card_pcm_start");
extern const uint8_t invalid_card_pcm_end[] asm("_binary_invalid_card_pcm_end");

static esp_err_t play_s16le_blocking(const int16_t *pcm, size_t sample_count)
{
    const size_t chunk = 512;
    for (size_t i = 0; i < sample_count && pcm != NULL; i += chunk) {
        size_t n = sample_count - i;
        if (n > chunk) {
            n = chunk;
        }
        esp_err_t e = hal_audio_play_pcm16(pcm + i, n);
        if (e != ESP_OK) {
            return e;
        }
    }
    return ESP_OK;
}

static void play_embedded_pcm(const uint8_t *start, const uint8_t *end)
{
    if (start == NULL || end == NULL || end <= start) {
        return;
    }
    size_t bytes = (size_t)(end - start);
    if (bytes < 2 || (bytes % 2) != 0) {
        ESP_LOGW(TAG, "PCM 长度无效: %u", (unsigned)bytes);
        return;
    }
    size_t samples = bytes / 2;
    if (play_s16le_blocking((const int16_t *)start, samples) != ESP_OK) {
        ESP_LOGW(TAG, "播放 PCM 失败");
    }
}
#endif

void card_voice_play_welcome(int volume_pct_0_100)
{
    int v = clamp_vol(volume_pct_0_100);
    hal_audio_set_playback_volume_pct(v);
#if HAS_CARD_VOICE_PCM
    ESP_LOGI(TAG, "播放欢迎语音 (%d%%)", v);
    play_embedded_pcm(welcome_card_pcm_start, welcome_card_pcm_end);
#else
    (void)hal_audio_beep_volume_pct(v);
#endif
}

void card_voice_play_invalid(int volume_pct_0_100)
{
    int v = clamp_vol(volume_pct_0_100);
    hal_audio_set_playback_volume_pct(v);
#if HAS_CARD_VOICE_PCM
    ESP_LOGI(TAG, "播放非法卡语音 (%d%%)", v);
    play_embedded_pcm(invalid_card_pcm_start, invalid_card_pcm_end);
#else
    (void)hal_audio_beep_volume_pct(v);
    vTaskDelay(pdMS_TO_TICKS(120));
    (void)hal_audio_beep_volume_pct(v);
#endif
}
