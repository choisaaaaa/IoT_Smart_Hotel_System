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

# 前台端：接入音频（I2S）、EC11 旋钮和 Agent 按钮。
# 禁用不需要的引脚（如继电器、传感器等），避免冲突。
add_compile_definitions(
    # 禁用传感器
    GLOBAL_ADC_MQ2_PIN=-1
    GLOBAL_ADC_LDR_PIN=-1
    GLOBAL_ADC_NTC_PIN=-1
    GLOBAL_DHT11_PIN=-1
    GLOBAL_RD03_OT2_PIN=-1
    
    # 禁用继电器
    GLOBAL_RELAY_CH1_PIN=-1
    GLOBAL_RELAY_CH2_PIN=-1
    GLOBAL_RELAY_CH3_PIN=-1
    GLOBAL_RELAY_CH4_PIN=-1
    
    # 禁用蜂鸣器（改用音频播放）
    GLOBAL_BUZZER_PIN=-1
    
    # 禁用客房/楼控按键
    GLOBAL_BTN_ROOM_1_PIN=-1
    GLOBAL_BTN_ROOM_2_PIN=-1
    GLOBAL_BTN_FLOOR_1_PIN=-1
    
    # 前台按键（已在代码中注释掉，这里也置为 -1 释放引脚）
    GLOBAL_BTN_FRONT_1_PIN=-1
    GLOBAL_BTN_FRONT_2_PIN=-1
    
    # 开启 PTT (Agent) 按钮，使用 GPIO1
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
