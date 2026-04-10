import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class EnvironmentService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> getDashboardStats() async {
    try {
      final response = await _dioClient.get('${ApiConstants.environment}dashboard');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取环境数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getEnvironmentData() async {
    try {
      final response = await _dioClient.get(ApiConstants.environment);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) {
          return ApiResult.success(List<dynamic>.from(data));
        } else if (data is Map) {
          return ApiResult.success([data]);
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取环境数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getEnvironmentHistory({
    int? roomId,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.environment}history',
        queryParameters: {
          'room_id': roomId,
          'start_time': startTime,
          'end_time': endTime,
        }..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) {
          return ApiResult.success(List<dynamic>.from(data));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取历史数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getFireAlarms({String? status}) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.environment}fire-alarms',
        queryParameters: {'status': status}..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) {
          return ApiResult.success(List<dynamic>.from(data));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取消防警报失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> acknowledgeAlarm(int alarmId) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.environment}fire-alarms/$alarmId/acknowledge',
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '确认警报失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> resolveAlarm(int alarmId) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.environment}fire-alarms/$alarmId/resolve',
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '解决警报失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getEnergyConsumption() async {
    try {
      final response = await _dioClient.get('${ApiConstants.environment}energy');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取能耗数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getEventLogs({int limit = 50}) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.environment}event-logs',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) {
          return ApiResult.success(List<dynamic>.from(data));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取事件日志失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final environmentServiceProvider = Provider<EnvironmentService>((ref) => EnvironmentService());
