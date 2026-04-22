class MqttConstants {
  // 从环境变量或构建配置获取MQTT服务器配置
  static String get brokerHost {
    // 灵活配置方案
    // 方案1: 优先使用环境变量
    const String envHost = String.fromEnvironment('MQTT_BROKER_HOST');
    if (envHost.isNotEmpty) {
      return envHost;
    }
    
    // 方案2: 开发环境默认值
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      return 'localhost';
    }
    
    // 方案3: 生产环境默认值（打包到手机端使用）
    return '8.134.166.69';
  }
  
  static int get brokerPort {
    const String envPort = String.fromEnvironment('MQTT_BROKER_PORT');
    if (envPort.isNotEmpty) {
      return int.tryParse(envPort) ?? 1883;
    }
    
    // 开发环境默认值（仅在调试模式下使用）
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

  static String deviceStatusTopic(int hotelId, int roomId, String deviceId) =>
      'hotel/$hotelId/room/$roomId/device/$deviceId/status';

  static String deviceControlTopic(int hotelId, int roomId, String deviceId) =>
      'hotel/$hotelId/room/$roomId/device/$deviceId/control';

  static String sensorDataTopic(int hotelId, int roomId, String sensorType) =>
      'hotel/$hotelId/room/$roomId/sensor/$sensorType/data';

  static String alarmTopic(int hotelId) => 'hotel/$hotelId/alarm';

  static String deviceWildcardStatus(int hotelId) =>
      'hotel/$hotelId/+/device/+/status';
}
