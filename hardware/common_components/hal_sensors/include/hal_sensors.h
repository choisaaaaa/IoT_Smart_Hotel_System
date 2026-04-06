#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 传感器数据结构体，上层业务只需获取此结构体即可打包 JSON
 */
typedef struct {
    float temperature;         // 温度 (摄氏度, 如 24.5)
    float humidity;            // 湿度 (%, 如 50.0)
    uint16_t air_quality_adc;  // 空气质量/烟雾浓度 (MQ-135/MQ-2 ADC采集值)
    uint16_t light_adc;        // 环境光照强度 (光敏电阻 ADC采集值)
    bool is_human_present;     // 是否有人 (毫米波雷达检测, true=有人)
} sensor_data_t;

/**
 * @brief 初始化所有环境采集引脚与 ADC 驱动
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t hal_sensors_init(void);

/**
 * @brief 获取所有传感器的最新数据
 * @param out_data 传入的结构体指针，用于接收数据
 * @return esp_err_t ESP_OK 读取成功
 */
esp_err_t hal_sensors_read_all(sensor_data_t *out_data);

#ifdef __cplusplus
}
#endif
