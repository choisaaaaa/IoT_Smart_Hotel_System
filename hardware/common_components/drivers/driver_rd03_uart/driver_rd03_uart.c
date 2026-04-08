#include "driver_rd03_uart.h"
#include "hal_log.h"
#include "driver/uart.h"
#include <string.h>

static const char *TAG = "RD03_UART";

#define RD03_RX_BUF 512

static uart_port_t s_port;
static bool s_uart_ready;
static uint8_t s_acc[RD03_RX_BUF];
static size_t s_acc_len;

static bool match_hdr(const uint8_t *p, uint8_t a, uint8_t b, uint8_t c, uint8_t d)
{
    return p[0] == a && p[1] == b && p[2] == c && p[3] == d;
}

static bool try_take_frame(size_t i, uint16_t payload_len, size_t *out_consume, bool *out_present)
{
    if (payload_len < 1) {
        return false;
    }
    size_t need = 4 + 2 + payload_len;
    if (i + need > s_acc_len) {
        return false;
    }
    *out_present = (s_acc[i + 6] != 0);
    *out_consume = need;
    return true;
}

static bool scan_one(bool *out_present, size_t *out_offset, size_t *out_len)
{
    for (size_t i = 0; i + 6 < s_acc_len; i++) {
        uint16_t plen;
        size_t consume = 0;
        if (match_hdr(s_acc + i, 0xF4, 0xF3, 0xF2, 0xF1) ||
            match_hdr(s_acc + i, 0xF8, 0xF7, 0xF6, 0xF5)) {
            plen = (uint16_t)s_acc[i + 4] | ((uint16_t)s_acc[i + 5] << 8);
            if (plen == 0 || plen > 200) {
                continue;
            }
            if (try_take_frame(i, plen, &consume, out_present)) {
                *out_offset = i;
                *out_len = consume;
                return true;
            }
        }
    }
    return false;
}

esp_err_t driver_rd03_uart_init(uart_port_t uart_num, int pin_mcu_tx, int pin_mcu_rx)
{
    if (uart_num >= UART_NUM_MAX) {
        return ESP_ERR_INVALID_ARG;
    }

    uart_config_t cfg = {
        .baud_rate = 115200,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };
    esp_err_t err = uart_param_config(uart_num, &cfg);
    if (err != ESP_OK) {
        return err;
    }
    err = uart_set_pin(uart_num, pin_mcu_tx, pin_mcu_rx,
                       UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
    if (err != ESP_OK) {
        return err;
    }
    err = uart_driver_install(uart_num, RD03_RX_BUF * 2, 0, 0, NULL, 0);
    if (err != ESP_OK) {
        return err;
    }

    s_port = uart_num;
    s_uart_ready = true;
    s_acc_len = 0;
    HAL_LOGI(TAG, "RD-03 UART on port %d TX=%d RX=%d (V2 wiring)", (int)uart_num, pin_mcu_tx, pin_mcu_rx);
    return ESP_OK;
}

void driver_rd03_uart_reset_buffer(void)
{
    s_acc_len = 0;
}

esp_err_t driver_rd03_uart_poll(bool *out_updated, bool *out_present)
{
    if (!s_uart_ready || out_updated == NULL || out_present == NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    *out_updated = false;

    uint8_t chunk[128];
    int n = uart_read_bytes(s_port, chunk, sizeof(chunk), 0);
    if (n > 0) {
        size_t add = (size_t)n;
        if (s_acc_len + add > RD03_RX_BUF) {
            size_t drop = s_acc_len + add - RD03_RX_BUF;
            if (drop < s_acc_len) {
                memmove(s_acc, s_acc + drop, s_acc_len - drop);
                s_acc_len -= drop;
            } else {
                s_acc_len = 0;
            }
        }
        memcpy(s_acc + s_acc_len, chunk, add);
        s_acc_len += add;
    }

    bool present;
    size_t off, flen;
    while (scan_one(&present, &off, &flen)) {
        *out_present = present;
        *out_updated = true;
        memmove(s_acc, s_acc + off + flen, s_acc_len - (off + flen));
        s_acc_len -= off + flen;
    }

    return ESP_OK;
}
