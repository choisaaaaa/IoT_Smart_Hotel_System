import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class CallService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> outboundCall({
    required String callerId,
    required String calleeType,
    required String calleeId,
    String? callerType,
    String? type,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.calls}/outbound',
        data: {
          'caller_id': callerId,
          'callee_type': calleeType,
          'callee_id': calleeId,
          if (callerType != null) 'caller_type': callerType,
          if (type != null) 'type': type,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '发起通话失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> answerCall(String callId) async {
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

  Future<ApiResult<Map<String, dynamic>>> rejectCall(String callId) async {
    try {
      final response = await _dioClient.post('${ApiConstants.calls}/$callId/reject');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '拒绝失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> hangupCall(String callId) async {
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

  Future<ApiResult<Map<String, dynamic>>> getCallStatus(String callId) async {
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

  Future<ApiResult<List<dynamic>>> getActiveCalls() async {
    try {
      final response = await _dioClient.get('${ApiConstants.calls}/active');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is Map && data.containsKey('items')) {
          return ApiResult.success(List<dynamic>.from(data['items'] ?? []));
        } else if (data is List) {
          return ApiResult.success(List<dynamic>.from(data));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取活跃通话失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getCallHistory({
    int? page,
    int? limit,
    String? roomId,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;
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

  Future<ApiResult<Map<String, dynamic>>> getCallStats({
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
      return ApiResult.failure(response.data['message'] ?? '获取通话统计失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final callServiceProvider = Provider((ref) => CallService());
