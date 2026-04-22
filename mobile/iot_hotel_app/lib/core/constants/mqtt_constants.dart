class MqttConstants {
  static String get brokerHost {
    const String envHost = String.fromEnvironment('MQTT_BROKER_HOST');
    if (envHost.isNotEmpty) {
      return envHost;
    }

    if (const bool.fromEnvironment('dart.vm.product') == false) {
      return 'localhost';
    }

    return '8.134.166.69';
  }

  static int get brokerPort {
    const String envPort = String.fromEnvironment('MQTT_BROKER_PORT');
    if (envPort.isNotEmpty) {
      return int.tryParse(envPort) ?? 1883;
    }

    if (const bool.fromEnvironment('dart.vm.product') == false) {
      return 1883;
    }

    return 1883;
  }

  static String get username {
    const String envUsername = String.fromEnvironment('MQTT_USERNAME');
    return envUsername;
  }

  static String get password {
    const String envPassword = String.fromEnvironment('MQTT_PASSWORD');
    return envPassword;
  }

  static const String clientIdPrefix = 'iot_hotel_app_';
  static const int keepAlive = 60;
  static const int connectTimeout = 10000;

  // ===== 统一格式主题（与后端 mqtt.service.ts 对齐） =====

  // 设备状态上报: hotel/device/status/{type}/{id}
  static String deviceStatusTopic(String type, String id) =>
      'hotel/device/status/$type/$id';

  // 设备状态通配: hotel/device/status/+/+
  static const String deviceStatusWildcard = 'hotel/device/status/+/+';

  // 传感器数据上报: hotel/device/data/{type}
  static String sensorDataTopic(String type) => 'hotel/device/data/$type';

  // 传感器数据通配: hotel/device/data/+
  static const String sensorDataWildcard = 'hotel/device/data/+';

  // 指令执行结果: hotel/device/command/result
  static const String commandResultTopic = 'hotel/device/command/result';

  // 安防事件: hotel/device/security/event
  static const String securityEventTopic = 'hotel/device/security/event';

  // 下发控制指令: hotel/device/command/{type}/{deviceId}
  static String deviceCommandTopic(String type, String deviceId) =>
      'hotel/device/command/$type/$deviceId';

  // WebRTC初始化配置: hotel/device/config/room/{deviceId}
  static String webrtcConfigTopic(String deviceId) =>
      'hotel/device/config/room/$deviceId';

  // WebRTC信令: hotel/device/signal/room/{deviceId}
  static String webrtcSignalTopic(String deviceId) =>
      'hotel/device/signal/room/$deviceId';

  // 通话上行: hotel/device/call/{callId}/up
  static String callUpTopic(String callId) => 'hotel/device/call/$callId/up';

  // 通话下行: hotel/device/call/{callId}/down
  static String callDownTopic(String callId) =>
      'hotel/device/call/$callId/down';

  // AI语音请求: hotel/device/ai/request/{roomId}
  static String aiRequestTopic(String roomId) =>
      'hotel/device/ai/request/$roomId';

  // AI回复下发: hotel/ai/response/room/{roomId}
  static String aiResponseTopic(String roomId) =>
      'hotel/ai/response/room/$roomId';

  // 送物服务请求: hotel/device/service/delivery/{roomId}
  static String deliveryServiceTopic(String roomId) =>
      'hotel/device/service/delivery/$roomId';

  // 维修服务请求: hotel/device/service/maintenance/{roomId}
  static String maintenanceServiceTopic(String roomId) =>
      'hotel/device/service/maintenance/$roomId';

  // 服务状态: hotel/device/service/+/status
  static const String serviceStatusWildcard =
      'hotel/device/service/+/status';

  // 服务响应: hotel/service/response/{roomNumber}
  static String serviceResponseTopic(String roomNumber) =>
      'hotel/service/response/$roomNumber';

  // 前台通知广播: hotel/{hotelId}/reception/announce
  static String receptionAnnounceTopic(int hotelId) =>
      'hotel/$hotelId/reception/announce';

  // 全局报警: hotel/security/global_alarm
  static const String globalAlarmTopic = 'hotel/security/global_alarm';

  // 场景控制: hotel/room/{roomId}/scene
  static String sceneTopic(String roomId) => 'hotel/room/$roomId/scene';

  // 场景执行结果: hotel/room/{roomId}/scene/result
  static String sceneResultTopic(String roomId) =>
      'hotel/room/$roomId/scene/result';

  // 语音数据: hotel/device/voice/{deviceId}/+
  static String voiceDataTopic(String deviceId) =>
      'hotel/device/voice/$deviceId/+';

  // ===== 兼容旧方法（逐步废弃，保留向后兼容） =====
  @Deprecated('Use deviceStatusTopic(type, id) instead')
  static String deviceStatusTopicLegacy(
          int hotelId, int roomId, String deviceId) =>
      'hotel/$hotelId/room/$roomId/device/$deviceId/status';

  @Deprecated('Use deviceCommandTopic(type, deviceId) instead')
  static String deviceControlTopicLegacy(
          int hotelId, int roomId, String deviceId) =>
      'hotel/$hotelId/room/$roomId/device/$deviceId/control';

  @Deprecated('Use sensorDataTopic(type) instead')
  static String sensorDataTopicLegacy(
          int hotelId, int roomId, String sensorType) =>
      'hotel/$hotelId/room/$roomId/sensor/$sensorType/data';

  @Deprecated('Use globalAlarmTopic instead')
  static String alarmTopic(int hotelId) => 'hotel/$hotelId/alarm';

  @Deprecated('Use deviceStatusWildcard instead')
  static String deviceWildcardStatus(int hotelId) =>
      'hotel/$hotelId/+/device/+/status';
}
