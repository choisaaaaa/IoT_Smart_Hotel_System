cmake_minimum_required(VERSION 3.16)

# IDF 6：配网改用组件仓库 network_provisioning，排除已移除的旧 wifi_provisioning 占位
set(EXCLUDE_COMPONENTS wifi_provisioning)

# 将外部公共组件池路径映射至编译配置中
set(EXTRA_COMPONENT_DIRS
    "../common_components/drivers"
    "../common_components/hal"
    "../common_components/services"
    "../common_components/config"
)

# 楼控端当前硬件为单路继电器：CH1=GPIO7，其他通道禁用
add_compile_definitions(
    GLOBAL_RELAY_CH1_PIN=7
    GLOBAL_RELAY_CH2_PIN=-1
    GLOBAL_RELAY_CH3_PIN=-1
    GLOBAL_RELAY_CH4_PIN=-1
    GLOBAL_RD03_OT2_PIN=-1
    GLOBAL_DHT11_PIN=4
    GLOBAL_ADC_MQ2_PIN=1
    GLOBAL_BTN_FLOOR_1_PIN=18
)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(floor_controller)
