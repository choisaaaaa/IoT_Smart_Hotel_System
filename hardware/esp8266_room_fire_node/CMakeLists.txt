# ESP8266 客房火灾辅助节点（热敏 + MQTT 订阅楼控 MQ2）
#
# 本工程使用 Espressif ESP8266 RTOS SDK（与 ESP32 的 ESP-IDF 同源工具链风格：CMake + idf.py），
# 请勿在 ESP32 的 IDF_PATH 下编译。请安装/解压 ESP8266_RTOS_SDK，并执行例如：
#   set IDF_PATH=D:\path\to\ESP8266_RTOS_SDK
#   cd hardware\esp8266_room_fire_node
#   idf.py set-target esp8266
#   idf.py menuconfig   # 配置 WiFi / MQTT / 楼控 device_id 等（或使用 NVS 烧录参数）
#   idf.py build flash monitor
#
cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(esp8266_room_fire_node)
