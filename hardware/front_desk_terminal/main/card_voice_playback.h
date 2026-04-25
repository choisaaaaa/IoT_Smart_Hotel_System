#pragma once

#include <stdint.h>

/**
 * 客房刷卡语音提示（需 main/ 下放置 welcome_card.pcm、invalid_card.pcm，见 tools/gen_card_voice_pcm.py）
 * 格式：16kHz 单声道 s16le 原始 PCM；无文件时回退为蜂鸣组合。
 */
void card_voice_play_welcome(int volume_pct_0_100);
void card_voice_play_invalid(int volume_pct_0_100);
