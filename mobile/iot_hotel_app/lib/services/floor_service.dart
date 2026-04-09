import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class FloorService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getFloors() async {
    try {
      final response = await _dioClient.get(ApiConstants.floors);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取楼层列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createFloor(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.floors, data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建楼层失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateFloor(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put('${ApiConstants.floors}$id', data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) return ApiResult.success(null);
      return ApiResult.failure(response.data['message'] ?? '更新楼层失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteFloor(int id) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.floors}$id');
      if (response.statusCode == 200 && response.data['code'] == 200) return ApiResult.success(null);
      return ApiResult.failure(response.data['message'] ?? '删除楼层失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final floorServiceProvider = Provider((ref) => FloorService());
