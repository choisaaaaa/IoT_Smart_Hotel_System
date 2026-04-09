import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class RoomTypeService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getRoomTypes() async {
    try {
      final response = await _dioClient.get(ApiConstants.roomTypes);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取房型列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getRoomTypeById(int id) async {
    try {
      final response = await _dioClient.get('${ApiConstants.roomTypes}$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取房型详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createRoomType(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.roomTypes, data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建房型失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateRoomType(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put('${ApiConstants.roomTypes}$id', data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) return ApiResult.success(null);
      return ApiResult.failure(response.data['message'] ?? '更新房型失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteRoomType(int id) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.roomTypes}$id');
      if (response.statusCode == 200 && response.data['code'] == 200) return ApiResult.success(null);
      return ApiResult.failure(response.data['message'] ?? '删除房型失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final roomTypeServiceProvider = Provider((ref) => RoomTypeService());
