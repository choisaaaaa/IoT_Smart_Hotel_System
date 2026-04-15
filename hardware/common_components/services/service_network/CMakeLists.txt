# espressif__network_provisioning：SoftAP 配网头文件与链接（IDF 6 已移除内置 wifi_provisioning）
# 依赖必须无条件声明：解析本 CMakeLists 时 Kconfig 可能尚未注入 CONFIG_*，条件 REQUIRES 会导致找不到头文件
set(service_network_requires
    nvs_flash
    freertos
    esp_netif
    lwip
    esp_wifi
    esp_event
    protocomm
    espressif__network_provisioning)

idf_component_register(SRCS "service_network.c"
                    INCLUDE_DIRS "include"
                    REQUIRES ${service_network_requires})
