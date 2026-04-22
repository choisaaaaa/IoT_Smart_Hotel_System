#pragma once

#include <stdint.h>
#include <stddef.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 音频子系统初始化（客房默认 LMD02718：MEMS + NS4168，经 driver_lmd2718_mic / driver_ns4168）
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t hal_audio_init(void);

/**
 * @brief 开始录制一段 8kHz G.711 音频 (阻塞式采样或返回固定块大小)
 * @param buffer 用于存放录音数据的缓冲区
 * @param max_len 缓冲区最大长度
 * @param out_read_len 实际读取到的字节数
 * @return esp_err_t ESP_OK 读取成功
 */
esp_err_t hal_audio_record_chunk(uint8_t *buffer, size_t max_len, size_t *out_read_len);

/**
 * @brief 播放一段从后端接收到的 8kHz 音频流
 * @param data 音频数据流指针
 * @param len 音频数据长度
 * @return esp_err_t ESP_OK 投递给DAC播放成功
 */
esp_err_t hal_audio_play_chunk(const uint8_t *data, size_t len);

/** 16-bit PCM 直连 MEMS（与通话/Agent 上行一致），max_samples 建议 ≤512。 */
esp_err_t hal_audio_record_pcm16(int16_t *samples, size_t max_samples, size_t *out_sample_count);

/** 16-bit PCM 直连 NS4168（下行 TTS/对端语音），sample_count 建议 ≤512。 */
esp_err_t hal_audio_play_pcm16(const int16_t *samples, size_t sample_count);

/**
 * @brief 设置下行/通话等 PCM 播放的全局音量比例（0–100），与旋钮音量一致；默认 100。
 *        影响 hal_audio_play_pcm16、hal_audio_play_chunk；不影响 hal_audio_beep_volume_pct（其自带幅度参数）。
 */
void hal_audio_set_playback_volume_pct(int volume_pct_0_100);

/**
 * @brief 喇叭短提示音（约 1kHz 正弦），幅度按 volume_pct（0–100）线性缩放；0 为静音。
 *        与 hal_audio_play_pcm16 共用互斥，避免与语音下行交错。
 */
esp_err_t hal_audio_beep_volume_pct(int volume_pct_0_100);

#ifdef __cplusplus
}
#endif
