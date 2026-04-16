import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class KnowledgeBaseService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getKnowledgeList({
    String? category,
    int? isActive,
    int? hotelId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null) queryParams['category'] = category;
      if (isActive != null) queryParams['is_active'] = isActive;
      if (hotelId != null) queryParams['hotel_id'] = hotelId;

      final response = await _dioClient.get(
        ApiConstants.knowledgeBase,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        if (data is Map && data.containsKey('list')) {
          return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取知识库列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getKnowledgeById(int id) async {
    try {
      final response = await _dioClient.get('${ApiConstants.knowledgeBase}/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取知识库详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createOrUpdateKnowledge(
      String category, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.knowledgeBase}/$category',
        data: data,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>? ?? {});
      }
      return ApiResult.failure(response.data['message'] ?? '保存知识库失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> toggleKnowledgeActive(int id) async {
    try {
      final response = await _dioClient.patch('${ApiConstants.knowledgeBase}/$id/toggle');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '切换状态失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteKnowledge(int id) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.knowledgeBase}/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除知识库失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> initDefaultKnowledge({int? hotelId}) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.knowledgeBase}/init',
        data: {if (hotelId != null) 'hotel_id': hotelId},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '初始化知识库失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final knowledgeBaseServiceProvider = Provider((ref) => KnowledgeBaseService());
