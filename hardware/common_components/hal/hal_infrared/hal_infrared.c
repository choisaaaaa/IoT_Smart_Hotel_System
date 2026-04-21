#include "hal_infrared.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_timer.h"
#include "driver_ir_tx.h"
#include "driver_ir_rx.h"
#include "global_config.h"

static const char *TAG = "HAL_INFRARED";
static bool s_ir_ready = false;

esp_err_t hal_infrared_init(void) {
    esp_err_t err = driver_ir_tx_init(GLOBAL_IR_TX_PIN);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "红外发射初始化失败: %s", esp_err_to_name(err));
        return err;
    }
    err = driver_ir_rx_init(GLOBAL_IR_RX_PIN);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "红外接收初始化失败: %s", esp_err_to_name(err));
        return err;
    }
    s_ir_ready = true;
    ESP_LOGI(TAG, "红外收发初始化完成 TX=%d RX=%d", GLOBAL_IR_TX_PIN, GLOBAL_IR_RX_PIN);
    return ESP_OK;
}

esp_err_t hal_infrared_send_ac_command(ir_brand_type_t brand, const ir_ac_cmd_t *cmd) {
    if (cmd == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!s_ir_ready) {
        return ESP_ERR_INVALID_STATE;
    }

    uint8_t addr = 0x00;
    switch (brand) {
        case IR_BRAND_GREE:  addr = 0x10; break;
        case IR_BRAND_MIDEA: addr = 0x20; break;
        case IR_BRAND_TV:    addr = 0x30; break;
        default:             addr = 0x00; break;
    }

    // 简化命令映射：bit7=电源，bit6..0=温度（16~30 映射）
    uint8_t temp = cmd->temperature;
    if (temp < 16) temp = 16;
    if (temp > 30) temp = 30;
    uint8_t cmd_byte = (cmd->power_on ? 0x80 : 0x00) | (uint8_t)(temp - 16);

    esp_err_t err = driver_ir_tx_send_nec(addr, cmd_byte);
    if (err == ESP_OK) {
        ESP_LOGI(TAG, "红外指令发送成功: brand=%d power=%d temp=%u", (int)brand, cmd->power_on ? 1 : 0, (unsigned)temp);
    }
    return err;
}

esp_err_t hal_infrared_learn_code(uint8_t *out_buffer, size_t max_len, uint32_t timeout_ms) {
    if (out_buffer == NULL || max_len < 2) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!s_ir_ready) {
        return ESP_ERR_INVALID_STATE;
    }

    int64_t start = esp_timer_get_time();
    while (((uint32_t)((esp_timer_get_time() - start) / 1000)) < timeout_ms) {
        uint8_t addr = 0;
        uint8_t cmd = 0;
        bool updated = false;
        esp_err_t err = driver_ir_rx_poll_nec(&addr, &cmd, &updated);
        if (err == ESP_OK && updated) {
            out_buffer[0] = addr;
            out_buffer[1] = cmd;
            ESP_LOGI(TAG, "红外学习成功: addr=0x%02X cmd=0x%02X", addr, cmd);
            return ESP_OK;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
    return ESP_ERR_TIMEOUT;
}
