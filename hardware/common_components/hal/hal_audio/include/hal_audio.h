#pragma once

#include <stdint.h>
#include <stddef.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 音频子系统初始化 (录音I2S与播音DAC)
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

#ifdef __cplusplus
}
#endif
