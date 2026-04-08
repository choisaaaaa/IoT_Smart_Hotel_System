#pragma once

#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float temperature_c;
    float humidity_percent;
} driver_dht11_data_t;

/**
 * @brief 初始化 DHT11 驱动
 * @param gpio_num 数据引脚（需外接上拉电阻，常见 4.7k~10k）
 */
esp_err_t driver_dht11_init(int gpio_num);

/**
 * @brief 读取一次 DHT11 数据（阻塞式，约 5~20ms）
 */
esp_err_t driver_dht11_read(driver_dht11_data_t *out_data);

#ifdef __cplusplus
}
#endif
