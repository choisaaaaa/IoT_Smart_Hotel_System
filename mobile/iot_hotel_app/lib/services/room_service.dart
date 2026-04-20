import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class RoomService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getRooms({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? floor,
    int? hotelId,
    int? roomTypeId,
    String? type,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (status != null) queryParams['status'] = status;
      if (floor != null) queryParams['floor'] = floor;
      if (hotelId != null) queryParams['hotel_id'] = hotelId;
      if (roomTypeId != null) queryParams['room_type_id'] = roomTypeId;
      if (type != null) queryParams['type'] = type;

      final response = await _dioClient.get(
        ApiConstants.rooms,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is Map && data.containsKey('list')) {
          return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
        } else if (data is List) {
          return ApiResult.success(List<dynamic>.from(data));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取房间列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getRoomById(int roomId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.rooms}/$roomId');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取房间详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createRoom(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.rooms, data: data);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建房间失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateRoom(int roomId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put('${ApiConstants.rooms}/$roomId', data: data);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '更新房间失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateRoomStatus(int roomId, String status) async {
    try {
      final response = await _dioClient.patch(
        '${ApiConstants.rooms}/$roomId/status',
        data: {'status': status},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '更新房间状态失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteRoom(int roomId) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.rooms}/$roomId');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除房间失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getRoomStatusDistribution() async {
    try {
      final response = await _dioClient.get(
        ApiConstants.rooms,
        queryParameters: {'pageSize': 200},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        List<dynamic> rooms = [];
        if (data is Map && data.containsKey('list')) {
          rooms = List<dynamic>.from(data['list'] ?? []);
        } else if (data is List) {
          rooms = List<dynamic>.from(data);
        }

        final Map<String, int> distribution = {};
        for (final room in rooms) {
          final status = room['room_status']?.toString() ?? room['status']?.toString() ?? 'available';
          distribution[status] = (distribution[status] ?? 0) + 1;
        }

        return ApiResult.success({
          'total': rooms.length,
          'distribution': distribution,
        });
      }
      return ApiResult.failure(response.data['message'] ?? '获取房间状态分布失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final roomServiceProvider = Provider((ref) => RoomService());
