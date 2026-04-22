#pragma once

#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

void voice_session_init(const char *room_device_id,
                        volatile bool *network_ready,
                        volatile bool *on_call,
                        volatile bool *call_incoming_pending,
                        char *call_id_buffer,
                        size_t call_id_buffer_size);

esp_err_t voice_session_subscribe_downlink(void);

/** PTT 长按唤醒 Agent 后打开一段时间：按住 PTT 即上行 PCM（与电话互斥）。 */
void voice_session_arm_agent_window(uint32_t window_ms);

void voice_session_close_agent_window(void);

void voice_uplink_task(void *pvParameters);

void voice_downlink_mqtt_cb(const char *topic, const char *data, int data_len);

#ifdef __cplusplus
}
#endif
