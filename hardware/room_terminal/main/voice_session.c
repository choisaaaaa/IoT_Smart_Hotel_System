#include "voice_session.h"
#include "esp_log.h"
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
} voice_play_item_t;

static QueueHandle_t s_play_q;

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

static void voice_playback_task(void *arg)
{
    (void)arg;
    voice_play_item_t it;
    for (;;) {
        if (xQueueReceive(s_play_q, &it, portMAX_DELAY) != pdTRUE) {
            continue;
        }
        if (it.pcm == NULL || it.nbytes < sizeof(int16_t) || (it.nbytes % sizeof(int16_t)) != 0) {
            free(it.pcm);
            continue;
        }
#if (GLOBAL_VOICE_PLAY_JITTER_PREFILL_MS) > 0u
        /* 仅手上一段、队里无下一段时：先睡一会再播，与后端首包微错开，抗到达抖动 */
        if (uxQueueMessagesWaiting(s_play_q) == 0) {
            vTaskDelay(pdMS_TO_TICKS(GLOBAL_VOICE_PLAY_JITTER_PREFILL_MS));
        }
#endif
        const int16_t *pcm = (const int16_t *)it.pcm;
        size_t samples = it.nbytes / sizeof(int16_t);
        size_t off = 0;
        while (off < samples) {
            size_t chunk = samples - off;
            if (chunk > PCM_CHUNK_MAX_SAMPLES) {
                chunk = PCM_CHUNK_MAX_SAMPLES;
            }
            esp_err_t e = hal_audio_play_pcm16(pcm + off, chunk);
            if (e != ESP_OK) {
                ESP_LOGW(TAG, "下行播放失败 off=%u: %s", (unsigned)off, esp_err_to_name(e));
                break;
            }
            voice_playback_pace_delay_after_chunk(chunk);
            off += chunk;
        }
        ESP_LOGD(TAG, "下行播放完成 %u samples", (unsigned)samples);
        free(it.pcm);
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

    cJSON *root = cJSON_Parse(json_str);
    free(json_str);

    if (root == NULL) {
        ESP_LOGW(TAG, "下行 JSON 解析失败 len=%d", data_len);
        return;
    }
    cJSON *fmt = cJSON_GetObjectItem(root, "format");
    if (!cJSON_IsString(fmt) || strcmp(fmt->valuestring, "pcm_s16le") != 0) {
        ESP_LOGW(TAG, "下行 format 非 pcm_s16le");
        cJSON_Delete(root);
        return;
    }
    cJSON *b64item = cJSON_GetObjectItem(root, "pcm_base64");
    if (!cJSON_IsString(b64item) || b64item->valuestring == NULL) {
        cJSON_Delete(root);
        return;
    }
    const char *b64str = b64item->valuestring;
    const size_t b64_len = strlen(b64str);
    const size_t alloc_bytes = (b64_len / 4) * 3 + 3;
    if (alloc_bytes > DOWNLINK_PCM_MAX_BYTES) {
        ESP_LOGW(TAG, "下行 PCM 过大: 预计 %u 字节 > 上限 %d，已丢弃",
                 (unsigned)alloc_bytes, DOWNLINK_PCM_MAX_BYTES);
        cJSON_Delete(root);
        return;
    }
    cJSON_Delete(root);

    uint8_t *raw = (uint8_t *)malloc(alloc_bytes);
    if (raw == NULL) {
        ESP_LOGE(TAG, "下行解码缓冲分配失败 need=%u", (unsigned)alloc_bytes);
        return;
    }
    size_t raw_len = 0;
    int dr = mbedtls_base64_decode(raw, alloc_bytes, &raw_len, (const unsigned char *)b64str, b64_len);
    if (dr != 0 || raw_len < sizeof(int16_t) || (raw_len % sizeof(int16_t)) != 0) {
        ESP_LOGW(TAG, "下行 base64 解码失败 dr=%d len=%u", dr, (unsigned)raw_len);
        free(raw);
        return;
    }

    voice_play_item_t item = {.nbytes = raw_len, .pcm = raw};
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
