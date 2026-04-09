import 'package:json_annotation/json_annotation.dart';

class Device {
  final int id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'device_type')
  final String deviceType;
  @JsonKey(name: 'device_name')
  final String deviceName;
  @JsonKey(name: 'device_key')
  final String deviceKey;
  @JsonKey(name: 'device_status')
  final String deviceStatus;
  @JsonKey(name: 'firmware_version')
  final String? firmwareVersion;
  @JsonKey(name: 'last_seen')
  final DateTime? lastSeen;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  Device({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    this.deviceType = 'sensor',
    required this.deviceKey,
    this.deviceStatus = 'offline',
    this.firmwareVersion,
    this.lastSeen,
    this.createdAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] ?? 0,
        deviceId: json['device_id'] ?? '',
        deviceName: json['device_name'] ?? '',
        deviceType: json['device_type'] ?? 'sensor',
        deviceKey: json['device_key'] ?? '',
        deviceStatus: json['device_status'] ?? json['status'] ?? 'offline',
        firmwareVersion: json['firmware_version'],
        lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'device_id': deviceId, 'device_name': deviceName, 'device_type': deviceType,
        'device_key': deviceKey, 'device_status': deviceStatus, 'firmware_version': firmwareVersion,
        'last_seen': lastSeen?.toIso8601String(), 'created_at': createdAt?.toIso8601String(),
      };

  bool get isOnline => deviceStatus == 'online';

  String get typeIcon {
    switch (deviceType) {
      case 'light': return '💡';
      case 'ac': return '❄️';
      case 'curtain': return '🪟';
      case 'tv': return '📺';
      case 'lock': return '🔒';
      case 'sensor': return '🌡️';
      default: return '📡';
    }
  }

  String get typeName {
    const map = {'light': '灯光', 'ac': '空调', 'curtain': '窗帘', 'tv': '电视', 'lock': '门锁', 'sensor': '传感器'};
    return map[deviceType] ?? deviceType;
  }
}
