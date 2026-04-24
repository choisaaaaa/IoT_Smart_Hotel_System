import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class CallApiService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> outbound({
    required String callerId,
    required String calleeType,
    required String calleeId,
    String callerType = 'front_desk',
    String type = 'voice',
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.calls}/outbound',
        data: {
          'caller_id': callerId,
          'caller_type': callerType,
          'callee_type': calleeType,
          'callee_id': calleeId,
          'type': type,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '发起呼叫失败');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? '网络错误';
      return ApiResult.failure(msg);
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> answer(String callId) async {
    try {
      final response = await _dioClient.post('${ApiConstants.calls}/$callId/answer');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '接听失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> reject(String callId) async {
    try {
      final response = await _dioClient.post('${ApiConstants.calls}/$callId/reject');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '拒接失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> hangup(String callId) async {
    try {
      final response = await _dioClient.post('${ApiConstants.calls}/$callId/hangup');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '挂断失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getStatus(String callId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.calls}/$callId/status');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取通话状态失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getActive() async {
    try {
      final response = await _dioClient.get('${ApiConstants.calls}/active');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is Map && data.containsKey('items')) {
          return ApiResult.success(List<dynamic>.from(data['items'] ?? []));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取活跃通话失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getHistory({
    int page = 1,
    int limit = 50,
    String? roomId,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (roomId != null) queryParams['room_id'] = roomId;
      if (startTime != null) queryParams['start_time'] = startTime;
      if (endTime != null) queryParams['end_time'] = endTime;

      final response = await _dioClient.get(
        '${ApiConstants.calls}/history',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取通话记录失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getStats({
    String? roomId,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (roomId != null) queryParams['room_id'] = roomId;
      if (startTime != null) queryParams['start_time'] = startTime;
      if (endTime != null) queryParams['end_time'] = endTime;

      final response = await _dioClient.get(
        '${ApiConstants.calls}/stats',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取统计失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final callApiServiceProvider = Provider<CallApiService>((ref) => CallApiService());
