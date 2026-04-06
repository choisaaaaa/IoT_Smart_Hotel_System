#include "driver_rc522.h"
#include "esp_log.h"
#include "driver/i2c.h"

static const char *TAG = "RC522_HAL";

esp_err_t driver_rc522_init(void) {
    ESP_LOGI(TAG, "Initializing RC522 over I2C...");
    // TODO: Configure I2C master and initialize MFRC522 registers
    return ESP_OK;
}

esp_err_t driver_rc522_read_sector(uint8_t sector_num, const uint8_t *key, uint8_t *out_data) {
    ESP_LOGI(TAG, "Attempting to authenticate and read Sector %d...", sector_num);
    // TODO: Send PICC_CMD_MF_AUTH_KEY_A to RC522, then MIFARE_Read
    return ESP_OK; // Return ESP_FAIL if crypto verification fails
}

esp_err_t driver_rc522_write_sector(uint8_t sector_num, const uint8_t *key, const uint8_t *data) {
    ESP_LOGI(TAG, "Attempting to format and write to Sector %d...", sector_num);
    // TODO: Send PICC_CMD_MF_AUTH_KEY_B to RC522, then MIFARE_Write
    return ESP_OK;
}
