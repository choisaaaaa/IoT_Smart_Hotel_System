#include "driver_w25q64.h"
#include "hal_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>
#include <stdlib.h>

static const char *TAG = "DRIVER_W25Q64";

// W25Q64 常用指令
#define CMD_READ_ID         0x9F
#define CMD_READ_DATA       0x03
#define CMD_PAGE_PROGRAM    0x02
#define CMD_SECTOR_ERASE_4K 0x20
#define CMD_READ_STATUS_1   0x05
#define CMD_WRITE_ENABLE    0x06

static bool s_inited = false;
static spi_device_handle_t s_dev = NULL;

static esp_err_t txrx(const uint8_t *tx, uint8_t *rx, size_t len)
{
    spi_transaction_t t = {0};
    t.length = (int)(len * 8);
    t.tx_buffer = tx;
    t.rx_buffer = rx;
    return spi_device_transmit(s_dev, &t);
}

static esp_err_t write_enable(void)
{
    uint8_t cmd = CMD_WRITE_ENABLE;
    return txrx(&cmd, NULL, 1);
}

static esp_err_t read_status1(uint8_t *out_status)
{
    if (out_status == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    uint8_t tx[2] = {CMD_READ_STATUS_1, 0x00};
    uint8_t rx[2] = {0};
    esp_err_t err = txrx(tx, rx, sizeof(tx));
    if (err != ESP_OK) {
        return err;
    }
    *out_status = rx[1];
    return ESP_OK;
}

static esp_err_t wait_busy_clear(int timeout_ms)
{
    int elapsed = 0;
    while (elapsed < timeout_ms) {
        uint8_t st = 0;
        esp_err_t err = read_status1(&st);
        if (err != ESP_OK) {
            return err;
        }
        if ((st & 0x01) == 0) {
            return ESP_OK;
        }
        vTaskDelay(pdMS_TO_TICKS(1));
        elapsed += 1;
    }
    return ESP_ERR_TIMEOUT;
}

esp_err_t driver_w25q64_init(const driver_w25q64_config_t *cfg)
{
    if (s_inited) {
        return ESP_OK;
    }
    if (cfg == NULL || cfg->pin_mosi < 0 || cfg->pin_miso < 0 || cfg->pin_sclk < 0 || cfg->pin_cs < 0) {
        return ESP_ERR_INVALID_ARG;
    }

    spi_bus_config_t buscfg = {
        .mosi_io_num = cfg->pin_mosi,
        .miso_io_num = cfg->pin_miso,
        .sclk_io_num = cfg->pin_sclk,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = (cfg->max_transfer_sz > 0) ? cfg->max_transfer_sz : 4096,
    };
    esp_err_t err = spi_bus_initialize(cfg->spi_host, &buscfg, SPI_DMA_CH_AUTO);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "spi_bus_initialize failed: %s", esp_err_to_name(err));
        return err;
    }

    spi_device_interface_config_t devcfg = {
        .clock_speed_hz = (cfg->clock_hz > 0) ? cfg->clock_hz : (10 * 1000 * 1000),
        .mode = 0,
        .spics_io_num = cfg->pin_cs,
        .queue_size = 1,
    };
    err = spi_bus_add_device(cfg->spi_host, &devcfg, &s_dev);
    if (err != ESP_OK) {
        spi_bus_free(cfg->spi_host);
        return err;
    }

    s_inited = true;
    HAL_LOGI(TAG, "W25Q64 init on SPI host=%d CS=%d", (int)cfg->spi_host, cfg->pin_cs);
    return ESP_OK;
}

esp_err_t driver_w25q64_read_jedec_id(uint8_t *mid, uint8_t *mem_type, uint8_t *capacity)
{
    if (!s_inited || mid == NULL || mem_type == NULL || capacity == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    uint8_t tx[4] = {CMD_READ_ID, 0x00, 0x00, 0x00};
    uint8_t rx[4] = {0};
    esp_err_t err = txrx(tx, rx, sizeof(tx));
    if (err != ESP_OK) {
        return err;
    }
    *mid = rx[1];
    *mem_type = rx[2];
    *capacity = rx[3];
    return ESP_OK;
}

esp_err_t driver_w25q64_read(uint32_t addr, uint8_t *out_data, size_t len)
{
    if (!s_inited || out_data == NULL || len == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    size_t total = 4 + len;
    uint8_t *tx = (uint8_t *)calloc(total, 1);
    uint8_t *rx = (uint8_t *)calloc(total, 1);
    if (tx == NULL || rx == NULL) {
        free(tx);
        free(rx);
        return ESP_ERR_NO_MEM;
    }

    tx[0] = CMD_READ_DATA;
    tx[1] = (uint8_t)(addr >> 16);
    tx[2] = (uint8_t)(addr >> 8);
    tx[3] = (uint8_t)(addr);

    spi_transaction_t t = {0};
    t.length = (int)(total * 8);
    t.tx_buffer = tx;
    t.rx_buffer = rx;
    esp_err_t err = spi_device_transmit(s_dev, &t);
    if (err == ESP_OK) {
        memcpy(out_data, rx + 4, len);
    }
    free(tx);
    free(rx);
    return err;
}

esp_err_t driver_w25q64_sector_erase_4k(uint32_t addr)
{
    if (!s_inited) {
        return ESP_ERR_INVALID_STATE;
    }
    esp_err_t err = write_enable();
    if (err != ESP_OK) {
        return err;
    }

    uint8_t tx[4] = {
        CMD_SECTOR_ERASE_4K,
        (uint8_t)(addr >> 16),
        (uint8_t)(addr >> 8),
        (uint8_t)(addr),
    };
    err = txrx(tx, NULL, sizeof(tx));
    if (err != ESP_OK) {
        return err;
    }
    return wait_busy_clear(5000);
}

esp_err_t driver_w25q64_page_program(uint32_t addr, const uint8_t *data, size_t len)
{
    if (!s_inited || data == NULL || len == 0 || len > 256) {
        return ESP_ERR_INVALID_ARG;
    }

    // 页写不能跨页
    if (((addr & 0xFF) + len) > 256) {
        return ESP_ERR_INVALID_SIZE;
    }

    esp_err_t err = write_enable();
    if (err != ESP_OK) {
        return err;
    }

    size_t total = 4 + len;
    uint8_t *tx = (uint8_t *)malloc(total);
    if (tx == NULL) {
        return ESP_ERR_NO_MEM;
    }
    tx[0] = CMD_PAGE_PROGRAM;
    tx[1] = (uint8_t)(addr >> 16);
    tx[2] = (uint8_t)(addr >> 8);
    tx[3] = (uint8_t)(addr);
    memcpy(tx + 4, data, len);

    spi_transaction_t t = {0};
    t.length = (int)(total * 8);
    t.tx_buffer = tx;
    err = spi_device_transmit(s_dev, &t);
    free(tx);
    if (err != ESP_OK) {
        return err;
    }

    return wait_busy_clear(100);
}
