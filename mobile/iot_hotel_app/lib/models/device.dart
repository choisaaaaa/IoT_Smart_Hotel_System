import 'package:json_annotation/json_annotation.dart';

class Device {
  final int id;
  @JsonKey(name: 'device_name')
  final String deviceName;
  @JsonKey(name: 'device_type')
  final String deviceType;
  @JsonKey(name: 'device_code')
  final String deviceCode;
  @JsonKey(name: 'room_id')
  final int roomId;
  @JsonKey(name: 'hotel_id')
  final int hotelId;
  @JsonKey(name: 'is_online')
  final bool isOnline;
  @JsonKey(name: 'status')
  final String status;
  @JsonKey(name: 'last_heartbeat')
  final DateTime? lastHeartbeat;
  Map<String, dynamic>? properties;

  Device({
    required this.id,
    required this.deviceName,
    this.deviceType = 'sensor',
    required this.deviceCode,
    this.roomId = 0,
    this.hotelId = 1,
    this.isOnline = false,
    this.status = 'offline',
    this.lastHeartbeat,
    this.properties,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] ?? 0, deviceName: json['device_name'] ?? '', deviceType: json['device_type'] ?? 'sensor',
        deviceCode: json['device_code'] ?? '', roomId: json['room_id'] ?? 0, hotelId: json['hotel_id'] ?? 1,
        isOnline: json['is_online'] ?? false, status: json['status'] ?? 'offline',
        lastHeartbeat: json['last_heartbeat'] != null ? DateTime.parse(json['last_heartbeat']) : null,
        properties: json['properties'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'device_name': deviceName, 'device_type': deviceType,
    'device_code': deviceCode, 'room_id': roomId, 'hotel_id': hotelId, 'is_online': isOnline,
    'status': status, 'last_heartbeat': lastHeartbeat?.toIso8601String(), 'properties': properties};

  String get typeIcon {
    switch (deviceType) { case 'light': return '💡'; case 'ac': return '❄️'; case 'curtain': return '🪟';
      case 'tv': return '📺'; case 'lock': return '🔒'; case 'sensor': return '🌡️'; default: return '📡'; }
  }

  String get typeName {
    const map = {'light': '灯光', 'ac': '空调', 'curtain': '窗帘', 'tv': '电视', 'lock': '门锁', 'sensor': '传感器'};
    return map[deviceType] ?? deviceType;
  }
}
