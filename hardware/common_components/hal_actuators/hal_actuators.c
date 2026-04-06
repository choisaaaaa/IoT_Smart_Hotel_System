#include "hal_actuators.h"
#include "esp_log.h"

static const char *TAG = "HAL_ACTUATORS_MOCK";

esp_err_t hal_actuators_init(void) {
    ESP_LOGI(TAG, "[MOCK] 继电器 GPIO 初始化成功，已设为默认断开状态");
    // TODO: 硬件到货后，此处替换为 gpio_config_t 真实引脚配置
    return ESP_OK;
}

esp_err_t hal_actuators_set_state(actuator_type_t type, bool state) {
    const char* state_str = state ? "打开 (ON)" : "关闭 (OFF)";
    
    switch (type) {
        case ACTUATOR_LIGHT_MAIN:
            ESP_LOGI(TAG, "[MOCK] 继电器执行: 客房主灯/走廊照明 -> %s", state_str);
            break;
        case ACTUATOR_SOCKET:
            ESP_LOGI(TAG, "[MOCK] 继电器执行: 客房插座/备用控制 -> %s", state_str);
            break;
        case ACTUATOR_CURTAIN:
            ESP_LOGI(TAG, "[MOCK] 继电器执行: 窗帘电机 -> %s", state_str);
            break;
        case ACTUATOR_DOOR_LOCK:
            ESP_LOGI(TAG, "[MOCK] 继电器执行: 电磁门锁 -> %s", state_str);
            break;
        default:
            ESP_LOGE(TAG, "[MOCK] 错误: 未知的执行器类型");
            return ESP_FAIL;
    }
    
    // TODO: 硬件到货后，此处替换为 gpio_set_level() 真实拉高拉低引脚
    return ESP_OK;
}
