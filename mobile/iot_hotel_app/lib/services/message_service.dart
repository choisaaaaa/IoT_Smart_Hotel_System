import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/type_utils.dart';

class MessageService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getMessages({
    int page = 1,
    int pageSize = 20,
    String? type,
    bool? isRead,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.messages,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'type': type,
          'is_read': isRead,
        }..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final data = response.data['data'] ?? response.data['result'];
        List<dynamic> list;
        if (data is Map) {
          list = List<dynamic>.from(data['list'] ?? data['items'] ?? []);
        } else if (data is List) {
          list = List<dynamic>.from(data);
        } else {
          list = [];
        }
        return ApiResult.success(list);
      }
      return ApiResult.failure(response.data['message'] ?? '获取消息列表失败');
    } catch (e) {
      return ApiResult.failure('消息服务暂不可用');
    }
  }

  Future<ApiResult<List<dynamic>>> getMessagesByRoom(int roomId) async {
    return getMessages(type: 'room_$roomId');
  }

  Future<ApiResult<int>> getUnreadCount() async {
    try {
      final response = await _dioClient.get('${ApiConstants.messages}/unread/count');
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final data = response.data['data'];
        return ApiResult.success(safeToInt(data is Map ? data['count'] : data));
      }
    } catch (e) {
      debugPrint('专用未读计数接口失败，尝试通过消息列表统计: $e');
    }

    try {
      final messagesResponse = await _dioClient.get(
        ApiConstants.messages,
        queryParameters: {'page': 1, 'pageSize': 100, 'is_read': false},
      );
      if (messagesResponse.statusCode == 200 && isApiSuccess(messagesResponse.data)) {
        final data = messagesResponse.data['data'];
        List<dynamic> list;
        if (data is Map) {
          list = List<dynamic>.from(data['list'] ?? data['items'] ?? []);
        } else if (data is List) {
          list = List<dynamic>.from(data);
        } else {
          list = [];
        }
        final total = data is Map ? safeToInt(data['total']) : list.length;
        return ApiResult.success(total > 0 ? total : list.length);
      }
    } catch (e) {
      debugPrint('通过消息列表统计未读数也失败: $e');
    }

    return ApiResult.success(0);
  }

  Future<ApiResult<void>> markAsRead(int messageId) async {
    try {
      final response = await _dioClient.put('${ApiConstants.messages}/$messageId/read');
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '标记已读失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> markAllAsRead() async {
    try {
      final response = await _dioClient.put('${ApiConstants.messages}/read-all');
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '全部标记已读失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteMessage(int messageId) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.messages}/$messageId');
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除消息失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> sendMessage({
    Map<String, dynamic>? data,
    int? roomId,
    String? senderType,
    int? senderId,
    String? content,
  }) async {
    try {
      final payload = data ??
          {
            if (roomId != null) 'room_id': roomId,
            if (senderType != null) 'sender_type': senderType,
            if (senderId != null) 'sender_id': senderId,
            if (content != null) 'content': content,
          };
      final response = await _dioClient.post(ApiConstants.messages, data: payload);

      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final resultData = response.data['data'] ?? response.data['result'];
        if (resultData is Map<String, dynamic>) {
          return ApiResult.success(resultData);
        }
        return ApiResult.success({});
      }
      return ApiResult.failure(response.data['message'] ?? '发送消息失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final messageServiceProvider = Provider<MessageService>((ref) => MessageService());
