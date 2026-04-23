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
#define GLOBAL_MQTT_BROKER_URI "mqtt://8.134.166.69:1883"

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
/** 客房上行 PCM（JSON+base64）：hotel/device/audio/uplink/<device_id> */
#define GLOBAL_TOPIC_DEVICE_AUDIO_UPLINK_PREFIX  "hotel/device/audio/uplink"
/** 下行播放同一 device_id：hotel/device/audio/downlink/<device_id> */
#define GLOBAL_TOPIC_DEVICE_AUDIO_DOWNLINK_PREFIX "hotel/device/audio/downlink"

// 房卡扇区 1 应用层密文默认 AES-128 密钥（32 个十六进制字符）。生产环境请在前台与客房 NVS
// 写入 HotelCard_AES128Hex（内容与本宏等长），勿长期使用公开默认值。
#define GLOBAL_CARD_AES128_HEX_DEFAULT "2B7E151628AED2A6ABF7158809CF4F3C"

// 开发阶段默认允许无签名上报；联调后切换为 1
#define GLOBAL_ENABLE_MESSAGE_SIGNATURE          0

// 驱动分层预开发：允许 mock 兜底，后续可逐模块切换为 0
#define GLOBAL_ENABLE_MOCK_NETWORK               0
#define GLOBAL_ENABLE_MOCK_SENSORS               0
#define GLOBAL_ENABLE_MOCK_AUDIO                 0
#define GLOBAL_ENABLE_MOCK_INFRARED              0
#define GLOBAL_ENABLE_MOCK_RC522                 0

// ==========================================
// 统一硬件引脚分配 (ESP32-S3)
// - 《01》《03》：单 PCB / 基线冻结表。
// - 开发板杜邦线原型：以 hardware/docs/22_ESP32-S3-N16R8开发板排针接线表_三端杜邦线版.md §4
//   与 hardware/docs/24_硬件杜邦线傻瓜接线教程_v1.0.md 第三部分「客房端」为准；与《03》不一致处见 22 标注列。
// - 本头为「三端共用」：GLOBAL_BTN_FRONT_* 仅对应前台端（24 §1.2）；客房端 GPIO5/6 在 22/24 中为继电器 IN3/IN4，
//   客房固件须在 CMake 中将 FRONT 两键置 -1，避免 hal_interactive 与 hal_actuators 抢同一脚。
// ==========================================

// 音频 — 客房实物为安信可 LMD2718+NS4168 一体模组（板载 LMD2718T PDM MEMS + NS4168 D 类功放）。
//   【SPK 路径】I2S0 标准模式（Philips），接 NS4168：
//     LRCLK→WS(GPIO42)、BCLK(GPIO41)、SDATA←MCU DOUT(GPIO40)；
//   【MIC 路径】I2S1 PDM RX 模式（LMD2718T 是单比特 PDM 麦，不是 I2S 麦，规格书明确）：
//     PDM_CLK 由 MCU 输出→MIC CLK(GPIO14，独立脚，不可与 BCLK 共用)；
//     PDM_DATA←MCU DIN(GPIO39)。
//   重要：MIC CLK 必须独立于 NS4168 BCLK，因为 PDM CLK 典型 2.048MHz 而 I2S BCLK 在 16-bit mono
//   slot 下是 fs×32=512kHz~1MHz，两者频率不同，共线会互相顶导致两边都出乱码。
#define GLOBAL_I2S_BCLK_PIN        41
#define GLOBAL_I2S_WS_PIN          42
#define GLOBAL_I2S_DIN_PIN         39  /* 兼容旧配置名：实际作为 MIC PDM DATA */
#define GLOBAL_I2S_DOUT_PIN        40
#define GLOBAL_I2S_MIC_PDM_CLK_PIN 7   /* MIC PDM CLK 独立脚（与 BCLK 频率不同，必须独占） */
#define GLOBAL_PTT_BTN_PIN         1  // 客房：接听/唤醒 Agent（杜邦线开发板，见 docs/22）

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

// 毫米波雷达：安信可 S3KM1110 等焊盘为 3V3/GND/OT1/RX/OT2（常见无模组侧 TX），
// 杜邦线基准为 OT2 数字输出接 MCU，与 driver_rd03_simple 一致。
#ifndef GLOBAL_RD03_OT2_PIN
#define GLOBAL_RD03_OT2_PIN        16
#endif
// 若使用带模组 TX/RX 的 UART 版本，与上项二选一（勿在同一 MCU 脚上同时接 OT2 与 UART RX）。
#define GLOBAL_UART_RD03_TX_PIN    15
#define GLOBAL_UART_RD03_RX_PIN    16

// ADC 采样 (传感器)
#ifndef GLOBAL_ADC_MQ2_PIN
#define GLOBAL_ADC_MQ2_PIN         4
#endif
#ifndef GLOBAL_ADC_LDR_PIN
#define GLOBAL_ADC_LDR_PIN         5
#endif
#ifndef GLOBAL_ADC_NTC_PIN
#define GLOBAL_ADC_NTC_PIN         6
#endif

// 楼控雨棚（SG90 舵机 + 雨量数字 DO）。未使用写 -1；DO 极性：多数 FC-37 类为「有雨拉低」→ ACTIVE_LOW=1
#ifndef GLOBAL_CANOPY_SERVO_PIN
#define GLOBAL_CANOPY_SERVO_PIN    (-1)
#endif
#ifndef GLOBAL_RAIN_SENSOR_DO_PIN
#define GLOBAL_RAIN_SENSOR_DO_PIN  (-1)
#endif
#ifndef GLOBAL_RAIN_SENSOR_ACTIVE_LOW
#define GLOBAL_RAIN_SENSOR_ACTIVE_LOW 1
#endif
#ifndef GLOBAL_CANOPY_ANGLE_RETRACT_DEG
#define GLOBAL_CANOPY_ANGLE_RETRACT_DEG 0
#endif
#ifndef GLOBAL_CANOPY_ANGLE_EXTEND_DEG
#define GLOBAL_CANOPY_ANGLE_EXTEND_DEG 180
#endif

// DHT11 单总线数据脚（可由终端工程通过编译宏覆盖）
#ifndef GLOBAL_DHT11_PIN
#define GLOBAL_DHT11_PIN           15
#endif
// 客房端 NVS：Floor_Sensor_Device_Id 与本层楼控 MQTT client_id/device_id 一致（如 floor_03），
// 用于订阅 hotel/device/data/*/floor_03 的 MQ2 与走廊 NTC，参与客房「三重与」疑似火灾判据。

// 继电器与红外
// 允许各终端工程通过编译宏覆盖默认引脚（如楼控单路继电器场景）
#ifndef GLOBAL_RELAY_CH1_PIN
#define GLOBAL_RELAY_CH1_PIN       17 // 灯光
#endif
#ifndef GLOBAL_RELAY_CH2_PIN
#define GLOBAL_RELAY_CH2_PIN       18 // 插座
#endif
#ifndef GLOBAL_RELAY_CH3_PIN
#define GLOBAL_RELAY_CH3_PIN       5 // 窗帘（杜邦线开发板适配；《03》PCB 为 GPIO31）
#endif
#ifndef GLOBAL_RELAY_CH4_PIN
#define GLOBAL_RELAY_CH4_PIN       6 // 门锁（杜邦线开发板适配；《03》PCB 为 GPIO32）
#endif
#define GLOBAL_IR_TX_PIN           47
#define GLOBAL_IR_RX_PIN           48

// EC11 旋转编码器（各终端可 CMake 覆盖；未用某脚时可 -1，且勿与继电器/按键同一脚复用）
#ifndef GLOBAL_EC11_A_PIN
#define GLOBAL_EC11_A_PIN          2
#endif
#ifndef GLOBAL_EC11_B_PIN
#define GLOBAL_EC11_B_PIN          38
#endif
#ifndef GLOBAL_EC11_SW_PIN
#define GLOBAL_EC11_SW_PIN         4
#endif

// 独立按键 (低有效)；各终端可在 CMake 中用 add_compile_definitions(...=-1) 关闭未接线槽位
#define GLOBAL_BTN_ROOM_1_PIN      14 // 客房: 报警/SOS（GPIO7 让位给 MIC PDM CLK）
#ifndef GLOBAL_BTN_ROOM_2_PIN
#define GLOBAL_BTN_ROOM_2_PIN      20 // 客房: 场景（可选；《03》PCB 为 GPIO28）
#endif
#ifndef GLOBAL_BTN_FRONT_1_PIN
#define GLOBAL_BTN_FRONT_1_PIN     5  // 仅前台杜邦线：消音（24 §1.2）；勿用于客房（客房 GPIO5=继电器 IN3）
#endif
#ifndef GLOBAL_BTN_FRONT_2_PIN
#define GLOBAL_BTN_FRONT_2_PIN     6  // 仅前台杜邦线：广播（24 §1.2）；勿用于客房（客房 GPIO6=继电器 IN4）
#endif
#ifndef GLOBAL_BTN_FLOOR_1_PIN
#define GLOBAL_BTN_FLOOR_1_PIN     19 // 《03》单 PCB 楼控报警；杜邦线楼控见 22 §3 为 GPIO18，由 floor_controller/CMake 覆盖
#endif

// 其他输出
#ifndef GLOBAL_BUZZER_PIN
#define GLOBAL_BUZZER_PIN          38 // 蜂鸣器 (高有效)
#endif
#define GLOBAL_RGB_LED_PIN         21 // RGB 灯带(可选)

#ifdef __cplusplus
}
#endif
