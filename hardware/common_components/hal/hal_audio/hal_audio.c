#include "hal_audio.h"
#include "hal_interactive.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include <math.h>
#include <string.h>
#include "driver_ns4168.h"
#include "driver_lmd2718_mic.h"
#include "global_config.h"

static const char *TAG = "HAL_AUDIO";
static bool s_audio_ready = false;
static int16_t s_pcm_buf[512];
static SemaphoreHandle_t s_spk_mtx;
/** 下行/流式播放相对旋钮音量（0–100），由 main 与 EC11 同步 */
static volatile int s_playback_vol_pct = 100;

/** 旋钮音量反馈：时长与频率（与 HAL_AUDIO_SAMPLE_RATE_HZ 匹配）。 */
#ifndef HAL_AUDIO_UI_BEEP_MS
#define HAL_AUDIO_UI_BEEP_MS 45
#endif
#ifndef HAL_AUDIO_UI_BEEP_HZ
#define HAL_AUDIO_UI_BEEP_HZ 1000
#endif
/** beep 结束后追加静音，避免 I2S TX 欠载后功放/最后一采样被重复听起来像「一直响」 */
#ifndef HAL_AUDIO_UI_BEEP_TAIL_MS
#define HAL_AUDIO_UI_BEEP_TAIL_MS 64
#endif

static esp_err_t spk_write_pcm16_unlocked(const int16_t *samples, size_t sample_count)
{
    if (sample_count > 512) {
        sample_count = 512;
    }
    return driver_ns4168_play_pcm(samples, sample_count);
}

/**
 * 采样率由 global_config 的 GLOBAL_HAL_AUDIO_SAMPLE_RATE_HZ 提供（通常 16k 对齐 ASR；可改 32k 换 PDM 余量）。
 * PDM CLK ≈ fs×64，见 LMD2718T 规格书。
 */
#ifndef HAL_AUDIO_SAMPLE_RATE_HZ
#ifdef GLOBAL_HAL_AUDIO_SAMPLE_RATE_HZ
#define HAL_AUDIO_SAMPLE_RATE_HZ GLOBAL_HAL_AUDIO_SAMPLE_RATE_HZ
#else
#define HAL_AUDIO_SAMPLE_RATE_HZ 32000u
#endif
#endif

esp_err_t hal_audio_init(void) {
    if (GLOBAL_I2S_BCLK_PIN < 0 || GLOBAL_I2S_WS_PIN < 0 || GLOBAL_I2S_DIN_PIN < 0 ||
        GLOBAL_I2S_DOUT_PIN < 0 || GLOBAL_I2S_MIC_PDM_CLK_PIN < 0) {
        ESP_LOGI(TAG,
                 "I2S/PDM 引脚未配置，跳过 MIC/功放；提示音可走有源蜂鸣器 (hal_interactive_beep)");
        s_audio_ready = false;
        return ESP_OK;
    }

    /* 外设分配（ESP32-S3 限制：PDM 模式只支持 I2S0，I2S1 仅 STD/TDM）：
     *   MIC → I2S0 + PDM RX（PDM CLK 独立 GPIO，不与功放 BCLK 共用）
     *   SPK → I2S1 + STD TX
     * 两个外设完全独立，时钟互不干扰。 */
    driver_lmd2718_mic_config_t mic_cfg = {
        .i2s_port = 0,
        .pin_pdm_clk = GLOBAL_I2S_MIC_PDM_CLK_PIN,
        .pin_pdm_din = GLOBAL_I2S_DIN_PIN,
        .sample_rate_hz = HAL_AUDIO_SAMPLE_RATE_HZ,
    };
    esp_err_t err = driver_lmd2718_mic_init(&mic_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "LMD2718T MIC(PDM) 路径初始化失败: %s", esp_err_to_name(err));
        return err;
    }

    driver_ns4168_config_t spk_cfg = {
        .i2s_port = 1,
        .pin_bclk = GLOBAL_I2S_BCLK_PIN,
        .pin_ws = GLOBAL_I2S_WS_PIN,
        .pin_dout = GLOBAL_I2S_DOUT_PIN,
        .sample_rate_hz = HAL_AUDIO_SAMPLE_RATE_HZ,
    };
    err = driver_ns4168_init(&spk_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "NS4168 功放路径初始化失败: %s", esp_err_to_name(err));
        return err;
    }

    if (s_spk_mtx == NULL) {
        s_spk_mtx = xSemaphoreCreateMutex();
        if (s_spk_mtx == NULL) {
            ESP_LOGE(TAG, "喇叭播放互斥创建失败");
            return ESP_ERR_NO_MEM;
        }
    }

    s_audio_ready = true;
    ESP_LOGI(TAG,
             "音频初始化完成: MIC(I2S0 PDM RX clk=%d din=%d) + SPK(I2S1 STD TX bclk=%d ws=%d dout=%d) %luHz",
             GLOBAL_I2S_MIC_PDM_CLK_PIN, GLOBAL_I2S_DIN_PIN, GLOBAL_I2S_BCLK_PIN,
             GLOBAL_I2S_WS_PIN, GLOBAL_I2S_DOUT_PIN,
             (unsigned long)HAL_AUDIO_SAMPLE_RATE_HZ);
    return ESP_OK;
}

void hal_audio_set_playback_volume_pct(int volume_pct_0_100)
{
    if (volume_pct_0_100 < 0) {
        volume_pct_0_100 = 0;
    }
    if (volume_pct_0_100 > 100) {
        volume_pct_0_100 = 100;
    }
    s_playback_vol_pct = volume_pct_0_100;
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
    esp_err_t err = driver_lmd2718_mic_read_pcm(s_pcm_buf, max_samples, &read_samples);
    if (err != ESP_OK) {
        return err;
    }

    for (size_t i = 0; i < read_samples; i++) {
        int32_t v = (int32_t)s_pcm_buf[i] >> 8;
        v += 128;
        if (v < 0) {
            v = 0;
        }
        if (v > 255) {
            v = 255;
        }
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
    if (len > 512) {
        len = 512;
    }
    const int vol = s_playback_vol_pct;
    for (size_t i = 0; i < len; i++) {
        int32_t u = (int32_t)data[i] - 128;
        int32_t s = u * 256;
        if (vol < 100) {
            s = (s * vol) / 100;
        }
        if (s > 32767) {
            s = 32767;
        }
        if (s < -32768) {
            s = -32768;
        }
        s_pcm_buf[i] = (int16_t)s;
    }
    esp_err_t err = ESP_ERR_INVALID_STATE;
    if (s_spk_mtx) {
        xSemaphoreTake(s_spk_mtx, portMAX_DELAY);
    }
    err = spk_write_pcm16_unlocked(s_pcm_buf, len);
    if (s_spk_mtx) {
        xSemaphoreGive(s_spk_mtx);
    }
    return err;
}

/**
 * MIC 软件增益（线性倍数）。LMD2718T PDM MEMS 在 64×CIC 抽取后输出的 s16 通常 peak ≈ 2k~4k，
 * Fun-ASR 在 peak < 5000 时识别准确率会明显下降。这里默认 6× 把正常说话拉到 ~12k~24k 区间，
 * 仍留一倍安全裕度避免削顶；若用户 PDM 板已自带高增益 mic，可改为 1。
 */
#ifndef HAL_AUDIO_MIC_GAIN_X
#define HAL_AUDIO_MIC_GAIN_X 6
#endif

esp_err_t hal_audio_record_pcm16(int16_t *samples, size_t max_samples, size_t *out_sample_count)
{
    if (samples == NULL || out_sample_count == NULL || max_samples == 0) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!s_audio_ready) {
        return ESP_ERR_INVALID_STATE;
    }
    size_t cap = max_samples > 512 ? 512 : max_samples;
    esp_err_t err = driver_lmd2718_mic_read_pcm(samples, cap, out_sample_count);
    if (err != ESP_OK) {
        return err;
    }
#if HAL_AUDIO_MIC_GAIN_X > 1
    const size_t n = *out_sample_count;
    for (size_t i = 0; i < n; i++) {
        int32_t v = (int32_t)samples[i] * HAL_AUDIO_MIC_GAIN_X;
        if (v > 32767) {
            v = 32767;
        } else if (v < -32768) {
            v = -32768;
        }
        samples[i] = (int16_t)v;
    }
#endif
    return ESP_OK;
}

esp_err_t hal_audio_play_pcm16(const int16_t *samples, size_t sample_count)
{
    if (samples == NULL || sample_count == 0) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!s_audio_ready) {
        return ESP_ERR_INVALID_STATE;
    }
    if (sample_count > 512) {
        sample_count = 512;
    }
    const int vol = s_playback_vol_pct;
    const int16_t *out = samples;
    if (vol <= 0) {
        memset(s_pcm_buf, 0, sample_count * sizeof(int16_t));
        out = s_pcm_buf;
    } else if (vol < 100) {
        for (size_t i = 0; i < sample_count; i++) {
            int32_t s = ((int32_t)samples[i] * vol) / 100;
            if (s > 32767) {
                s = 32767;
            }
            if (s < -32768) {
                s = -32768;
            }
            s_pcm_buf[i] = (int16_t)s;
        }
        out = s_pcm_buf;
    }
    esp_err_t err = ESP_ERR_INVALID_STATE;
    if (s_spk_mtx) {
        xSemaphoreTake(s_spk_mtx, portMAX_DELAY);
    }
    err = spk_write_pcm16_unlocked(out, sample_count);
    if (s_spk_mtx) {
        xSemaphoreGive(s_spk_mtx);
    }
    return err;
}

esp_err_t hal_audio_beep_volume_pct(int volume_pct_0_100)
{
    if (!s_audio_ready) {
        if (volume_pct_0_100 <= 0) {
            return ESP_OK;
        }
        if (volume_pct_0_100 > 100) {
            volume_pct_0_100 = 100;
        }
        uint32_t d = (uint32_t)HAL_AUDIO_UI_BEEP_MS;
        if (volume_pct_0_100 < 100) {
            d = (uint32_t)((uint64_t)HAL_AUDIO_UI_BEEP_MS * (uint32_t)volume_pct_0_100 / 100u);
            if (d < 20u) {
                d = 20u;
            }
        }
        return hal_interactive_beep(1, d);
    }
    if (volume_pct_0_100 <= 0) {
        return ESP_OK;
    }
    if (volume_pct_0_100 > 100) {
        volume_pct_0_100 = 100;
    }

    const uint32_t sr = HAL_AUDIO_SAMPLE_RATE_HZ;
    const size_t total = (size_t)(((uint64_t)sr * (uint32_t)HAL_AUDIO_UI_BEEP_MS) / 1000ULL);
    if (total == 0) {
        return ESP_OK;
    }

    const float w0 = 2.0f * 3.14159265f * (float)HAL_AUDIO_UI_BEEP_HZ / (float)sr;
    const float peak = 30000.0f * (float)volume_pct_0_100 / 100.0f;
    const float fade_len = 40.0f;

    int16_t buf[512];
    esp_err_t ret = ESP_OK;

    if (s_spk_mtx) {
        xSemaphoreTake(s_spk_mtx, portMAX_DELAY);
    }
    for (size_t off = 0; off < total && ret == ESP_OK;) {
        size_t chunk = total - off;
        if (chunk > 512) {
            chunk = 512;
        }
        for (size_t i = 0; i < chunk; i++) {
            const size_t gi = off + i;
            float s = sinf(w0 * (float)gi);
            float win = 1.0f;
            if ((float)total > fade_len * 2.1f) {
                if ((float)gi < fade_len) {
                    win = (float)gi / fade_len;
                } else if ((float)gi > (float)total - 1.f - fade_len) {
                    win = ((float)total - 1.f - (float)gi) / fade_len;
                }
            }
            float v = s * peak * win;
            if (v > 32767.0f) {
                v = 32767.0f;
            }
            if (v < -32768.0f) {
                v = -32768.0f;
            }
            buf[i] = (int16_t)v;
        }
        ret = spk_write_pcm16_unlocked(buf, chunk);
        off += chunk;
    }

    if (ret == ESP_OK) {
        const size_t tail_total = (size_t)(((uint64_t)sr * (uint32_t)HAL_AUDIO_UI_BEEP_TAIL_MS) / 1000ULL);
        for (size_t off = 0; off < tail_total && ret == ESP_OK;) {
            size_t chunk = tail_total - off;
            if (chunk > 512) {
                chunk = 512;
            }
            memset(buf, 0, chunk * sizeof(int16_t));
            ret = spk_write_pcm16_unlocked(buf, chunk);
            off += chunk;
        }
    }

    if (s_spk_mtx) {
        xSemaphoreGive(s_spk_mtx);
    }
    return ret;
}
