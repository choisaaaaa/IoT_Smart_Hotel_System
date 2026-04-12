import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class DeviceService {
  final DioClient _dioClient = DioClient();

  bool _isSuccess(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['code'] == 200 || data['code'] == 201) return true;
    if (data['success'] == true) return true;
    return false;
  }

  Future<ApiResult<List<dynamic>>> getMyRoomDevices() async {
    try {
      final bookingResponse = await _dioClient.get(
        ApiConstants.bookings,
        queryParameters: {'status': 'checked_in', 'pageSize': 5},
      );

      if (bookingResponse.statusCode == 200 && _isSuccess(bookingResponse.data)) {
        final data = bookingResponse.data['data'];
        List<dynamic> bookings = [];
        if (data is Map && data.containsKey('list')) {
          bookings = List<dynamic>.from(data['list'] ?? []);
        } else if (data is List) {
          bookings = List<dynamic>.from(data);
        }

        final checkedIn = bookings.where((b) => b['status'] == 'checked_in').toList();
        if (checkedIn.isEmpty) {
          return ApiResult.success([]);
        }

        final roomId = checkedIn.first['room_id'];
        if (roomId == null) return ApiResult.success([]);

        try {
          final response = await _dioClient.get(
            ApiConstants.devices,
            queryParameters: {'room_id': roomId},
          );

          if (response.statusCode == 200 && _isSuccess(response.data)) {
            final devData = response.data['data'];
            if (devData is List) return ApiResult.success(List<dynamic>.from(devData));
            return ApiResult.success(List<dynamic>.from(devData['list'] ?? []));
          }
        } catch (_) {}

        try {
          final roomResponse = await _dioClient.get('${ApiConstants.rooms}/$roomId');
          if (roomResponse.statusCode == 200 && _isSuccess(roomResponse.data)) {
            final roomData = roomResponse.data['data'];
            final devices = roomData['devices'];
            if (devices is List) return ApiResult.success(List<dynamic>.from(devices));
          }
        } catch (_) {}
      }

      return ApiResult.success([]);
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> controlDevice(int deviceId, String command, dynamic value) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.devices}/$deviceId/command',
        data: {
          'command_type': command,
          'command_value': value,
        },
      );

      if (response.statusCode == 200 && _isSuccess(response.data)) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '操作失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getAllDevices({String? status, int? roomId}) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.devices,
        queryParameters: {
          'status': status,
          'room_id': roomId,
        }..removeWhere((key, value) => value == null),
      );
      if (response.statusCode == 200 && _isSuccess(response.data)) {
        return ApiResult.success(List<dynamic>.from(response.data['data']));
      }
      return ApiResult.failure(response.data['message'] ?? '获取设备列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> aiChat(int roomId, String text, {String? audioData}) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.aiButler}/chat',
        data: {
          'room_id': roomId,
          'text': text,
          if (audioData != null) 'audio': audioData,
        },
      );

      if (response.statusCode == 200 && _isSuccess(response.data)) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? 'AI管家暂时无法回答');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService());
