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

# 楼控端：单路继电器 + 走廊传感器，并合并原「客房端」环境采集脚位（杜邦一体板）。
#
# ┌─────────────────┬──────┬──────────────────────────────────────────────┐
# │ 功能            │ GPIO │ 说明                                         │
# ├─────────────────┼──────┼──────────────────────────────────────────────┤
# │ 继电器 CH1      │  7   │ 走廊灯 / 代客单路（低有效吸合，与现固件一致）│
# │ MQ-2 模拟输出   │  1   │ 烟雾 ADC（与原楼控一致）                     │
# │ 光敏 LDR        │  2   │ 光照 ADC（与原楼控一致）                     │
# │ DHT11 数据线    │ 20   │ 与原客房 room_terminal 一致；旧楼控 GPIO4 空 │
# │ NTC 10k 分压    │ 19   │ 与原客房「房内 NTC」一致，参与火灾温升判据   │
# │ 楼控报警按键    │ 18   │ BTN_FLOOR_1（低有效）                        │
# │ RD-03 OT2 数字  │ 16   │ 毫米波「有人」输出→MCU（高=有人，driver_rd03_simple）│
# └─────────────────┴──────┴──────────────────────────────────────────────┘
# 若使用 RD-03 UART 版（接 MCU TX/RX），勿与本项 OT2 同脚复用；未接雷达时 GLOBAL_RD03_OT2_PIN=-1。
# 未用/禁用：CH2–CH4、雨棚等一律 -1。
# 重要：GPIO19/20 在部分 N16R8 板占用 USB-Serial-JTAG；烧录/串口请用 CH343 口（常见 GPIO43/44），
#       与客房文档 24/CMake 说明一致。
# 蜂鸣器：global_config 默认 GPIO38；本板若不接蜂鸣器可取消下行注释改为 -1。
# add_compile_definitions(GLOBAL_BUZZER_PIN=-1)
add_compile_definitions(
    GLOBAL_RELAY_CH1_PIN=7
    GLOBAL_RELAY_CH2_PIN=-1
    GLOBAL_RELAY_CH3_PIN=-1
    GLOBAL_RELAY_CH4_PIN=-1
    GLOBAL_RD03_OT2_PIN=16
    GLOBAL_DHT11_PIN=20
    GLOBAL_ADC_MQ2_PIN=1
    GLOBAL_ADC_NTC_PIN=19
    GLOBAL_ADC_LDR_PIN=2
    GLOBAL_BTN_FLOOR_1_PIN=18
)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(floor_controller)
