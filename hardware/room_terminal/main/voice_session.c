#include "voice_session.h"
#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "cJSON.h"
#include "mbedtls/base64.h"
#include "hal_audio.h"
#include "hal_interactive.h"
#include "service_mqtt.h"
#include "global_config.h"
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/** TTS 下行 JSON：避免 cJSON_Parse 整包（~8KB+）在堆上建完整树导致 OOM，表现为「JSON 解析失败」与 seq 缺口 */
static const char *json_skip_ws(const char *p)
{
    if (p == NULL) {
        return NULL;
    }
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') {
        p++;
    }
    return p;
}

static const char *json_find_key_value_ptr(const char *json, const char *key)
{
    char pat[40];
    int n = snprintf(pat, sizeof(pat), "\"%s\"", key);
    if (n <= 0 || (size_t)n >= sizeof(pat)) {
        return NULL;
    }
    const char *p = strstr(json, pat);
    if (p == NULL) {
        return NULL;
    }
    p += strlen(pat);
    p = json_skip_ws(p);
    if (*p != ':') {
        return NULL;
    }
    p++;
    return json_skip_ws(p);
}

static bool json_read_string_value(const char *p, char *out, size_t cap)
{
    if (p == NULL || *p != '"') {
        return false;
    }
    p++;
    size_t i = 0;
    while (*p != '\0' && *p != '"') {
        if (*p == '\\') {
            p++;
            if (*p == '\0') {
                return false;
            }
        }
        if (i + 1 >= cap) {
            return false;
        }
        out[i++] = *p++;
    }
    if (*p != '"') {
        return false;
    }
    out[i] = '\0';
    return true;
}

static bool json_read_b64_span(const char *p, const char **start, size_t *out_len)
{
    if (p == NULL || *p != '"') {
        return false;
    }
    p++;
    *start = p;
    const char *end = strchr(p, '"');
    if (end == NULL) {
        return false;
    }
    *out_len = (size_t)(end - p);
    return true;
}

static bool json_read_u32(const char *p, uint32_t *out)
{
    if (p == NULL) {
        return false;
    }
    char *end = NULL;
    unsigned long v = strtoul(p, &end, 10);
    if (end == p) {
        return false;
    }
    *out = (uint32_t)v;
    return true;
}

static bool json_read_u64(const char *p, uint64_t *out)
{
    if (p == NULL) {
        return false;
    }
    char *end = NULL;
    unsigned long long v = strtoull(p, &end, 10);
    if (end == p) {
        return false;
    }
    *out = (uint64_t)v;
    return true;
}

static bool voice_downlink_parse_tts_json(const char *json,
                                          char *playback_id,
                                          size_t playback_id_cap,
                                          uint64_t *timestamp_ms,
                                          uint32_t *seq,
                                          uint32_t *total_seq,
                                          const char **pcm_b64_start,
                                          size_t *pcm_b64_len)
{
    const char *vf = json_find_key_value_ptr(json, "format");
    char fmt[24] = {0};
    if (vf == NULL || !json_read_string_value(vf, fmt, sizeof(fmt))) {
        return false;
    }
    if (strcmp(fmt, "pcm_s16le") != 0) {
        return false;
    }

    playback_id[0] = '\0';
    const char *vpb = json_find_key_value_ptr(json, "playback_id");
    if (vpb != NULL) {
        (void)json_read_string_value(vpb, playback_id, playback_id_cap);
    }

    *timestamp_ms = 0;
    const char *vts = json_find_key_value_ptr(json, "timestamp_ms");
    if (vts != NULL) {
        (void)json_read_u64(vts, timestamp_ms);
    }

    *seq = 0;
    const char *vsq = json_find_key_value_ptr(json, "seq");
    if (vsq != NULL) {
        (void)json_read_u32(vsq, seq);
    }

    *total_seq = 0;
    const char *vtot = json_find_key_value_ptr(json, "total_seq");
    if (vtot != NULL) {
        (void)json_read_u32(vtot, total_seq);
    }

    const char *vb = json_find_key_value_ptr(json, "pcm_base64");
    if (vb == NULL || !json_read_b64_span(vb, pcm_b64_start, pcm_b64_len)) {
        return false;
    }
    return true;
}

static const char *TAG = "VOICE_SESSION";

/** 单帧 PCM 样本数：512 @16k = 32ms，恰好对齐 I2S DMA 一次返回的最大块 */
#define PCM_CHUNK_MAX_SAMPLES    512
/**
 * 闲时轮询周期：仅在没有上行/通话时使用，节省 CPU。
 * 活跃上行不再额外 vTaskDelay：lmd02718_i2s_read 本身阻塞至 512 样本就绪 (~32ms)，
 * 它就是天然的 pacing —— 之前再叠 32ms 会让读循环周期变成 ~64ms，正好等于 DMA 总缓冲，
 * 网络稍卡就会丢一半采样，是「录音不稳/识别飘」的最大根因。
 */
#define VOICE_UPLINK_IDLE_MS     50
#define B64_BUF_SIZE             ((((PCM_CHUNK_MAX_SAMPLES) * 2 + 2) / 3) * 4 + 8)
#define DOWNLINK_PCM_MAX_BYTES   32768  /* 单包分段解码上限 */
/* 深度由 global_config 的 GLOBAL_VOICE_PLAY_QUEUE_DEPTH 配置（默认 128） */
/**
 * 下行入队：优先阻塞等待空槽，让已入队的段先被播放，避免「还没播就腾槽丢队头」。
 * 极长时间仍满才放弃本包（不 pop 队里已有未播段）。单位 ms。
 */
#ifndef VOICE_DOWNLINK_ENQUEUE_WAIT_MS
#define VOICE_DOWNLINK_ENQUEUE_WAIT_MS 8000u
#endif
/**
 * PTT 松手后再多读这些样本作为「尾巴」，捕获最后一个字 + 给 ASR 一个静音边界。
 * 240ms = 7~8 帧 32ms，刚好让用户「说完了」的口腔余响也被采到。
 */
#define UPLINK_TAIL_DRAIN_MS     240
#define UPLINK_TAIL_DRAIN_FRAMES (((UPLINK_TAIL_DRAIN_MS) * (int)GLOBAL_HAL_AUDIO_SAMPLE_RATE_HZ / 1000 + PCM_CHUNK_MAX_SAMPLES - 1) / PCM_CHUNK_MAX_SAMPLES)

typedef struct {
    size_t nbytes;
    uint8_t *pcm;
    uint64_t timestamp_ms;
    uint32_t seq;
    uint32_t total_seq;
    char playback_id[48];
} voice_play_item_t;

static QueueHandle_t s_play_q;
static char s_last_started_playback_id[48];
/** 新会话代际号：每次检测到新 playback_id(seq=1) 就递增，播放线程据此立即清场。 */
static volatile uint32_t s_downlink_generation = 0;
/** 每轮从播放队列批量取出后按时间戳排序，缓解网络抖动导致的乱序到达。 */
#define VOICE_PLAY_SORT_BATCH_MAX 24
#define VOICE_PLAY_PENDING_MAX 96
#define VOICE_REORDER_WAIT_MS 600u
#define VOICE_FINISHED_PLAYBACK_MAX 8
/* 新会话启动前先等一小段时间攒包，降低“边到边播”导致的尾字丢失/乱序跳播 */
#define VOICE_REORDER_PREFETCH_MS 360u

/**
 * 快速清空下行队列：单遍非阻塞出队，每出一段立即 free，无栈上指针表、无第二遍循环，清槽最省时间。
 * 释放顺序为队列 FIFO，与 heap 释放先后无关，功能上等价于原 LIFO 二遍释。
 */
void voice_session_discard_downlink_buffer(void)
{
    if (s_play_q == NULL) {
        return;
    }
    voice_play_item_t t;
    while (xQueueReceive(s_play_q, &t, 0) == pdTRUE) {
        free(t.pcm);
    }
}

/** 本块 PCM 等效时长外再拖一点，略慢于实时，入队快于播时队列空槽易回升。pace=1000 为关闭。 */
static void voice_playback_pace_delay_after_chunk(size_t samples_in_chunk)
{
#if (GLOBAL_VOICE_PLAY_PACE_PERMILLE) <= 1000u
    (void)samples_in_chunk;
    return;
#else
    const uint32_t sr = (uint32_t)GLOBAL_HAL_AUDIO_SAMPLE_RATE_HZ;
    if (sr == 0u || samples_in_chunk == 0) {
        return;
    }
    const uint32_t base_ms = (uint32_t)(((uint64_t)samples_in_chunk * 1000u) / (uint64_t)sr);
    const uint32_t num = (uint32_t)(GLOBAL_VOICE_PLAY_PACE_PERMILLE - 1000u);
    const uint32_t extra_ms = (base_ms * num) / 1000u;
    if (extra_ms == 0) {
        return;
    }
    vTaskDelay(pdMS_TO_TICKS(extra_ms));
#endif
}

static bool same_playback_id(const char *a, const char *b)
{
    if (a == NULL || b == NULL) {
        return false;
    }
    return strncmp(a, b, sizeof(((voice_play_item_t *)0)->playback_id)) == 0;
}

static void clear_pending_items(voice_play_item_t *pending, size_t *pending_cnt)
{
    if (pending == NULL || pending_cnt == NULL) {
        return;
    }
    for (size_t i = 0; i < *pending_cnt; i++) {
        free(pending[i].pcm);
    }
    *pending_cnt = 0;
}

static void play_one_item(const voice_play_item_t *it, uint32_t generation_snapshot)
{
    if (it == NULL || it->pcm == NULL || it->nbytes < sizeof(int16_t) || (it->nbytes % sizeof(int16_t)) != 0) {
        return;
    }
    const int16_t *pcm = (const int16_t *)it->pcm;
    size_t samples = it->nbytes / sizeof(int16_t);
    size_t off = 0;
    while (off < samples) {
        size_t chunk = samples - off;
        if (chunk > PCM_CHUNK_MAX_SAMPLES) {
            chunk = PCM_CHUNK_MAX_SAMPLES;
        }
        if (s_downlink_generation != generation_snapshot) {
            ESP_LOGW(TAG, "播放中检测到新会话，立即中断旧分片 pb=%s seq=%u/%u",
                     it->playback_id, (unsigned)it->seq, (unsigned)it->total_seq);
            break;
        }
        esp_err_t e = hal_audio_play_pcm16(pcm + off, chunk);
        if (e != ESP_OK) {
            ESP_LOGW(TAG, "下行播放失败 off=%u: %s", (unsigned)off, esp_err_to_name(e));
            break;
        }
        voice_playback_pace_delay_after_chunk(chunk);
        off += chunk;
    }
    ESP_LOGD(TAG, "下行播放完成 %u samples ts=%llu pb=%s seq=%u/%u",
             (unsigned)samples, (unsigned long long)it->timestamp_ms, it->playback_id, (unsigned)it->seq, (unsigned)it->total_seq);
}

static void voice_playback_task(void *arg)
{
    (void)arg;
    voice_play_item_t pending[VOICE_PLAY_PENDING_MAX];
    size_t pending_cnt = 0;
    char active_playback_id[48] = {0};
    uint32_t expected_seq = 1;
    uint32_t active_total_seq = 0;
    TickType_t wait_start_tick = 0;
    char finished_playback_ids[VOICE_FINISHED_PLAYBACK_MAX][48] = {{0}};
    size_t finished_cnt = 0;
    uint32_t observed_generation = s_downlink_generation;
    for (;;) {
        voice_play_item_t item;
        if (xQueueReceive(s_play_q, &item, portMAX_DELAY) != pdTRUE) {
            continue;
        }
        if (observed_generation != s_downlink_generation) {
            clear_pending_items(pending, &pending_cnt);
            active_playback_id[0] = '\0';
            expected_seq = 1;
            active_total_seq = 0;
            wait_start_tick = 0;
            finished_cnt = 0;
            observed_generation = s_downlink_generation;
        }

        // 已结束会话的迟到包直接丢弃，避免“句尾回跳到句首”
        bool already_finished = false;
        for (size_t i = 0; i < finished_cnt; i++) {
            if (same_playback_id(item.playback_id, finished_playback_ids[i])) {
                already_finished = true;
                break;
            }
        }
        if (already_finished) {
            ESP_LOGW(TAG, "丢弃已结束会话的迟到分片 pb=%s seq=%u/%u",
                     item.playback_id, (unsigned)item.seq, (unsigned)item.total_seq);
            free(item.pcm);
            continue;
        }

        if (pending_cnt >= VOICE_PLAY_PENDING_MAX) {
            ESP_LOGW(TAG, "重排缓冲已满，丢弃最旧片段");
            free(pending[0].pcm);
            memmove(&pending[0], &pending[1], (VOICE_PLAY_PENDING_MAX - 1) * sizeof(voice_play_item_t));
            pending_cnt = VOICE_PLAY_PENDING_MAX - 1;
        }
        pending[pending_cnt++] = item;

        // 尝试尽可能严格按 playback_id + seq 输出
        for (;;) {
            if (observed_generation != s_downlink_generation) {
                clear_pending_items(pending, &pending_cnt);
                active_playback_id[0] = '\0';
                expected_seq = 1;
                active_total_seq = 0;
                wait_start_tick = 0;
                finished_cnt = 0;
                observed_generation = s_downlink_generation;
                break;
            }
            if (pending_cnt == 0) {
                active_playback_id[0] = '\0';
                expected_seq = 1;
                active_total_seq = 0;
                wait_start_tick = 0;
                break;
            }

            // 选择活动会话：优先最早时间戳的分片
            if (active_playback_id[0] == '\0') {
                vTaskDelay(pdMS_TO_TICKS(VOICE_REORDER_PREFETCH_MS));
                // 预取窗口期间继续把已到达分片拿进 pending，避免刚起播就缺片
                while (pending_cnt < VOICE_PLAY_PENDING_MAX &&
                       xQueueReceive(s_play_q, &item, 0) == pdTRUE) {
                    bool already_finished2 = false;
                    for (size_t k = 0; k < finished_cnt; k++) {
                        if (same_playback_id(item.playback_id, finished_playback_ids[k])) {
                            already_finished2 = true;
                            break;
                        }
                    }
                    if (already_finished2) {
                        free(item.pcm);
                        continue;
                    }
                    pending[pending_cnt++] = item;
                }

                size_t pick = 0;
                for (size_t i = 1; i < pending_cnt; i++) {
                    if (pending[i].timestamp_ms < pending[pick].timestamp_ms) {
                        pick = i;
                    }
                }
                strncpy(active_playback_id, pending[pick].playback_id, sizeof(active_playback_id) - 1);
                active_playback_id[sizeof(active_playback_id) - 1] = '\0';
                expected_seq = 1;
                active_total_seq = pending[pick].total_seq;
                wait_start_tick = xTaskGetTickCount();
            }

            int exact_idx = -1;
            int next_idx = -1;
            for (size_t i = 0; i < pending_cnt; i++) {
                if (!same_playback_id(pending[i].playback_id, active_playback_id)) {
                    continue;
                }
                // 丢弃已过期分片（迟到的小 seq）
                if (pending[i].seq > 0 && pending[i].seq < expected_seq) {
                    ESP_LOGW(TAG, "丢弃过期分片 pb=%s seq=%u 期望>=%u",
                             active_playback_id, (unsigned)pending[i].seq, (unsigned)expected_seq);
                    free(pending[i].pcm);
                    memmove(&pending[i], &pending[i + 1], (pending_cnt - i - 1) * sizeof(voice_play_item_t));
                    pending_cnt--;
                    i--;
                    continue;
                }
                if (pending[i].seq == expected_seq) {
                    exact_idx = (int)i;
                    break;
                }
                if (pending[i].seq > expected_seq) {
                    if (next_idx < 0 || pending[i].seq < pending[(size_t)next_idx].seq) {
                        next_idx = (int)i;
                    }
                }
            }

            if (exact_idx >= 0) {
                voice_play_item_t out = pending[(size_t)exact_idx];
                memmove(&pending[(size_t)exact_idx], &pending[(size_t)exact_idx + 1], (pending_cnt - (size_t)exact_idx - 1) * sizeof(voice_play_item_t));
                pending_cnt--;
                play_one_item(&out, observed_generation);
                free(out.pcm);
                expected_seq++;
                wait_start_tick = xTaskGetTickCount();
                if (active_total_seq > 0 && expected_seq > active_total_seq) {
                    if (active_playback_id[0] != '\0') {
                        if (finished_cnt < VOICE_FINISHED_PLAYBACK_MAX) {
                            strncpy(finished_playback_ids[finished_cnt], active_playback_id, sizeof(finished_playback_ids[finished_cnt]) - 1);
                            finished_playback_ids[finished_cnt][sizeof(finished_playback_ids[finished_cnt]) - 1] = '\0';
                            finished_cnt++;
                        } else {
                            memmove(&finished_playback_ids[0], &finished_playback_ids[1], (VOICE_FINISHED_PLAYBACK_MAX - 1) * sizeof(finished_playback_ids[0]));
                            strncpy(finished_playback_ids[VOICE_FINISHED_PLAYBACK_MAX - 1], active_playback_id, sizeof(finished_playback_ids[0]) - 1);
                            finished_playback_ids[VOICE_FINISHED_PLAYBACK_MAX - 1][sizeof(finished_playback_ids[0]) - 1] = '\0';
                        }
                    }
                    active_playback_id[0] = '\0';
                    expected_seq = 1;
                    active_total_seq = 0;
                }
                continue;
            }

            if (next_idx >= 0) {
                TickType_t now = xTaskGetTickCount();
                if (wait_start_tick == 0) {
                    wait_start_tick = now;
                }
                if ((now - wait_start_tick) < pdMS_TO_TICKS(VOICE_REORDER_WAIT_MS)) {
                    // 继续收包等待缺失 seq
                    break;
                }
                voice_play_item_t out = pending[(size_t)next_idx];
                ESP_LOGW(TAG, "严格排序超时，跳过缺失 seq，播放 seq=%u 期望=%u pb=%s",
                         (unsigned)out.seq, (unsigned)expected_seq, active_playback_id);
                memmove(&pending[(size_t)next_idx], &pending[(size_t)next_idx + 1], (pending_cnt - (size_t)next_idx - 1) * sizeof(voice_play_item_t));
                pending_cnt--;
                play_one_item(&out, observed_generation);
                free(out.pcm);
                expected_seq = out.seq + 1;
                wait_start_tick = xTaskGetTickCount();
                if (active_total_seq > 0 && expected_seq > active_total_seq) {
                    if (active_playback_id[0] != '\0') {
                        if (finished_cnt < VOICE_FINISHED_PLAYBACK_MAX) {
                            strncpy(finished_playback_ids[finished_cnt], active_playback_id, sizeof(finished_playback_ids[finished_cnt]) - 1);
                            finished_playback_ids[finished_cnt][sizeof(finished_playback_ids[finished_cnt]) - 1] = '\0';
                            finished_cnt++;
                        } else {
                            memmove(&finished_playback_ids[0], &finished_playback_ids[1], (VOICE_FINISHED_PLAYBACK_MAX - 1) * sizeof(finished_playback_ids[0]));
                            strncpy(finished_playback_ids[VOICE_FINISHED_PLAYBACK_MAX - 1], active_playback_id, sizeof(finished_playback_ids[0]) - 1);
                            finished_playback_ids[VOICE_FINISHED_PLAYBACK_MAX - 1][sizeof(finished_playback_ids[0]) - 1] = '\0';
                        }
                    }
                    active_playback_id[0] = '\0';
                    expected_seq = 1;
                    active_total_seq = 0;
                }
                continue;
            }

            // 活跃会话已无可播片段，切到新会话
            active_playback_id[0] = '\0';
            expected_seq = 1;
            active_total_seq = 0;
            wait_start_tick = 0;
        }
    }
}

static char s_device_id[40];
static volatile bool *s_net_ok;
static volatile bool *s_on_call;
static volatile bool *s_call_incoming;
static char *s_call_id;
static size_t s_call_id_cap;

static bool s_agent_window_active;
static TickType_t s_agent_window_end;
static uint32_t s_uplink_seq;
static bool s_ptt_prev;
/** 本轮按住 PTT 是否已成功发出过至少一帧 Agent PCM（松开时据此决定是否发 eos） */
static bool s_agent_had_pcm_this_ptt;

/** 普通控制类（eos 等）依旧 QoS 1：保证可靠送达 */
static esp_err_t publish_uplink_json(const char *topic, cJSON *root)
{
    char *json = cJSON_PrintUnformatted(root);
    if (json == NULL) {
        return ESP_ERR_NO_MEM;
    }
    esp_err_t err = service_mqtt_publish_silent(topic, json);
    free(json);
    return err;
}

/** 高频音频 PCM 包：QoS 0 直发，避免 ACK 排队拖垮上行节奏 */
static esp_err_t publish_uplink_audio_json(const char *topic, cJSON *root)
{
    char *json = cJSON_PrintUnformatted(root);
    if (json == NULL) {
        return ESP_ERR_NO_MEM;
    }
    esp_err_t err = service_mqtt_publish_audio(topic, json);
    free(json);
    return err;
}

static void publish_agent_eos(void)
{
    if (!s_net_ok || !*s_net_ok) {
        return;
    }
    char topic[128];
    snprintf(topic, sizeof(topic), "%s/%s", GLOBAL_TOPIC_DEVICE_AUDIO_UPLINK_PREFIX, s_device_id);

    cJSON *root = cJSON_CreateObject();
    if (root == NULL) {
        return;
    }
    cJSON_AddStringToObject(root, "device_id", s_device_id);
    cJSON_AddStringToObject(root, "session", "agent");
    cJSON_AddBoolToObject(root, "eos", true);
    cJSON_AddNumberToObject(root, "seq", (double)++s_uplink_seq);
    cJSON_AddNumberToObject(root, "sample_rate", (double)GLOBAL_HAL_AUDIO_SAMPLE_RATE_HZ);
    if (publish_uplink_json(topic, root) == ESP_OK) {
        ESP_LOGI(TAG, "Agent 上行: 句末 eos");
    }
    cJSON_Delete(root);
}

static void publish_call_uplink_pcm(const int16_t *pcm, size_t n_samples)
{
    if (!s_net_ok || !*s_net_ok || s_call_id == NULL) {
        return;
    }
    unsigned char b64[B64_BUF_SIZE];
    size_t olen = 0;
    int br = mbedtls_base64_encode(b64, sizeof(b64) - 1, &olen,
                                   (const unsigned char *)pcm, n_samples * sizeof(int16_t));
    if (br != 0) {
        ESP_LOGW(TAG, "base64 encode fail: %d", br);
        return;
    }
    b64[olen] = '\0';

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/%s", GLOBAL_TOPIC_DEVICE_AUDIO_UPLINK_PREFIX, s_device_id);

    cJSON *root = cJSON_CreateObject();
    if (root == NULL) {
        return;
    }
    cJSON_AddStringToObject(root, "device_id", s_device_id);
    cJSON_AddStringToObject(root, "session", "call");
    cJSON_AddStringToObject(root, "call_id", s_call_id[0] ? s_call_id : "");
    cJSON_AddNumberToObject(root, "seq", (double)++s_uplink_seq);
    cJSON_AddStringToObject(root, "format", "pcm_s16le");
    cJSON_AddNumberToObject(root, "sample_rate", (double)GLOBAL_HAL_AUDIO_SAMPLE_RATE_HZ);
    cJSON_AddStringToObject(root, "pcm_base64", (const char *)b64);
    if (publish_uplink_audio_json(topic, root) != ESP_OK) {
        ESP_LOGD(TAG, "call uplink publish skip/err");
    }
    cJSON_Delete(root);
}

static bool publish_agent_uplink_pcm(const int16_t *pcm, size_t n_samples)
{
    if (!s_net_ok || !*s_net_ok) {
        return false;
    }
    unsigned char b64[B64_BUF_SIZE];
    size_t olen = 0;
    int br = mbedtls_base64_encode(b64, sizeof(b64) - 1, &olen,
                                   (const unsigned char *)pcm, n_samples * sizeof(int16_t));
    if (br != 0) {
        ESP_LOGW(TAG, "agent uplink base64 encode fail: %d", br);
        return false;
    }
    b64[olen] = '\0';

    char topic[128];
    snprintf(topic, sizeof(topic), "%s/%s", GLOBAL_TOPIC_DEVICE_AUDIO_UPLINK_PREFIX, s_device_id);

    cJSON *root = cJSON_CreateObject();
    if (root == NULL) {
        return false;
    }
    cJSON_AddStringToObject(root, "device_id", s_device_id);
    cJSON_AddStringToObject(root, "session", "agent");
    cJSON_AddNumberToObject(root, "seq", (double)++s_uplink_seq);
    cJSON_AddStringToObject(root, "format", "pcm_s16le");
    cJSON_AddNumberToObject(root, "sample_rate", (double)GLOBAL_HAL_AUDIO_SAMPLE_RATE_HZ);
    cJSON_AddStringToObject(root, "pcm_base64", (const char *)b64);
    if (publish_uplink_audio_json(topic, root) != ESP_OK) {
        ESP_LOGD(TAG, "agent uplink publish skip/err");
        cJSON_Delete(root);
        return false;
    }
    cJSON_Delete(root);
    return true;
}

void voice_session_init(const char *room_device_id,
                        volatile bool *network_ready,
                        volatile bool *on_call,
                        volatile bool *call_incoming_pending,
                        char *call_id_buffer,
                        size_t call_id_buffer_size)
{
    memset(s_device_id, 0, sizeof(s_device_id));
    if (room_device_id != NULL) {
        strncpy(s_device_id, room_device_id, sizeof(s_device_id) - 1);
    }
    s_net_ok = network_ready;
    s_on_call = on_call;
    s_call_incoming = call_incoming_pending;
    s_call_id = call_id_buffer;
    s_call_id_cap = call_id_buffer_size;
    s_agent_window_active = false;
    s_agent_window_end = 0;
    s_uplink_seq = 0;
    s_ptt_prev = false;
    s_agent_had_pcm_this_ptt = false;
    memset(s_last_started_playback_id, 0, sizeof(s_last_started_playback_id));
    s_downlink_generation = 0;
    (void)s_call_id_cap;

    if (s_play_q == NULL) {
        s_play_q = xQueueCreate((UBaseType_t)GLOBAL_VOICE_PLAY_QUEUE_DEPTH, sizeof(voice_play_item_t));
        if (s_play_q == NULL) {
            ESP_LOGE(TAG, "播放队列创建失败");
        } else if (xTaskCreate(voice_playback_task, "voice_play", 8192, NULL, 6, NULL) != pdPASS) {
            ESP_LOGE(TAG, "voice_play 任务创建失败");
        }
    }
}

esp_err_t voice_session_subscribe_downlink(void)
{
    char topic[128];
    snprintf(topic, sizeof(topic), "%s/%s", GLOBAL_TOPIC_DEVICE_AUDIO_DOWNLINK_PREFIX, s_device_id);
    return service_mqtt_subscribe(topic, voice_downlink_mqtt_cb);
}

void voice_session_arm_agent_window(uint32_t window_ms)
{
    /* 不再在此处清空下行队列，避免「助理还在播上一轮、用户又打开窗口」时把未播段清光 */
    TickType_t now = xTaskGetTickCount();
    s_agent_window_end = now + pdMS_TO_TICKS(window_ms);
    s_agent_window_active = true;
    s_agent_had_pcm_this_ptt = false;
    ESP_LOGI(TAG, "Agent 语音窗口已打开 %lu ms（按住 PTT 上行）", (unsigned long)window_ms);
}

void voice_session_close_agent_window(void)
{
    s_agent_window_active = false;
    s_agent_window_end = 0;
    s_agent_had_pcm_this_ptt = false;
    ESP_LOGI(TAG, "Agent 语音窗口已关闭");
}

void voice_downlink_mqtt_cb(const char *topic, const char *data, int data_len)
{
    (void)topic;
    if (s_play_q == NULL) {
        ESP_LOGW(TAG, "下行丢弃: 播放队列未初始化");
        return;
    }
    char *json_str = (char *)malloc(data_len + 1);
    if (!json_str) {
        ESP_LOGE(TAG, "下行 OOM 无法分配 json 字符串");
        return;
    }
    memcpy(json_str, data, data_len);
    json_str[data_len] = '\0';

    char playbackId[48] = {0};
    uint64_t tsFromJson = 0;
    uint32_t seq = 0;
    uint32_t totalSeq = 0;
    const char *b64_start = NULL;
    size_t b64_len = 0;
    if (!voice_downlink_parse_tts_json(json_str, playbackId, sizeof(playbackId), &tsFromJson, &seq, &totalSeq,
                                       &b64_start, &b64_len)) {
        ESP_LOGW(TAG, "下行 TTS JSON 轻量解析失败 len=%d heap=%u", data_len, (unsigned)esp_get_free_heap_size());
        free(json_str);
        return;
    }

    if (playbackId[0] == '\0') {
        strncpy(playbackId, "legacy", sizeof(playbackId) - 1);
    }
    uint64_t tsMs = (uint64_t)xTaskGetTickCount() * portTICK_PERIOD_MS;
    if (tsFromJson > 0) {
        tsMs = tsFromJson;
    }
    if (seq == 1 &&
        playbackId[0] != '\0' &&
        strncmp(playbackId, "legacy", sizeof(playbackId)) != 0 &&
        strncmp(playbackId, s_last_started_playback_id, sizeof(s_last_started_playback_id)) != 0) {
        s_downlink_generation++;
        ESP_LOGW(TAG, "检测到新对话会话，清空旧残留: old=%s new=%s",
                 s_last_started_playback_id[0] ? s_last_started_playback_id : "(none)",
                 playbackId);
        voice_session_discard_downlink_buffer();
        strncpy(s_last_started_playback_id, playbackId, sizeof(s_last_started_playback_id) - 1);
        s_last_started_playback_id[sizeof(s_last_started_playback_id) - 1] = '\0';
    }
    const size_t alloc_bytes = (b64_len / 4) * 3 + 3;
    if (alloc_bytes > DOWNLINK_PCM_MAX_BYTES) {
        ESP_LOGW(TAG, "下行 PCM 过大: 预计 %u 字节 > 上限 %d，已丢弃",
                 (unsigned)alloc_bytes, DOWNLINK_PCM_MAX_BYTES);
        free(json_str);
        return;
    }

    uint8_t *raw = (uint8_t *)malloc(alloc_bytes);
    if (raw == NULL) {
        ESP_LOGE(TAG, "下行解码缓冲分配失败 need=%u", (unsigned)alloc_bytes);
        free(json_str);
        return;
    }
    size_t raw_len = 0;
    int dr = mbedtls_base64_decode(raw, alloc_bytes, &raw_len, (const unsigned char *)b64_start, b64_len);
    free(json_str);
    if (dr != 0 || raw_len < sizeof(int16_t) || (raw_len % sizeof(int16_t)) != 0) {
        ESP_LOGW(TAG, "下行 base64 解码失败 dr=%d len=%u", dr, (unsigned)raw_len);
        free(raw);
        return;
    }

    voice_play_item_t item = {
        .nbytes = raw_len,
        .pcm = raw,
        .timestamp_ms = tsMs,
        .seq = seq,
        .total_seq = totalSeq
    };
    strncpy(item.playback_id, playbackId, sizeof(item.playback_id) - 1);
    /* 等播任务吃队列、腾出槽再入队；不 pop 队头，避免未播先丢。超时只丢本网络包。 */
    if (xQueueSend(s_play_q, &item, pdMS_TO_TICKS(VOICE_DOWNLINK_ENQUEUE_WAIT_MS)) != pdTRUE) {
        ESP_LOGW(TAG, "下行队列 %ums 内仍无空槽，丢弃本包 %u bytes（已排队段保留）", (unsigned)VOICE_DOWNLINK_ENQUEUE_WAIT_MS, (unsigned)raw_len);
        free(raw);
        return;
    }
    ESP_LOGD(TAG, "下行分段已入队 %u bytes", (unsigned)raw_len);
}

void voice_uplink_task(void *pvParameters)
{
    (void)pvParameters;
    ESP_LOGI(TAG, "语音上行任务启动（通话：连续上行；Agent：窗口内按住 PTT 上行，松开发 eos）");
    int16_t pcm[PCM_CHUNK_MAX_SAMPLES];

    while (1) {
        TickType_t now = xTaskGetTickCount();
        if (s_agent_window_active && s_agent_window_end != 0 && now >= s_agent_window_end) {
            s_agent_window_active = false;
            ESP_LOGI(TAG, "Agent 语音窗口超时结束");
        }

        bool ptt = hal_interactive_is_button_pressed(BTN_ROOM_PTT);
        bool net = (s_net_ok != NULL && *s_net_ok);
        bool on_call = (s_on_call != NULL && *s_on_call);
        bool incoming = (s_call_incoming != NULL && *s_call_incoming);

        if (!s_ptt_prev && ptt && s_agent_window_active && !on_call && !incoming && net) {
            s_agent_had_pcm_this_ptt = false;
        }

        bool agent_uplink = s_agent_window_active && ptt && !on_call && !incoming && net;

        if (on_call && net) {
            size_t n = 0;
            if (hal_audio_record_pcm16(pcm, PCM_CHUNK_MAX_SAMPLES, &n) == ESP_OK && n > 0) {
                publish_call_uplink_pcm(pcm, n);
            }
        } else if (agent_uplink) {
            size_t n = 0;
            if (hal_audio_record_pcm16(pcm, PCM_CHUNK_MAX_SAMPLES, &n) == ESP_OK && n > 0) {
                /* 每秒打印一次麦克风电平，快速判断 MEMS 是否采到有效信号 */
                static TickType_t s_last_lvl_log = 0;
                static int32_t s_lvl_peak = 0;
                static uint32_t s_lvl_abs_sum = 0;
                static uint32_t s_lvl_count = 0;
                for (size_t i = 0; i < n; i++) {
                    int32_t v = pcm[i];
                    int32_t a = v < 0 ? -v : v;
                    if (a > s_lvl_peak) {
                        s_lvl_peak = a;
                    }
                    s_lvl_abs_sum += (uint32_t)a;
                    s_lvl_count++;
                }
                TickType_t tnow = xTaskGetTickCount();
                if (tnow - s_last_lvl_log >= pdMS_TO_TICKS(1000) && s_lvl_count > 0) {
                    uint32_t avg_abs = s_lvl_abs_sum / s_lvl_count;
                    ESP_LOGI(TAG,
                             "MIC 电平: peak=%d avg_abs=%u samples=%u（安静应接近 0，正常说话 peak 建议 > 3000）",
                             (int)s_lvl_peak, (unsigned)avg_abs, (unsigned)s_lvl_count);
                    s_last_lvl_log = tnow;
                    s_lvl_peak = 0;
                    s_lvl_abs_sum = 0;
                    s_lvl_count = 0;
                }
                if (publish_agent_uplink_pcm(pcm, n)) {
                    s_agent_had_pcm_this_ptt = true;
                }
            }
        }

        if (s_ptt_prev && !ptt && s_agent_window_active && !on_call && !incoming && net) {
            /* PTT 松开后，再吸 240ms 「尾巴」一起发上去：
             *   - 用户说完最后一个字到松手通常还有 ~150~250ms 余响；
             *   - 让 ASR 看到一个明确的安静尾，避免把最后一字截断；
             *   - 这里直接复用同一缓冲，每帧调用 publish_agent_uplink_pcm。 */
            for (int i = 0; i < UPLINK_TAIL_DRAIN_FRAMES; i++) {
                size_t n = 0;
                if (hal_audio_record_pcm16(pcm, PCM_CHUNK_MAX_SAMPLES, &n) != ESP_OK || n == 0) {
                    break;
                }
                if (publish_agent_uplink_pcm(pcm, n)) {
                    s_agent_had_pcm_this_ptt = true;
                }
            }
            if (s_agent_had_pcm_this_ptt) {
                publish_agent_eos();
            }
            s_agent_had_pcm_this_ptt = false;
        }
        s_ptt_prev = ptt;

        /* 活跃上行不再 sleep：hal_audio_record_pcm16 内部会阻塞到一帧 (~32ms) 就绪，
         * 这就是天然 pacing；再叠 vTaskDelay 会把读循环周期拉到 64ms+，刚好等于 DMA 总缓冲，
         * 网络稍卡就会丢一半采样，是「录音不稳/识别飘」的最大根因。 */
        if (!((on_call && net) || agent_uplink)) {
            vTaskDelay(pdMS_TO_TICKS(VOICE_UPLINK_IDLE_MS));
        }
    }
}
