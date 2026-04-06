#include "hal_infrared.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "HAL_INFRARED_MOCK";

esp_err_t hal_infrared_init(void) {
    ESP_LOGI(TAG, "[MOCK] 红外发射管(RMT)与接收头(GPIO Interrupt)初始化完成");
    // TODO: 硬件到位后配置 rmt_config_t 和 gpio_isr_handler_add()
    return ESP_OK;
}

esp_err_t hal_infrared_send_ac_command(ir_brand_type_t brand, const ir_ac_cmd_t *cmd) {
    if (cmd == NULL) return ESP_ERR_INVALID_ARG;

    const char* brand_str = (brand == IR_BRAND_GREE) ? "格力" : (brand == IR_BRAND_MIDEA) ? "美的" : "电视机";
    const char* power_str = cmd->power_on ? "开机" : "关机";
    
    // 模拟组包与发射的时间
    vTaskDelay(pdMS_TO_TICKS(50));
    ESP_LOGI(TAG, "[MOCK] 成功发出 %s 空调红外遥控指令 -> %s | 设温: %d℃", brand_str, power_str, cmd->temperature);

    // TODO: 硬件到位后替换为红外库的组包函数，并通过 rmt_write_items() 发送载波
    return ESP_OK;
}

esp_err_t hal_infrared_learn_code(uint8_t *out_buffer, size_t max_len, uint32_t timeout_ms) {
    if (out_buffer == NULL) return ESP_ERR_INVALID_ARG;

    ESP_LOGI(TAG, "[MOCK] 红外学习模式已开启，等待接收环境中的遥控器红外光信号... 超时：%u ms", timeout_ms);
    // 模拟用户在 2 秒后按下了遥控器按键
    vTaskDelay(pdMS_TO_TICKS(2000));
    
    // 随便填充点特征码
    for (int i = 0; i < (max_len > 10 ? 10 : max_len); i++) {
        out_buffer[i] = 0xAA + i;
    }

    ESP_LOGI(TAG, "[MOCK] 成功捕捉到来自未知遥控器的红外波形时序特征码，已返回给业务层");
    // TODO: 硬件到位后替换为真实的接收中断逻辑和高低电平时序计算
    return ESP_OK;
}
