#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// ==========================================
// 全局网络与后台服务器配置 (Global Network Config)
// 统一在此处修改，客房端、前台端、楼控端一键生效
// ==========================================

// 后台 MQTT 服务器地址配置
// 开发环境: mqtt://192.168.1.100:1883
// 云服务器: mqtt://your-domain.com:1883 或 mqtt://your-server-ip:1883
// 生产环境(推荐): mqtts://your-domain.com:8883 (启用TLS加密)
#define GLOBAL_MQTT_BROKER_URI "mqtt://192.168.1.100:1883"

// 默认配网 AP 热点名称前缀
#define GLOBAL_WIFI_DEFAULT_SSID "SmartHotel_AP"

#ifdef __cplusplus
}
#endif
