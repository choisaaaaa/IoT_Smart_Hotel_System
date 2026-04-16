import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class DeviceService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getDevices({
    String? status,
    String? auditStatus,
    int? roomId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (auditStatus != null) queryParams['audit_status'] = auditStatus;
      if (roomId != null) queryParams['room_id'] = roomId;

      final response = await _dioClient.get(
        ApiConstants.devices,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        if (data is Map && data.containsKey('list')) {
          return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
        }
        if (data is Map && data.containsKey('devices')) {
          return ApiResult.success(List<dynamic>.from(data['devices'] ?? []));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取设备列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getDeviceDetail(String deviceId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.devices}/$deviceId');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取设备详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> auditDevice(int id, {
    required String status,
    int? roomId,
    String? area,
  }) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.devices}/$id/audit',
        data: {
          'status': status,
          if (roomId != null) 'room_id': roomId,
          if (area != null) 'area': area,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '审核设备失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteDevice(int id) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.devices}/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除设备失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> sendCommand(
      int id, String commandType, String commandValue) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.devices}/$id/command',
        data: {
          'command_type': commandType,
          'command_value': commandValue,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>? ?? {});
      }
      return ApiResult.failure(response.data['message'] ?? '发送指令失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getDeviceStatusHistory(String deviceId, {int? limit}) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.devices}/$deviceId/history',
        queryParameters: {if (limit != null) 'limit': limit},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取设备历史失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getAllDevices({String? status, String? auditStatus, int? roomId}) async {
    return getDevices(status: status, auditStatus: auditStatus, roomId: roomId);
  }

  Future<ApiResult<List<dynamic>>> getMyRoomDevices({int? roomId}) async {
    return getDevices(roomId: roomId);
  }

  Future<ApiResult<Map<String, dynamic>>> controlDevice(int id, {
    required String commandType,
    required String commandValue,
  }) async {
    return sendCommand(id, commandType, commandValue);
  }
}

final deviceServiceProvider = Provider((ref) => DeviceService());
