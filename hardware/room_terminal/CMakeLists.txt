# The following lines of boilerplate have to be in your project's
# CMakeLists.txt.

# This line tells the ESP-IDF build system the minimum CMake version
cmake_minimum_required(VERSION 3.16)

# IDF 6：配网改用组件仓库 network_provisioning，排除已移除的旧 wifi_provisioning 占位
set(EXCLUDE_COMPONENTS wifi_provisioning)

# 引入我们刚才创建的“高复用组件池”
set(EXTRA_COMPONENT_DIRS
    "../common_components/drivers"
    "../common_components/hal"
    "../common_components/services"
    "../common_components/config"
    "../common_components/crypto"
)

# 客房端：与 hardware/docs/24_硬件杜邦线傻瓜接线教程_v1.0.md 第三部分、docs/22 §4 客房表一致。
# - 继电器 IN3/IN4 → GPIO5/6（24 §3.2 第二批）；EC11 SW→GPIO4；与《03》无关。
# - hal_interactive 六键槽里含「前台键」宏名 GLOBAL_BTN_FRONT_*，默认值为 5/6，会与客房继电器冲突，
#   故客房工程将 FRONT 两键置 -1（不是改硬件，而是禁止把 5/6 再配置成输入键）。
# - 场景键由 EC11 旋钮承担，故 GLOBAL_BTN_ROOM_2_PIN=-1；原场景键脚 GPIO20 改接 DHT11 数据线。
# - 房内 NTC：GPIO14 在部分开发板未引出；默认改 GPIO19（客房已禁用楼道键 GLOBAL_BTN_FLOOR_1_PIN=-1），
#   与继电器5/6、DHT20 不冲突；火灾判据仍用楼控 MQTT 的 MQ2+走廊 NTC + 房内 NTC（三重与）。
# - 客房板不接本地 MQ2/光敏：二者均 -1；无蜂鸣器：GLOBAL_BUZZER_PIN=-1。
add_compile_definitions(
    GLOBAL_ADC_MQ2_PIN=-1
    GLOBAL_ADC_LDR_PIN=-1
    GLOBAL_ADC_NTC_PIN=19
    GLOBAL_BUZZER_PIN=-1
    GLOBAL_BTN_ROOM_2_PIN=-1
    GLOBAL_DHT11_PIN=20
    GLOBAL_BTN_FRONT_1_PIN=-1
    GLOBAL_BTN_FRONT_2_PIN=-1
    GLOBAL_BTN_FLOOR_1_PIN=-1
)

# Include the main ESP-IDF build system script
include($ENV{IDF_PATH}/tools/cmake/project.cmake)

# Set the name of your project
project(room_terminal)
