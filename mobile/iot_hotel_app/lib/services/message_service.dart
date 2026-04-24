import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/type_utils.dart';

class MessageService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getMessages({
    int? roomId,
    int? hotelId,
    int? isRead,
    int page = 1,
    int pageSize = 50,
    int? beforeId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (roomId != null) queryParams['room_id'] = roomId;
      if (hotelId != null) queryParams['hotel_id'] = hotelId;
      if (isRead != null) queryParams['is_read'] = isRead;
      if (beforeId != null) queryParams['before_id'] = beforeId;

      final response = await _dioClient.get(
        ApiConstants.messages,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final data = response.data['data'];
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('[MessageService] messages接口未实现(404)，返回空列表');
        return ApiResult.success([]);
      }
      return ApiResult.failure('消息服务暂不可用');
    } catch (e) {
      return ApiResult.failure('消息服务暂不可用');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> sendMessage({
    required int roomId,
    required String senderType,
    required String content,
    int? hotelId,
    int? bookingId,
    int? guestId,
    int? senderId,
    String? senderName,
  }) async {
    try {
      final payload = <String, dynamic>{
        'room_id': roomId,
        'sender_type': senderType,
        'content': content,
      };
      if (hotelId != null) payload['hotel_id'] = hotelId;
      if (bookingId != null) payload['booking_id'] = bookingId;
      if (guestId != null) payload['guest_id'] = guestId;
      if (senderId != null) payload['sender_id'] = senderId;
      if (senderName != null) payload['sender_name'] = senderName;

      final response = await _dioClient.post(ApiConstants.messages, data: payload);

      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final resultData = response.data['data'];
        if (resultData is Map<String, dynamic>) {
          return ApiResult.success(resultData);
        }
        return ApiResult.success({});
      }
      return ApiResult.failure(response.data['message'] ?? '发送消息失败');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('[MessageService] messages发送接口未实现(404)');
        return ApiResult.failure('消息发送功能暂不可用');
      }
      return ApiResult.failure('网络错误：$e');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<int>> getUnreadCount({int? roomId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (roomId != null) queryParams['room_id'] = roomId;

      final response = await _dioClient.get(
        '${ApiConstants.messages}/unread-count',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final data = response.data['data'];
        return ApiResult.success(safeToInt(data is Map ? data['count'] : data));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('[MessageService] messages/unread-count接口未实现(404)，返回0');
        return ApiResult.success(0);
      }
      debugPrint('[MessageService] 获取未读数失败: $e');
    } catch (e) {
      debugPrint('[MessageService] 获取未读数失败: $e');
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResult.success(null);
      }
      return ApiResult.failure('网络错误：$e');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> markAllAsRead({int? roomId, int? hotelId}) async {
    try {
      final payload = <String, dynamic>{};
      if (roomId != null) payload['room_id'] = roomId;
      if (hotelId != null) payload['hotel_id'] = hotelId;

      final response = await _dioClient.put('${ApiConstants.messages}/read-all', data: payload);
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '全部标记已读失败');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResult.success(null);
      }
      return ApiResult.failure('网络错误：$e');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getRoomConversations({int? hotelId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (hotelId != null) queryParams['hotel_id'] = hotelId;

      final response = await _dioClient.get(
        '${ApiConstants.messages}/conversations',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && isApiSuccess(response.data)) {
        final data = response.data['data'];
        if (data is List) {
          return ApiResult.success(data);
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取会话列表失败');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResult.success([]);
      }
      return ApiResult.failure('网络错误：$e');
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResult.success(null);
      }
      return ApiResult.failure('网络错误：$e');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final messageServiceProvider = Provider<MessageService>((ref) => MessageService());
