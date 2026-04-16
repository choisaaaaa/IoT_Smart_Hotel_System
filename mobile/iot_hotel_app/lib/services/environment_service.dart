import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class EnvironmentService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> getEnvironmentData({
    int? floorId,
    int? roomId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (floorId != null) queryParams['floor_id'] = floorId;
      if (roomId != null) queryParams['room_id'] = roomId;
      if (status != null) queryParams['status'] = status;

      final response = await _dioClient.get(
        ApiConstants.environment,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
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
      if (hours != null) queryParams['hours'] = hours;

      final response = await _dioClient.get(
        '${ApiConstants.environment}/history',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取环境历史失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getFireAlarms({
    String? status,
    String? severity,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (severity != null) queryParams['severity'] = severity;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _dioClient.get(
        '${ApiConstants.environment}/fire-alarms',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取火警记录失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> acknowledgeAlarm(int alarmId, {String? handler, String? notes}) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.environment}/fire-alarms/$alarmId/acknowledge',
        data: {if (handler != null) 'handler': handler, if (notes != null) 'notes': notes},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '确认火警失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> resolveAlarm(int alarmId, {String? resolution, String? handler}) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.environment}/fire-alarms/$alarmId/resolve',
        data: {if (resolution != null) 'resolution': resolution, if (handler != null) 'handler': handler},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '解决火警失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getRoomDevices({int? roomId}) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.environment}/devices',
        queryParameters: {if (roomId != null) 'room_id': roomId},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取房间设备失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> controlDevice(String deviceId, {
    required String action,
    double? value,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.environment}/devices/$deviceId/control',
        data: {'action': action, if (value != null) 'value': value},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>? ?? {});
      }
      return ApiResult.failure(response.data['message'] ?? '控制设备失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getEnergyConsumption({int? roomId, String? period}) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.environment}/energy',
        queryParameters: {
          if (roomId != null) 'room_id': roomId,
          if (period != null) 'period': period,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取能耗数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getEventLogs({
    String? eventType,
    String? severity,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (eventType != null) queryParams['event_type'] = eventType;
      if (severity != null) queryParams['severity'] = severity;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _dioClient.get(
        '${ApiConstants.environment}/event-logs',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取事件日志失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getDashboardStats() async {
    try {
      final response = await _dioClient.get('${ApiConstants.environment}/dashboard');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取环境仪表盘失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final environmentServiceProvider = Provider((ref) => EnvironmentService());
