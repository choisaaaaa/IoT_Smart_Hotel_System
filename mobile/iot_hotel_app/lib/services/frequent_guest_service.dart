import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class FrequentGuestService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getFrequentGuests() async {
    try {
      final response = await _dioClient.get(ApiConstants.frequentGuests);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
      }
      return await _getFrequentGuestsFallback();
    } catch (e) {
      return await _getFrequentGuestsFallback();
    }
  }

  Future<ApiResult<List<dynamic>>> _getFrequentGuestsFallback() async {
    try {
      final response = await _dioClient.get(ApiConstants.guests);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
      }
    } catch (_) {}
    return ApiResult.success([]);
  }

  Future<ApiResult<Map<String, dynamic>>> addFrequentGuest(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.frequentGuests, data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '添加常旅客失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> updateFrequentGuest(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put('${ApiConstants.frequentGuests}$id', data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '更新常旅客失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteFrequentGuest(int id) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.frequentGuests}$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除常旅客失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final frequentGuestServiceProvider = Provider<FrequentGuestService>((ref) => FrequentGuestService());
