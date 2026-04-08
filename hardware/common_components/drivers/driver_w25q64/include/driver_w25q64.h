#pragma once

#include <stddef.h>
#include <stdint.h>
#include "driver/spi_master.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    spi_host_device_t spi_host;
    int pin_mosi;
    int pin_miso;
    int pin_sclk;
    int pin_cs;
    int max_transfer_sz;
    int clock_hz; // 例如 10*1000*1000
} driver_w25q64_config_t;

esp_err_t driver_w25q64_init(const driver_w25q64_config_t *cfg);
esp_err_t driver_w25q64_read_jedec_id(uint8_t *mid, uint8_t *mem_type, uint8_t *capacity);
esp_err_t driver_w25q64_read(uint32_t addr, uint8_t *out_data, size_t len);
esp_err_t driver_w25q64_sector_erase_4k(uint32_t addr);
esp_err_t driver_w25q64_page_program(uint32_t addr, const uint8_t *data, size_t len); // len <= 256

#ifdef __cplusplus
}
#endif
