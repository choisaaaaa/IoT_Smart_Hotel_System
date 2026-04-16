import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class SystemConfigService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<String>> getConfig(String key) async {
    try {
      final response = await _dioClient.get('${ApiConstants.systemConfig}/$key');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is String) return ApiResult.success(data);
        return ApiResult.success(data?.toString() ?? '');
      }
      return ApiResult.failure(response.data['message'] ?? '获取配置失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getAllConfigs() async {
    try {
      final response = await _dioClient.get(ApiConstants.systemConfig);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取所有配置失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateConfigs(Map<String, dynamic> configs) async {
    try {
      final response = await _dioClient.post(ApiConstants.systemConfig, data: configs);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '更新配置失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final systemConfigServiceProvider = Provider((ref) => SystemConfigService());
