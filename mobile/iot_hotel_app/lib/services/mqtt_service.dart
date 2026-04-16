import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class MqttService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getLogs() async {
    try {
      final response = await _dioClient.get('${ApiConstants.mqtt}/logs');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        if (data is Map && data.containsKey('list')) {
          return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取MQTT日志失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> sendMessage({
    required String topic,
    required String payload,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.mqtt}/send',
        data: {'topic': topic, 'payload': payload},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '发送MQTT消息失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getStatus() async {
    try {
      final response = await _dioClient.get('${ApiConstants.mqtt}/status');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取MQTT状态失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final mqttServiceProvider = Provider((ref) => MqttService());
