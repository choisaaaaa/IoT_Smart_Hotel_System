cmake_minimum_required(VERSION 3.16)

# IDF 6：配网改用组件仓库 network_provisioning，排除已移除的旧 wifi_provisioning 占位
set(EXCLUDE_COMPONENTS wifi_provisioning)

# 将外部公共组件池路径映射至编译配置中
set(EXTRA_COMPONENT_DIRS
    "../common_components/drivers"
    "../common_components/hal"
    "../common_components/services"
    "../common_components/config"
    "../common_components/crypto"
)

# 前台端：音频（I2S）、EC11、PTT、RC522；并接入「代客房」单路继电器 + 三线 RGB（与客房杜邦方案一致类）。
# 继电器 CH1=GPIO17；RGB 共阳 R=5 G=6 B=8（勿与 SPI10–13、I2S39–42、PDM7、EC11 2/4/38、PTT1 冲突）。
add_compile_definitions(
    # 禁用传感器
    GLOBAL_ADC_MQ2_PIN=-1
    GLOBAL_ADC_LDR_PIN=-1
    GLOBAL_ADC_NTC_PIN=-1
    GLOBAL_DHT11_PIN=-1
    GLOBAL_RD03_OT2_PIN=-1
    
    # 单路继电器（代客房灯/锁演示，MQTT light_on/light_off/door_unlock 与楼控代客一致）
    GLOBAL_RELAY_CH1_PIN=17
    GLOBAL_RELAY_CH2_PIN=-1
    GLOBAL_RELAY_CH3_PIN=-1
    GLOBAL_RELAY_CH4_PIN=-1

    # 共阳三线 RGB（hal_interactive_set_led_color）
    GLOBAL_RGB_R_PIN=5
    GLOBAL_RGB_G_PIN=6
    GLOBAL_RGB_B_PIN=8
    GLOBAL_RGB_COMMON_ANODE=1
    
    # 禁用蜂鸣器（改用音频播放）
    GLOBAL_BUZZER_PIN=-1
    
    # 禁用客房/楼控按键
    GLOBAL_BTN_ROOM_1_PIN=-1
    GLOBAL_BTN_ROOM_2_PIN=-1
    GLOBAL_BTN_FLOOR_1_PIN=-1
    
    # 前台清除/广播物理键已移除，不占 GPIO
    GLOBAL_BTN_FRONT_1_PIN=-1
    GLOBAL_BTN_FRONT_2_PIN=-1
    
    # PTT（Agent）：GPIO1，按键一脚接 GPIO1、一脚接 GND，内部上拉（与客房端逻辑一致）
    GLOBAL_PTT_BTN_PIN=1
    
    # 配置 EC11 旋钮引脚 (A=2, B=38, SW=4)
    GLOBAL_EC11_A_PIN=2
    GLOBAL_EC11_B_PIN=38
    GLOBAL_EC11_SW_PIN=4
    
    # I2S 音频引脚配置 (BCLK=41, WS=42, DIN=39, DOUT=40, PDM_CLK=7)
    GLOBAL_I2S_BCLK_PIN=41
    GLOBAL_I2S_WS_PIN=42
    GLOBAL_I2S_DIN_PIN=39
    GLOBAL_I2S_DOUT_PIN=40
    GLOBAL_I2S_MIC_PDM_CLK_PIN=7
)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(front_desk_terminal VERSION 1.2.0)
