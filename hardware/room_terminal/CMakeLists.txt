# The following lines of boilerplate have to be in your project's
# CMakeLists.txt.

# This line tells the ESP-IDF build system the minimum CMake version
cmake_minimum_required(VERSION 3.16)

# 引入我们刚才创建的“高复用组件池”
set(EXTRA_COMPONENT_DIRS "../common_components")

# Include the main ESP-IDF build system script
include($ENV{IDF_PATH}/tools/cmake/project.cmake)

# Set the name of your project
project(room_terminal)
