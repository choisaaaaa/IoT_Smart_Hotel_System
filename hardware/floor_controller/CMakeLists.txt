cmake_minimum_required(VERSION 3.16)

# 将外部公共组件池路径映射至编译配置中
set(EXTRA_COMPONENT_DIRS "../common_components")

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(floor_controller)
