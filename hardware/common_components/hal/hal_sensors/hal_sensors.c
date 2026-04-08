#include "hal_sensors.h"
#include "esp_log.h"
#include "esp_timer.h" // 用于生成伪造的时间随机数

static const char *TAG = "HAL_SENSORS_MOCK";

esp_err_t hal_sensors_init(void) {
    ESP_LOGI(TAG, "[MOCK] 环境传感器 ADC 及 GPIO 初始化成功");
    // TODO: 硬件到货后，此处配置 adc_oneshot 模块及 DHT11/雷达引脚
    return ESP_OK;
}

esp_err_t hal_sensors_read_all(sensor_data_t *out_data) {
    if (out_data == NULL) return ESP_ERR_INVALID_ARG;

    // 为了让前端测试数据波动，我们利用系统运行时间(微妙)生成一些轻微浮动的伪造数据
    int64_t time_us = esp_timer_get_time();
    
    // 伪造：温度在 24.0 ~ 25.0 之间波动
    out_data->temperature = 24.0f + (time_us % 10) * 0.1f;
    // 伪造：湿度在 50.0 ~ 55.0 之间波动
    out_data->humidity = 50.0f + (time_us % 5);
    // 伪造：空气质量 ADC 值 (越小越干净)
    out_data->air_quality_adc = 400 + (time_us % 50);
    // 伪造：光敏电阻 ADC 值
    out_data->light_adc = 1200 + (time_us % 100);
    
    // 伪造：永远有人 (毫米波雷达高电平)
    out_data->is_human_present = true;

    ESP_LOGI(TAG, "[MOCK] 传感器打包读取完成 - T: %.1fC, H: %.1f%%, MQ: %d, Radar: %d", 
             out_data->temperature, out_data->humidity, out_data->air_quality_adc, out_data->is_human_present);

    // TODO: 硬件到货后，替换为真实的 DHT11 协议读取及 ADC 读取操作
    return ESP_OK;
}
