#include "driver_rc522.h"
#include "esp_log.h"
#include "driver/spi_master.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "global_config.h"
#include <string.h>

static const char *TAG = "RC522_HAL";

static bool s_inited = false;
static bool s_bus_inited = false;
static spi_device_handle_t s_rc522_spi = NULL;

// MFRC522 registers
#define RC522_REG_COMMAND       0x01
#define RC522_REG_COM_I_EN      0x02
#define RC522_REG_DIV_I_EN      0x03
#define RC522_REG_COM_IRQ       0x04
#define RC522_REG_DIV_IRQ       0x05
#define RC522_REG_ERROR         0x06
#define RC522_REG_STATUS1       0x07
#define RC522_REG_STATUS2       0x08
#define RC522_REG_FIFO_DATA     0x09
#define RC522_REG_FIFO_LEVEL    0x0A
#define RC522_REG_CONTROL       0x0C
#define RC522_REG_BIT_FRAMING   0x0D
#define RC522_REG_COLL          0x0E
#define RC522_REG_MODE          0x11
#define RC522_REG_TX_MODE       0x12
#define RC522_REG_RX_MODE       0x13
#define RC522_REG_TX_CONTROL    0x14
#define RC522_REG_TX_ASK        0x15
#define RC522_REG_CRC_RESULT_H  0x21
#define RC522_REG_CRC_RESULT_L  0x22
#define RC522_REG_T_MODE        0x2A
#define RC522_REG_T_PRESCALER   0x2B
#define RC522_REG_T_RELOAD_H    0x2C
#define RC522_REG_T_RELOAD_L    0x2D

// MFRC522 commands
#define PCD_IDLE                0x00
#define PCD_CALC_CRC            0x03
#define PCD_TRANSCEIVE          0x0C
#define PCD_MF_AUTHENT          0x0E
#define PCD_SOFT_RESET          0x0F

// PICC commands
#define PICC_CMD_REQA           0x26
#define PICC_CMD_SEL_CL1        0x93
#define PICC_CMD_MF_AUTH_KEY_A  0x60
#define PICC_CMD_MF_READ        0x30
#define PICC_CMD_MF_WRITE       0xA0

static esp_err_t rc522_write_reg(uint8_t reg, uint8_t value) {
    if (s_rc522_spi == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    uint8_t tx[2] = {(uint8_t)((reg << 1) & 0x7E), value};
    spi_transaction_t t = {
        .length = 16,
        .tx_buffer = tx,
    };
    return spi_device_transmit(s_rc522_spi, &t);
}

static esp_err_t rc522_read_reg(uint8_t reg, uint8_t *out) {
    if (s_rc522_spi == NULL || out == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    uint8_t tx[2] = {(uint8_t)(((reg << 1) & 0x7E) | 0x80), 0x00};
    uint8_t rx[2] = {0};
    spi_transaction_t t = {
        .length = 16,
        .tx_buffer = tx,
        .rx_buffer = rx,
    };
    esp_err_t err = spi_device_transmit(s_rc522_spi, &t);
    if (err != ESP_OK) {
        return err;
    }
    *out = rx[1];
    return ESP_OK;
}

static esp_err_t rc522_set_bit_mask(uint8_t reg, uint8_t mask) {
    uint8_t v = 0;
    esp_err_t err = rc522_read_reg(reg, &v);
    if (err != ESP_OK) {
        return err;
    }
    return rc522_write_reg(reg, v | mask);
}

static esp_err_t rc522_clear_bit_mask(uint8_t reg, uint8_t mask) {
    uint8_t v = 0;
    esp_err_t err = rc522_read_reg(reg, &v);
    if (err != ESP_OK) {
        return err;
    }
    return rc522_write_reg(reg, v & (uint8_t)(~mask));
}

static esp_err_t rc522_antenna_on(void) {
    uint8_t v = 0;
    esp_err_t err = rc522_read_reg(RC522_REG_TX_CONTROL, &v);
    if (err != ESP_OK) {
        return err;
    }
    if ((v & 0x03) != 0x03) {
        return rc522_set_bit_mask(RC522_REG_TX_CONTROL, 0x03);
    }
    return ESP_OK;
}

static esp_err_t rc522_calculate_crc(const uint8_t *data, uint8_t len, uint8_t *out_crc) {
    if (data == NULL || out_crc == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    rc522_write_reg(RC522_REG_COMMAND, PCD_IDLE);
    rc522_write_reg(RC522_REG_DIV_IRQ, 0x04);
    rc522_set_bit_mask(RC522_REG_FIFO_LEVEL, 0x80);
    for (uint8_t i = 0; i < len; i++) {
        rc522_write_reg(RC522_REG_FIFO_DATA, data[i]);
    }
    rc522_write_reg(RC522_REG_COMMAND, PCD_CALC_CRC);

    for (int i = 0; i < 25; i++) {
        uint8_t n = 0;
        if (rc522_read_reg(RC522_REG_DIV_IRQ, &n) == ESP_OK && (n & 0x04)) {
            out_crc[0] = 0;
            out_crc[1] = 0;
            rc522_read_reg(RC522_REG_CRC_RESULT_L, &out_crc[0]);
            rc522_read_reg(RC522_REG_CRC_RESULT_H, &out_crc[1]);
            rc522_write_reg(RC522_REG_COMMAND, PCD_IDLE);
            return ESP_OK;
        }
        vTaskDelay(pdMS_TO_TICKS(1));
    }
    rc522_write_reg(RC522_REG_COMMAND, PCD_IDLE);
    return ESP_ERR_TIMEOUT;
}

static esp_err_t rc522_transceive(const uint8_t *send, uint8_t send_len, uint8_t *back, uint8_t *back_len, uint8_t *valid_bits) {
    if (send == NULL || send_len == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    rc522_write_reg(RC522_REG_COMMAND, PCD_IDLE);
    rc522_write_reg(RC522_REG_COM_IRQ, 0x7F);
    rc522_set_bit_mask(RC522_REG_FIFO_LEVEL, 0x80);

    for (uint8_t i = 0; i < send_len; i++) {
        rc522_write_reg(RC522_REG_FIFO_DATA, send[i]);
    }

    rc522_write_reg(RC522_REG_COMMAND, PCD_TRANSCEIVE);
    rc522_set_bit_mask(RC522_REG_BIT_FRAMING, 0x80);

    bool irq_done = false;
    for (int i = 0; i < 35; i++) {
        uint8_t irq = 0;
        rc522_read_reg(RC522_REG_COM_IRQ, &irq);
        if (irq & 0x30) { // RxIRq or IdleIRq
            irq_done = true;
            break;
        }
        if (irq & 0x01) { // TimerIRq
            break;
        }
        vTaskDelay(pdMS_TO_TICKS(1));
    }
    rc522_clear_bit_mask(RC522_REG_BIT_FRAMING, 0x80);
    if (!irq_done) {
        return ESP_ERR_TIMEOUT;
    }

    uint8_t err = 0;
    rc522_read_reg(RC522_REG_ERROR, &err);
    if (err & 0x13) { // BufferOvfl ParityErr ProtocolErr
        return ESP_FAIL;
    }

    uint8_t fifo_len = 0;
    rc522_read_reg(RC522_REG_FIFO_LEVEL, &fifo_len);
    uint8_t last_bits = 0;
    rc522_read_reg(RC522_REG_CONTROL, &last_bits);
    last_bits &= 0x07;
    if (valid_bits != NULL) {
        *valid_bits = last_bits;
    }

    if (back != NULL && back_len != NULL) {
        uint8_t n = (*back_len < fifo_len) ? *back_len : fifo_len;
        for (uint8_t i = 0; i < n; i++) {
            rc522_read_reg(RC522_REG_FIFO_DATA, &back[i]);
        }
        *back_len = n;
    }
    return ESP_OK;
}

static esp_err_t rc522_request_a(void) {
    uint8_t cmd = PICC_CMD_REQA;
    uint8_t atqa[2] = {0};
    uint8_t atqa_len = 2;
    uint8_t valid_bits = 7;
    rc522_write_reg(RC522_REG_BIT_FRAMING, 0x07); // 7-bit REQA
    esp_err_t err = rc522_transceive(&cmd, 1, atqa, &atqa_len, &valid_bits);
    rc522_write_reg(RC522_REG_BIT_FRAMING, 0x00);
    if (err != ESP_OK) {
        return err;
    }
    if (atqa_len != 2 || valid_bits != 0) {
        return ESP_FAIL;
    }
    return ESP_OK;
}

static esp_err_t rc522_anticoll_cl1(uint8_t *uid4) {
    if (uid4 == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    uint8_t cmd[2] = {PICC_CMD_SEL_CL1, 0x20};
    uint8_t resp[5] = {0};
    uint8_t resp_len = 5;
    uint8_t valid_bits = 0;
    rc522_write_reg(RC522_REG_BIT_FRAMING, 0x00);
    esp_err_t err = rc522_transceive(cmd, 2, resp, &resp_len, &valid_bits);
    if (err != ESP_OK || resp_len != 5) {
        return ESP_FAIL;
    }
    uint8_t bcc = (uint8_t)(resp[0] ^ resp[1] ^ resp[2] ^ resp[3]);
    if (bcc != resp[4]) {
        return ESP_FAIL;
    }
    memcpy(uid4, resp, 4);
    return ESP_OK;
}

static esp_err_t rc522_select_cl1(const uint8_t *uid4) {
    uint8_t buf[9] = {PICC_CMD_SEL_CL1, 0x70, uid4[0], uid4[1], uid4[2], uid4[3], 0x00, 0x00, 0x00};
    buf[6] = (uint8_t)(uid4[0] ^ uid4[1] ^ uid4[2] ^ uid4[3]);
    esp_err_t err = rc522_calculate_crc(buf, 7, &buf[7]);
    if (err != ESP_OK) {
        return err;
    }
    uint8_t sak[3] = {0};
    uint8_t sak_len = sizeof(sak);
    uint8_t valid_bits = 0;
    err = rc522_transceive(buf, sizeof(buf), sak, &sak_len, &valid_bits);
    if (err != ESP_OK || sak_len < 1) {
        return ESP_FAIL;
    }
    return ESP_OK;
}

static esp_err_t rc522_stop_crypto(void) {
    return rc522_clear_bit_mask(RC522_REG_STATUS2, 0x08);
}

static esp_err_t rc522_auth_a(uint8_t block_addr, const uint8_t *key, const uint8_t *uid4) {
    uint8_t buff[12] = {PICC_CMD_MF_AUTH_KEY_A, block_addr, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    memcpy(&buff[2], key, 6);
    memcpy(&buff[8], uid4, 4);

    rc522_write_reg(RC522_REG_COMMAND, PCD_IDLE);
    rc522_write_reg(RC522_REG_COM_IRQ, 0x7F);
    rc522_set_bit_mask(RC522_REG_FIFO_LEVEL, 0x80);
    for (uint8_t i = 0; i < sizeof(buff); i++) {
        rc522_write_reg(RC522_REG_FIFO_DATA, buff[i]);
    }
    rc522_write_reg(RC522_REG_COMMAND, PCD_MF_AUTHENT);

    for (int i = 0; i < 25; i++) {
        uint8_t irq = 0;
        rc522_read_reg(RC522_REG_COM_IRQ, &irq);
        if (irq & 0x10) { // IdleIRq
            break;
        }
        if (irq & 0x01) { // TimerIRq
            return ESP_ERR_TIMEOUT;
        }
        vTaskDelay(pdMS_TO_TICKS(1));
    }

    uint8_t status2 = 0;
    rc522_read_reg(RC522_REG_STATUS2, &status2);
    if (!(status2 & 0x08)) {
        return ESP_FAIL;
    }
    return ESP_OK;
}

static uint8_t rc522_sector_to_data_block(uint8_t sector_num) {
    // MIFARE 1K: each sector has 4 blocks; first block is data block.
    return (uint8_t)(sector_num * 4);
}

static esp_err_t rc522_mifare_read_block(uint8_t block_addr, uint8_t *out_data16) {
    uint8_t cmd[4] = {PICC_CMD_MF_READ, block_addr, 0, 0};
    esp_err_t err = rc522_calculate_crc(cmd, 2, &cmd[2]);
    if (err != ESP_OK) {
        return err;
    }
    uint8_t back[18] = {0};
    uint8_t back_len = sizeof(back);
    uint8_t valid_bits = 0;
    err = rc522_transceive(cmd, sizeof(cmd), back, &back_len, &valid_bits);
    if (err != ESP_OK || back_len < 16) {
        return ESP_FAIL;
    }
    memcpy(out_data16, back, 16);
    return ESP_OK;
}

static esp_err_t rc522_mifare_write_block(uint8_t block_addr, const uint8_t *data16) {
    uint8_t cmd[4] = {PICC_CMD_MF_WRITE, block_addr, 0, 0};
    esp_err_t err = rc522_calculate_crc(cmd, 2, &cmd[2]);
    if (err != ESP_OK) {
        return err;
    }
    uint8_t ack[3] = {0};
    uint8_t ack_len = sizeof(ack);
    uint8_t valid_bits = 0;
    err = rc522_transceive(cmd, sizeof(cmd), ack, &ack_len, &valid_bits);
    if (err != ESP_OK || ack_len == 0 || (ack[0] & 0x0F) != 0x0A) {
        return ESP_FAIL;
    }

    uint8_t payload[18] = {0};
    memcpy(payload, data16, 16);
    err = rc522_calculate_crc(payload, 16, &payload[16]);
    if (err != ESP_OK) {
        return err;
    }

    ack_len = sizeof(ack);
    valid_bits = 0;
    err = rc522_transceive(payload, sizeof(payload), ack, &ack_len, &valid_bits);
    if (err != ESP_OK || ack_len == 0 || (ack[0] & 0x0F) != 0x0A) {
        return ESP_FAIL;
    }
    return ESP_OK;
}

esp_err_t driver_rc522_init(void) {
    if (s_inited) {
        return ESP_OK;
    }

    spi_bus_config_t bus_cfg = {
        .mosi_io_num = GLOBAL_SPI_MOSI_PIN,
        .miso_io_num = GLOBAL_SPI_MISO_PIN,
        .sclk_io_num = GLOBAL_SPI_SCLK_PIN,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = 64,
    };

    if (!s_bus_inited) {
        esp_err_t bus_err = spi_bus_initialize(SPI2_HOST, &bus_cfg, SPI_DMA_CH_AUTO);
        if (bus_err != ESP_OK && bus_err != ESP_ERR_INVALID_STATE) {
            ESP_LOGE(TAG, "SPI bus init failed: %s", esp_err_to_name(bus_err));
            return bus_err;
        }
        s_bus_inited = true;
    }

    spi_device_interface_config_t dev_cfg = {
        .clock_speed_hz = 1000000,
        .mode = 0,
        .spics_io_num = GLOBAL_SPI_CS_RC522_PIN,
        .queue_size = 4,
    };

    esp_err_t err = spi_bus_add_device(SPI2_HOST, &dev_cfg, &s_rc522_spi);
    if (err == ESP_ERR_INVALID_STATE && s_rc522_spi != NULL) {
        err = ESP_OK;
    }
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "RC522 add spi device failed: %s", esp_err_to_name(err));
        return err;
    }

    rc522_write_reg(RC522_REG_COMMAND, PCD_SOFT_RESET);
    vTaskDelay(pdMS_TO_TICKS(50));

    rc522_write_reg(RC522_REG_T_MODE, 0x80);
    rc522_write_reg(RC522_REG_T_PRESCALER, 0xA9);
    rc522_write_reg(RC522_REG_T_RELOAD_L, 0xE8);
    rc522_write_reg(RC522_REG_T_RELOAD_H, 0x03);
    rc522_write_reg(RC522_REG_TX_ASK, 0x40);
    rc522_write_reg(RC522_REG_MODE, 0x3D);
    rc522_write_reg(RC522_REG_TX_MODE, 0x00);
    rc522_write_reg(RC522_REG_RX_MODE, 0x00);
    rc522_antenna_on();

    s_inited = true;
    ESP_LOGI(TAG, "RC522 SPI init ok (MOSI=%d MISO=%d SCLK=%d CS=%d)",
             GLOBAL_SPI_MOSI_PIN, GLOBAL_SPI_MISO_PIN, GLOBAL_SPI_SCLK_PIN, GLOBAL_SPI_CS_RC522_PIN);
    return ESP_OK;
}

esp_err_t driver_rc522_read_uid(uint8_t *uid, uint8_t *uid_len) {
    if (uid == NULL || uid_len == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }

    esp_err_t err = rc522_request_a();
    if (err != ESP_OK) {
        return ESP_ERR_NOT_FOUND;
    }

    err = rc522_anticoll_cl1(uid);
    if (err != ESP_OK) {
        return ESP_ERR_NOT_FOUND;
    }

    err = rc522_select_cl1(uid);
    if (err != ESP_OK) {
        return ESP_FAIL;
    }

    *uid_len = 4;
    return ESP_OK;
}

esp_err_t driver_rc522_read_sector(uint8_t sector_num, const uint8_t *key, uint8_t *out_data) {
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    if (key == NULL || out_data == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (sector_num > 15) {
        return ESP_ERR_INVALID_ARG;
    }

    uint8_t uid[10] = {0};
    uint8_t uid_len = 0;
    esp_err_t err = driver_rc522_read_uid(uid, &uid_len);
    if (err != ESP_OK || uid_len < 4) {
        return ESP_ERR_NOT_FOUND;
    }

    uint8_t block_addr = rc522_sector_to_data_block(sector_num);
    err = rc522_auth_a(block_addr, key, uid);
    if (err != ESP_OK) {
        rc522_stop_crypto();
        return err;
    }

    err = rc522_mifare_read_block(block_addr, out_data);
    rc522_stop_crypto();
    return err;
}

esp_err_t driver_rc522_write_sector(uint8_t sector_num, const uint8_t *key, const uint8_t *data) {
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    if (key == NULL || data == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (sector_num > 15) {
        return ESP_ERR_INVALID_ARG;
    }

    uint8_t uid[10] = {0};
    uint8_t uid_len = 0;
    esp_err_t err = driver_rc522_read_uid(uid, &uid_len);
    if (err != ESP_OK || uid_len < 4) {
        return ESP_ERR_NOT_FOUND;
    }

    uint8_t block_addr = rc522_sector_to_data_block(sector_num);
    err = rc522_auth_a(block_addr, key, uid);
    if (err != ESP_OK) {
        rc522_stop_crypto();
        return err;
    }

    err = rc522_mifare_write_block(block_addr, data);
    rc522_stop_crypto();
    return err;
}

esp_err_t driver_rc522_mock_present_card(const uint8_t *data, uint16_t data_len) {
    (void)data;
    (void)data_len;
    ESP_LOGW(TAG, "mock_present_card 已废弃：当前使用真实 RC522 SPI 驱动");
    return ESP_ERR_NOT_SUPPORTED;
}

esp_err_t driver_rc522_mock_clear_card(void) {
    ESP_LOGW(TAG, "mock_clear_card 已废弃：当前使用真实 RC522 SPI 驱动");
    return ESP_ERR_NOT_SUPPORTED;
}

bool driver_rc522_mock_has_card(void) {
    return false;
}
