#include "driver_rc522.h"
#include "esp_log.h"
#include "driver/i2c.h"
#include <string.h>

static const char *TAG = "RC522_HAL";
static uint8_t s_mock_card_data[48] = {0};
static uint16_t s_mock_card_len = 0;
static bool s_mock_has_card = false;

esp_err_t driver_rc522_init(void) {
    ESP_LOGI(TAG, "Initializing RC522 over I2C...");
    // TODO: Configure I2C master and initialize MFRC522 registers
    return ESP_OK;
}

esp_err_t driver_rc522_read_sector(uint8_t sector_num, const uint8_t *key, uint8_t *out_data) {
    (void)key;
    ESP_LOGI(TAG, "Attempting to authenticate and read Sector %d...", sector_num);
    // TODO: Send PICC_CMD_MF_AUTH_KEY_A to RC522, then MIFARE_Read
    if (!s_mock_has_card) {
        ESP_LOGW(TAG, "No card present in mock buffer");
        return ESP_ERR_NOT_FOUND;
    }
    if (out_data == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(out_data, 0, 16);
    memcpy(out_data, s_mock_card_data, (s_mock_card_len > 16) ? 16 : s_mock_card_len);
    return ESP_OK; // Return ESP_FAIL if crypto verification fails
}

esp_err_t driver_rc522_write_sector(uint8_t sector_num, const uint8_t *key, const uint8_t *data) {
    (void)key;
    ESP_LOGI(TAG, "Attempting to format and write to Sector %d...", sector_num);
    // TODO: Send PICC_CMD_MF_AUTH_KEY_B to RC522, then MIFARE_Write
    if (data == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(s_mock_card_data, 0, sizeof(s_mock_card_data));
    memcpy(s_mock_card_data, data, 16);
    s_mock_card_len = 16;
    s_mock_has_card = true;
    return ESP_OK;
}

esp_err_t driver_rc522_mock_present_card(const uint8_t *data, uint16_t data_len) {
    if (data == NULL || data_len == 0) {
        return ESP_ERR_INVALID_ARG;
    }
    uint16_t copy_len = (data_len > sizeof(s_mock_card_data)) ? sizeof(s_mock_card_data) : data_len;
    memset(s_mock_card_data, 0, sizeof(s_mock_card_data));
    memcpy(s_mock_card_data, data, copy_len);
    s_mock_card_len = copy_len;
    s_mock_has_card = true;
    ESP_LOGI(TAG, "Mock card presented, len=%u", (unsigned int)copy_len);
    return ESP_OK;
}

esp_err_t driver_rc522_mock_clear_card(void) {
    memset(s_mock_card_data, 0, sizeof(s_mock_card_data));
    s_mock_card_len = 0;
    s_mock_has_card = false;
    ESP_LOGI(TAG, "Mock card removed");
    return ESP_OK;
}

bool driver_rc522_mock_has_card(void) {
    return s_mock_has_card;
}
