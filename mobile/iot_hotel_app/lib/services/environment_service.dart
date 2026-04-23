import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/type_utils.dart';

class EnvironmentService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> getEnvironmentData({
    int? floorId,
    int? roomId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (roomId != null) queryParams['room_id'] = roomId;
      if (floorId != null) queryParams['floor_id'] = floorId;
      if (status != null) queryParams['status'] = status;

      final response = await _dioClient.get(
        ApiConstants.environment,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return ApiResult.success(data);
        }
        return ApiResult.success({'list': [], 'total': 0});
      }
      return ApiResult.failure(response.data['message'] ?? '获取环境数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getEnvironmentHistory({int? roomId, int? hours}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (roomId != null) queryParams['room_id'] = roomId;

      final now = DateTime.now();
      final startDate = now.subtract(Duration(hours: hours ?? 24));
      queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      queryParams['end_date'] = now.toIso8601String().split('T')[0];
      queryParams['group_by'] = 'day';

      final response = await _dioClient.get(
        '${ApiConstants.energy}/consumption',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取环境历史失败');
    } catch (e) {
      return ApiResult.failure('网络错误�?e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getFireAlarms({
    String? status,
    String? severity,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      queryParams['pageSize'] = limit ?? 50;
      if (status != null) {
        if (status == 'active') {
          queryParams['status'] = 'pending';
        } else if (status == 'acknowledged') {
          queryParams['status'] = 'processing';
        } else {
          queryParams['status'] = status;
        }
      }
      if (severity != null) queryParams['alarm_level'] = severity;

      final response = await _dioClient.get(
        ApiConstants.deviceAlarms,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final data = response.data['data'] as Map<String, dynamic>;
        final List<dynamic> alarmList = List<dynamic>.from(data['list'] ?? []);

        final mappedAlarms = alarmList.map((alarm) {
          final alarmStatus = alarm['status'] ?? 'pending';
          String mappedStatus;
          switch (alarmStatus) {
            case 'pending':
              mappedStatus = 'active';
              break;
            case 'processing':
              mappedStatus = 'acknowledged';
              break;
            case 'resolved':
              mappedStatus = 'resolved';
              break;
            case 'ignored':
              mappedStatus = 'false_alarm';
              break;
            default:
              mappedStatus = alarmStatus;
          }

          String alarmType = alarm['alarm_type'] ?? 'unknown';
          String mappedAlarmType;
          switch (alarmType) {
            case 'smoke':
            case 'fire':
              mappedAlarmType = 'smoke';
              break;
            case 'temperature':
            case 'overheat':
              mappedAlarmType = 'temperature';
              break;
            case 'co':
            case 'gas':
              mappedAlarmType = 'co';
              break;
            default:
              mappedAlarmType = alarmType;
          }

          return {
            'id': alarm['id'],
            'room_id': alarm['room_id'],
            'room_number': alarm['room_number'] ?? alarm['room_id']?.toString() ?? '-',
            'alarm_type': mappedAlarmType,
            'severity': alarm['alarm_level'] ?? 'warning',
            'value': alarm['sensor_value'] ?? 0,
            'threshold': alarm['threshold'] ?? 0,
            'triggered_at': alarm['created_at'] ?? '',
            'resolved_at': alarm['handled_at'],
            'status': mappedStatus,
            'handled_by': alarm['handled_by']?.toString(),
            'description': alarm['alarm_content'] ?? alarm['alarm_type'] ?? '设备告警',
          };
        }).toList();

        final activeCount = mappedAlarms.where((a) => a['status'] == 'active').length;
        final acknowledgedCount = mappedAlarms.where((a) => a['status'] == 'acknowledged').length;
        final resolvedCount = mappedAlarms.where((a) => a['status'] == 'resolved').length;
        final falseAlarmCount = mappedAlarms.where((a) => a['status'] == 'false_alarm').length;

        return ApiResult.success({
          'alarms': mappedAlarms,
          'total': data['pagination']?['total'] ?? mappedAlarms.length,
          'summary': {
            'active_count': activeCount,
            'acknowledged_count': acknowledgedCount,
            'resolved_today': resolvedCount,
            'false_alarm_count': falseAlarmCount,
          },
        });
      }
      return ApiResult.failure(response.data['message'] ?? '获取火警记录失败');
    } catch (e) {
      return ApiResult.failure('网络错误�?e');
    }
  }

  Future<ApiResult<void>> acknowledgeAlarm(int alarmId, {String? handler, String? notes}) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.deviceAlarms}/$alarmId/handle',
        data: {
          'status': 'resolved',
          if (handler != null) 'handled_by': handler,
          if (notes != null) 'handle_remark': notes,
        },
      );
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '确认火警失败');
    } catch (e) {
      return ApiResult.failure('网络错误�?e');
    }
  }

  Future<ApiResult<void>> resolveAlarm(int alarmId, {String? resolution, String? handler}) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.deviceAlarms}/$alarmId/handle',
        data: {
          'status': 'resolved',
          if (resolution != null) 'handle_remark': resolution,
        },
      );
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '解决火警失败');
    } catch (e) {
      return ApiResult.failure('网络错误�?e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getRoomDevices({int? roomId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (roomId != null) queryParams['room_id'] = roomId;

      final response = await _dioClient.get(
        ApiConstants.devices,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final data = response.data['data'];
        List<dynamic> deviceList = [];
        if (data is List) {
          deviceList = List<dynamic>.from(data);
        } else if (data is Map && data.containsKey('list')) {
          deviceList = List<dynamic>.from(data['list'] ?? []);
        } else if (data is Map && data.containsKey('devices')) {
          deviceList = List<dynamic>.from(data['devices'] ?? []);
        }

        final onlineCount = deviceList.where((d) =>
            d['device_status'] == 'online' || d['status'] == 'online').length;
        final offlineCount = deviceList.where((d) =>
            d['device_status'] == 'offline' || d['status'] == 'offline').length;
        final errorCount = deviceList.where((d) =>
            d['device_status'] == 'error' || d['status'] == 'error').length;
        final runningCount = deviceList.where((d) =>
            d['device_status'] == 'on' || d['status'] == 'on').length;

        return ApiResult.success({
          'devices': deviceList,
          'total': deviceList.length,
          'summary': {
            'online_count': onlineCount,
            'offline_count': offlineCount,
            'error_count': errorCount,
            'running_count': runningCount,
            'total_devices': deviceList.length,
            'online_rate': deviceList.isNotEmpty
                ? (onlineCount / deviceList.length * 100).round()
                : 0,
          },
        });
      }
      return ApiResult.failure(response.data['message'] ?? '获取房间设备失败');
    } catch (e) {
      return ApiResult.failure('网络错误�?e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> controlDevice(String deviceId, {
    required String action,
    double? value,
  }) async {
    try {
      final int deviceIdInt = int.tryParse(deviceId) ?? 0;
      String commandType = action;
      String commandValue = value?.toString() ?? '';

      switch (action) {
        case 'toggle':
          commandType = 'toggle';
          commandValue = value != null ? (value > 0 ? 'on' : 'off') : 'toggle';
          break;
        case 'temperature':
          commandType = 'temperature';
          commandValue = value?.toString() ?? '24';
          break;
        case 'brightness':
          commandType = 'brightness';
          commandValue = value?.toInt().toString() ?? '100';
          break;
        case 'position':
          commandType = 'position';
          commandValue = value?.toInt().toString() ?? '50';
          break;
      }

      final response = await _dioClient.post(
        '${ApiConstants.devices}/$deviceIdInt/command',
        data: {
          'command_type': commandType,
          'command_value': commandValue,
        },
      );
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>? ?? {});
      }
      return ApiResult.failure(response.data['message'] ?? '控制设备失败');
    } catch (e) {
      return ApiResult.failure('网络错误�?e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getEnergyConsumption({int? roomId, String? period}) async {
    try {
      final now = DateTime.now();
      String startDate;
      String endDate = now.toIso8601String().split('T')[0];

      switch (period ?? 'today') {
        case 'today':
          startDate = endDate;
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
          break;
        default:
          startDate = endDate;
      }

      final queryParams = <String, dynamic>{
        'start_date': startDate,
        'end_date': endDate,
        'group_by': 'day',
      };
      if (roomId != null) queryParams['room_id'] = roomId;

      final results = await Future.wait([
        _dioClient.get('${ApiConstants.energy}/consumption', queryParameters: queryParams),
        _dioClient.get('${ApiConstants.energy}/stats', queryParameters: {
          'start_date': startDate,
          'end_date': endDate,
        }),
      ]);

      Map<String, dynamic> consumptionData = {};
      Map<String, dynamic> statsData = {};

      if (results[0].statusCode == 200 && results[0].data['code'] == 200) {
        consumptionData = results[0].data['data'] as Map<String, dynamic>;
      }

      if (results[1].statusCode == 200 && results[1].data['code'] == 200) {
        statsData = results[1].data['data'] as Map<String, dynamic>;
      }

      final totalToday = (statsData['total'] as num?)?.toDouble() ?? 0;
      final trend = statsData['trend'] as List<dynamic>? ?? [];

      double yesterdayTotal = 0;
      if (trend.length >= 2) {
        yesterdayTotal = (trend[trend.length - 2]['value'] as num?)?.toDouble() ?? 0;
      }

      final savingsRate = yesterdayTotal > 0
          ? ((yesterdayTotal - totalToday) / yesterdayTotal * 100)
          : 0.0;

      return ApiResult.success({
        'consumption': consumptionData['data'] ?? [],
        'total': consumptionData['total_consumption'] ?? 0,
        'summary': {
          'total_today_kwh': totalToday,
          'total_yesterday_kwh': yesterdayTotal,
          'total_month_kwh': totalToday,
          'savings_rate': savingsRate,
          'estimated_monthly_cost': totalToday * 0.85,
          'most_efficient_room': '-',
          'least_efficient_room': '-',
        },
        'trend': trend,
      });
    } catch (e) {
      return ApiResult.failure('网络错误�?e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getEventLogs({
    String? eventType,
    String? severity,
    int? limit,
  }) async {
    try {
      final alarmParams = <String, dynamic>{
        'pageSize': limit ?? 100,
      };
      if (severity != null) alarmParams['alarm_level'] = severity;

      final alarmResponse = await _dioClient.get(
        ApiConstants.deviceAlarms,
        queryParameters: alarmParams,
      );

      List<dynamic> allLogs = [];

      if (alarmResponse.statusCode == 200 && alarmResponse.data['code'] == 200) {
        final alarmData = alarmResponse.data['data'] as Map<String, dynamic>;
        final List<dynamic> alarmList = List<dynamic>.from(alarmData['list'] ?? []);

        for (final alarm in alarmList) {
          String mappedEventType;
          switch (alarm['alarm_type']?.toString()) {
            case 'smoke':
            case 'fire':
              mappedEventType = 'fire_alarm';
              break;
            case 'temperature':
            case 'overheat':
              mappedEventType = 'environment_warning';
              break;
            case 'offline':
            case 'device_error':
              mappedEventType = 'device_error';
              break;
            default:
              mappedEventType = 'device_error';
          }

          String mappedSeverity;
          switch (alarm['alarm_level']?.toString()) {
            case 'emergency':
            case 'critical':
              mappedSeverity = 'critical';
              break;
            case 'error':
            case 'high':
              mappedSeverity = 'error';
              break;
            case 'warning':
            case 'medium':
              mappedSeverity = 'warning';
              break;
            default:
              mappedSeverity = 'info';
          }

          allLogs.add({
            'id': alarm['id'],
            'event_type': mappedEventType,
            'room_id': alarm['room_id'],
            'room_number': alarm['room_number'] ?? alarm['room_id']?.toString() ?? '-',
            'title': _getAlarmTitle(alarm['alarm_type'], alarm['alarm_level']),
            'description': alarm['alarm_content'] ?? '设备告警',
            'severity': mappedSeverity,
            'created_at': alarm['created_at'] ?? '',
            'resolved': alarm['status'] == 'resolved' || alarm['status'] == 'ignored',
            'resolved_at': alarm['handled_at'],
            'handled_by': alarm['handled_by']?.toString(),
          });
        }
      }

      if (eventType != null) {
        allLogs = allLogs.where((log) => log['event_type'] == eventType).toList();
      }
      if (severity != null) {
        allLogs = allLogs.where((log) => log['severity'] == severity).toList();
      }

      final criticalCount = allLogs.where((l) => l['severity'] == 'critical' && l['resolved'] == false).length;
      final unresolvedCount = allLogs.where((l) => l['resolved'] == false).length;

      return ApiResult.success({
        'logs': allLogs,
        'total': allLogs.length,
        'summary': {
          'critical_count': criticalCount,
          'unresolved_count': unresolvedCount,
          'today_total': allLogs.length,
        },
      });
    } catch (e) {
      return ApiResult.failure('网络错误�?e');
    }
  }

  String _getAlarmTitle(String? alarmType, String? alarmLevel) {
    final type = alarmType?.toString() ?? 'unknown';
    final level = alarmLevel?.toString() ?? 'warning';

    String levelEmoji;
    switch (level) {
      case 'emergency':
      case 'critical':
        levelEmoji = '🚨';
        break;
      case 'error':
      case 'high':
        levelEmoji = '⚠️';
        break;
      case 'warning':
      case 'medium':
        levelEmoji = '🔔';
        break;
      default:
        levelEmoji = 'ℹ️';
    }

    String typeText;
    switch (type) {
      case 'smoke':
      case 'fire':
        typeText = '烟雾告警';
        break;
      case 'temperature':
      case 'overheat':
        typeText = '温度告警';
        break;
      case 'offline':
        typeText = '设备离线';
        break;
      case 'device_error':
        typeText = '设备故障';
        break;
      default:
        typeText = '设备告警';
    }

    return '$levelEmoji $typeText';
  }

  Future<ApiResult<Map<String, dynamic>>> getDashboardStats() async {
    try {
      final results = await Future.wait([
        _dioClient.get(ApiConstants.devices),
        _dioClient.get('${ApiConstants.deviceAlarms}/stats'),
        _dioClient.get('${ApiConstants.energy}/stats'),
      ]);

      Map<String, dynamic> deviceData = {};
      Map<String, dynamic> alarmStats = {};
      Map<String, dynamic> energyStats = {};

      if (results[0].statusCode == 200 && results[0].data['code'] == 200) {
        deviceData = results[0].data['data'] as Map<String, dynamic>? ?? {};
      }

      if (results[1].statusCode == 200 && results[1].data['code'] == 200) {
        alarmStats = results[1].data['data'] as Map<String, dynamic>? ?? {};
      }

      if (results[2].statusCode == 200 && results[2].data['code'] == 200) {
        energyStats = results[2].data['data'] as Map<String, dynamic>? ?? {};
      }

      List<dynamic> deviceList = [];
      if (deviceData is List) {
        deviceList = List<dynamic>.from(deviceData as Iterable);
      } else if (deviceData.containsKey('list')) {
        deviceList = List<dynamic>.from(deviceData['list'] ?? []);
      }

      final onlineCount = deviceList.where((d) =>
          d['device_status'] == 'online' || d['status'] == 'online').length;
      final offlineCount = deviceList.where((d) =>
          d['device_status'] == 'offline' || d['status'] == 'offline').length;
      final errorCount = deviceList.where((d) =>
          d['device_status'] == 'error' || d['status'] == 'error').length;
      final runningCount = deviceList.where((d) =>
          d['device_status'] == 'on' || d['status'] == 'on').length;

      final smokeDetectors = deviceList.where((d) =>
          d['device_type'] == 'smoke_detector' || d['device_type'] == 'sensor').toList();
      final detectorsOnline = smokeDetectors.where((d) =>
          d['device_status'] == 'online' || d['status'] == 'online').length;

      final sensorDevices = deviceList.where((d) =>
          d['device_type'] == 'sensor' ||
          d['device_type'] == 'smoke_detector' ||
          d['device_type'] == 'temperature_sensor' ||
          d['device_type'] == 'humidity_sensor' ||
          d['device_type'] == 'thermostat').toList();

      double totalTemp = 0;
      int tempCount = 0;
      double totalHumidity = 0;
      int humidityCount = 0;

      for (final device in sensorDevices) {
        try {
          final sensorRes = await _dioClient.get(
            '${ApiConstants.devices}/${device['id']}/sensor-data/latest',
          );
          if (sensorRes.statusCode == 200 && sensorRes.data['code'] == 200) {
            final sensorData = sensorRes.data['data'];
            if (sensorData is List) {
              for (final s in sensorData) {
                if (s['sensor_type'] == 'temperature' && s['sensor_value'] != null) {
                  totalTemp += (s['sensor_value'] as num).toDouble();
                  tempCount++;
                }
                if (s['sensor_type'] == 'humidity' && s['sensor_value'] != null) {
                  totalHumidity += (s['sensor_value'] as num).toDouble();
                  humidityCount++;
                }
              }
            }
          }
        } catch (_) {}
      }

      final avgTemperature = tempCount > 0 ? totalTemp / tempCount : null;
      final avgHumidity = humidityCount > 0 ? totalHumidity / humidityCount : null;

      final byLevel = Map<String, dynamic>.from(alarmStats['by_level'] ?? {});
      final pendingCount = (alarmStats['pending_count'] as num?)?.toInt() ?? 0;
      final totalCount = (alarmStats['total_count'] as num?)?.toInt() ?? 0;

      final totalEnergy = (energyStats['total'] as num?)?.toDouble() ?? 0;
      final trend = energyStats['trend'] as List<dynamic>? ?? [];
      double yesterdayEnergy = 0;
      if (trend.length >= 2) {
        yesterdayEnergy = (trend[trend.length - 2]['value'] as num?)?.toDouble() ?? 0;
      }
      final savingsPercent = yesterdayEnergy > 0
          ? ((yesterdayEnergy - totalEnergy) / yesterdayEnergy * 100)
          : 0.0;

      int environmentScore = 85;
      if (errorCount > 0) environmentScore -= (errorCount * 10);
      if (pendingCount > 0) environmentScore -= (pendingCount * 5);
      if (offlineCount > 3) environmentScore -= 10;
      if (avgTemperature != null && (avgTemperature > 30 || avgTemperature < 18)) environmentScore -= 10;
      if (avgHumidity != null && (avgHumidity > 75 || avgHumidity < 30)) environmentScore -= 5;
      environmentScore = environmentScore.clamp(0, 100);

      final normalCount = deviceList.where((d) =>
          d['device_status'] == 'online' || d['status'] == 'online' ||
          d['device_status'] == 'on' || d['status'] == 'on').length;

      String airQuality = '优';
      String comfortLevel = '舒适';
      if (avgTemperature != null) {
        if (avgTemperature > 30 || avgTemperature < 15) { airQuality = '差'; comfortLevel = '不适'; }
        else if (avgTemperature > 28 || avgTemperature < 18) { airQuality = '良'; comfortLevel = '一般'; }
      }
      if (avgHumidity != null) {
        if (avgHumidity > 80 || avgHumidity < 20) { airQuality = '差'; comfortLevel = '不适'; }
        else if (avgHumidity > 70 || avgHumidity < 30) {
          if (airQuality == '优') airQuality = '良';
          if (comfortLevel == '舒适') comfortLevel = '一般';
        }
      }

      return ApiResult.success({
        'environment': {
          'avg_temperature': avgTemperature,
          'avg_humidity': avgHumidity,
          'air_quality': airQuality,
          'comfort_level': comfortLevel,
          'normal_count': normalCount,
          'total_rooms': deviceList.length,
        },
        'fire_safety': {
          'active_alarms': pendingCount,
          'today_alarms': totalCount,
          'detectors_online': detectorsOnline,
          'detectors_total': smokeDetectors.length,
          'system_status': pendingCount > 0 ? 'alert' : 'normal',
        },
        'devices': {
          'total': deviceList.length,
          'online': onlineCount,
          'offline': offlineCount,
          'error': errorCount,
          'running': runningCount,
          'maintenance_due': 0,
        },
        'energy': {
          'today_total': totalEnergy,
          'yesterday_total': yesterdayEnergy,
          'savings_percent': savingsPercent,
          'monthly_estimate': totalEnergy * 30,
          'monthly_cost': totalEnergy * 30 * 0.85,
          'peak_hour': '19:00-20:00',
        },
        'alerts': {
          'critical': (byLevel['critical'] as num?)?.toInt() ?? (byLevel['emergency'] as num?)?.toInt() ?? 0,
          'warning': (byLevel['warning'] as num?)?.toInt() ?? (byLevel['medium'] as num?)?.toInt() ?? 0,
          'info': (byLevel['info'] as num?)?.toInt() ?? (byLevel['low'] as num?)?.toInt() ?? 0,
          'unresolved': pendingCount,
        },
        'environment_score': environmentScore,
      });
    } catch (e) {
      return ApiResult.failure('网络错误�?e');
    }
  }
}

final environmentServiceProvider = Provider((ref) => EnvironmentService());
