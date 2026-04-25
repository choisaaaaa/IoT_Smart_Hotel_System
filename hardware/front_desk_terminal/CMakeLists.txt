cmake_minimum_required(VERSION 3.16)

# IDF 6：配网改用组件仓库 network_provisioning，排除已移除的旧 wifi_provisioning 占位
set(EXCLUDE_COMPONENTS wifi_provisioning)

set(EXTRA_COMPONENT_DIRS
    "../common_components/drivers"
    "../common_components/hal"
    "../common_components/services"
    "../common_components/config"
    "../common_components/crypto"
)

# ---------------------------------------------------------------------------
# 前台最小硬件：RC522 + 有源蜂鸣器 + 报警键（SOS）。无 OLED / EC11 / RGB / 继电器 / PTT / I2S 语音链。
# RC522 SPI：模块 SDA(NSS)=10、SCK=11、MOSI=12、MISO=13（与 global_config.h 一致）。
# ---------------------------------------------------------------------------
add_compile_definitions(
    FRONT_DESK_MINIMAL_HW=1

    GLOBAL_ADC_MQ2_PIN=-1
    GLOBAL_ADC_LDR_PIN=-1
    GLOBAL_ADC_NTC_PIN=-1
    GLOBAL_DHT11_PIN=-1
    GLOBAL_RD03_OT2_PIN=-1

    GLOBAL_RELAY_CH1_PIN=-1
    GLOBAL_RELAY_CH2_PIN=-1
    GLOBAL_RELAY_CH3_PIN=-1
    GLOBAL_RELAY_CH4_PIN=-1

    GLOBAL_RGB_R_PIN=-1
    GLOBAL_RGB_G_PIN=-1
    GLOBAL_RGB_B_PIN=-1

    GLOBAL_OLED_PIN_SDA=-1
    GLOBAL_OLED_PIN_SCL=-1

    GLOBAL_BUZZER_PIN=6
    # 有源蜂鸣器 SIG：1=高电平响/空闲为低(常见)；0=低电平响/空闲为高。上电后常响多因极性反了，改此宏后全量重编刷机
    GLOBAL_BUZZER_ACTIVE_HIGH=1

    GLOBAL_BTN_ROOM_1_PIN=3
    GLOBAL_BTN_ROOM_2_PIN=-1
    GLOBAL_BTN_FLOOR_1_PIN=-1
    GLOBAL_BTN_FRONT_1_PIN=-1
    GLOBAL_BTN_FRONT_2_PIN=-1

    GLOBAL_PTT_BTN_PIN=-1

    GLOBAL_EC11_A_PIN=-1
    GLOBAL_EC11_B_PIN=-1
    GLOBAL_EC11_SW_PIN=-1

    GLOBAL_I2S_BCLK_PIN=-1
    GLOBAL_I2S_WS_PIN=-1
    GLOBAL_I2S_DIN_PIN=-1
    GLOBAL_I2S_DOUT_PIN=-1
    GLOBAL_I2S_MIC_PDM_CLK_PIN=-1
)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(front_desk_terminal VERSION 1.4.0)
