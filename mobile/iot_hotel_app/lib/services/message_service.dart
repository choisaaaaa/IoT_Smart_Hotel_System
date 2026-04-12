import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

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

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取消息列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getMessagesByRoom(int roomId) async {
    return getMessages(type: 'room_$roomId');
  }

  Future<ApiResult<int>> getUnreadCount() async {
    // 后端暂未实现消息接口，直接返回0
    return ApiResult.success(0);
    // try {
    //   final response = await _dioClient.get('${ApiConstants.messages}unread/count');
    //
    //   if (response.statusCode == 200 && response.data['code'] == 200) {
    //     return ApiResult.success(response.data['data']['count'] as int);
    //   }
    //   return ApiResult.failure(response.data['message'] ?? '获取未读数失败');
    // } catch (e) {
    //   return ApiResult.failure('网络错误：$e');
    // }
  }

  Future<ApiResult<void>> markAsRead(int messageId) async {
    try {
      final response = await _dioClient.put('${ApiConstants.messages}/$messageId/read');

      if (response.statusCode == 200 && response.data['code'] == 200) {
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

      if (response.statusCode == 200 && response.data['code'] == 200) {
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

      if (response.statusCode == 200 && response.data['code'] == 200) {
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

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '发送消息失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final messageServiceProvider = Provider<MessageService>((ref) => MessageService());
