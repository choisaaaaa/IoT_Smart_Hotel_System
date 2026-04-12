#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// ==========================================
// 全局网络与后台服务器配置 (Global Network Config)
// 统一在此处修改，客房端、前台端、楼控端一键生效
// ==========================================

// 后台 MQTT 服务器地址配置
// 开发环境: mqtt://192.168.1.100:1883
// 云服务器: mqtt://your-domain.com:1883 或 mqtt://your-server-ip:1883
// 生产环境(推荐): mqtts://your-domain.com:8883 (启用TLS加密)
#define GLOBAL_MQTT_BROKER_URI "mqtt://192.168.1.100:1883"

// 默认配网 AP 热点名称前缀
#define GLOBAL_WIFI_DEFAULT_SSID "SmartHotel_AP"

// ==========================================
// 统一主题模板与预开发开关
// ==========================================
#define GLOBAL_TOPIC_DEVICE_STATUS_PREFIX        "hotel/device/status"
#define GLOBAL_TOPIC_DEVICE_DATA_PREFIX          "hotel/device/data"
#define GLOBAL_TOPIC_DEVICE_COMMAND_PREFIX       "hotel/device/command"
#define GLOBAL_TOPIC_DEVICE_COMMAND_RESULT       "hotel/device/command/result"
#define GLOBAL_TOPIC_SECURITY_EVENT              "hotel/security/event"

// 开发阶段默认允许无签名上报；联调后切换为 1
#define GLOBAL_ENABLE_MESSAGE_SIGNATURE          0

// 驱动分层预开发：允许 mock 兜底，后续可逐模块切换为 0
#define GLOBAL_ENABLE_MOCK_NETWORK               1
#define GLOBAL_ENABLE_MOCK_SENSORS               1
#define GLOBAL_ENABLE_MOCK_AUDIO                 1
#define GLOBAL_ENABLE_MOCK_INFRARED              1
#define GLOBAL_ENABLE_MOCK_RC522                 1

// ==========================================
// 统一硬件引脚分配 (ESP32-S3 冻结引脚)
// 根据文档《01_硬件架构与设计基线_v1.0.md》配置
// ==========================================

// 音频主线 (I2S)
#define GLOBAL_I2S_BCLK_PIN        42
#define GLOBAL_I2S_WS_PIN          41
#define GLOBAL_I2S_DIN_PIN         40
#define GLOBAL_I2S_DOUT_PIN        39
#define GLOBAL_PTT_BTN_PIN         14 // 客房呼叫前台按键

// SPI 总线 (RC522, W25Q64)
#define GLOBAL_SPI_MOSI_PIN        11
#define GLOBAL_SPI_MISO_PIN        13
#define GLOBAL_SPI_SCLK_PIN        12
#define GLOBAL_SPI_CS_RC522_PIN    10
#define GLOBAL_SPI_CS_W25Q64_PIN   9

// I2C 总线 (OLED)
#define GLOBAL_OLED_I2C_PORT_NUM   0
#define GLOBAL_OLED_PIN_SDA        21
#define GLOBAL_OLED_PIN_SCL        8
#define GLOBAL_OLED_I2C_ADDR       0x3C
#define GLOBAL_OLED_HEIGHT         64
#define GLOBAL_OLED_RST_GPIO       (-1)

// UART 总线 (RD-03雷达)
#define GLOBAL_UART_RD03_TX_PIN    15
#define GLOBAL_UART_RD03_RX_PIN    16

// ADC 采样 (传感器)
#define GLOBAL_ADC_MQ2_PIN         4
#define GLOBAL_ADC_LDR_PIN         5
#define GLOBAL_ADC_NTC_PIN         6
#define GLOBAL_ADC_POT_PIN         7

// 继电器与红外
#define GLOBAL_RELAY_CH1_PIN       17 // 灯光
#define GLOBAL_RELAY_CH2_PIN       18 // 插座
#define GLOBAL_RELAY_CH3_PIN       31 // 窗帘电机
#define GLOBAL_RELAY_CH4_PIN       32 // 电磁门锁
#define GLOBAL_IR_TX_PIN           47
#define GLOBAL_IR_RX_PIN           48

// EC11 旋转编码器
#define GLOBAL_EC11_A_PIN          2
#define GLOBAL_EC11_B_PIN          43
#define GLOBAL_EC11_SW_PIN         44

// 独立按键 (低有效)
#define GLOBAL_BTN_ROOM_1_PIN      26 // 客房: SOS
#define GLOBAL_BTN_ROOM_2_PIN      28 // 客房: 场景/睡眠
#define GLOBAL_BTN_FRONT_1_PIN     29 // 前台: 消音
#define GLOBAL_BTN_FRONT_2_PIN     30 // 前台: 广播
#define GLOBAL_BTN_FLOOR_1_PIN     19 // 楼控: 报警

// 其他输出
#define GLOBAL_BUZZER_PIN          38 // 蜂鸣器 (高有效)
#define GLOBAL_RGB_LED_PIN         27 // RGB 灯带

#ifdef __cplusplus
}
#endif
