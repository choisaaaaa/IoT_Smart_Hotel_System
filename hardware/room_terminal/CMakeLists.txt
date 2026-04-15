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
)

# Include the main ESP-IDF build system script
include($ENV{IDF_PATH}/tools/cmake/project.cmake)

# Set the name of your project
project(room_terminal)
