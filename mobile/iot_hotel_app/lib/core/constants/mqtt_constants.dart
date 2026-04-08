class MqttConstants {
  static const String brokerHost = '8.134.166.69';
  static const int brokerPort = 1883;
  static const String username = '';
  static const String password = '';
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
