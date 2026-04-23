import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class ReviewService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> getHotelReviews(int hotelId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.reviews,
        queryParameters: {
          'hotel_id': hotelId,
          'page': page,
          'pageSize': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取评价列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createReview({
    int? orderId,
    int? hotelId,
    int? roomTypeId,
    int? score,
    int? environmentRating,
    int? facilityRating,
    int? comfortRating,
    String? content,
    List<String>? photos,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (orderId != null) 'order_id': orderId,
        if (hotelId != null) 'hotel_id': hotelId,
        if (roomTypeId != null) 'room_type_id': roomTypeId,
        if (score != null) 'score': score,
        if (environmentRating != null) 'environment_rating': environmentRating,
        if (facilityRating != null) 'facility_rating': facilityRating,
        if (comfortRating != null) 'comfort_rating': comfortRating,
        if (content != null) 'content': content,
        if (photos != null && photos.isNotEmpty) 'photos': photos,
      };
      final response = await _dioClient.post(ApiConstants.reviews, data: payload);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '提交评价失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getMyReviews({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.reviews}/my',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取我的评价失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getReviewStats(int hotelId) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.reviews}/stats',
        queryParameters: {'hotel_id': hotelId},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取评价统计失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateReview({
    required int id,
    int? score,
    int? environmentRating,
    int? facilityRating,
    int? comfortRating,
    String? content,
    List<String>? photos,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (score != null) 'score': score,
        if (environmentRating != null) 'environment_rating': environmentRating,
        if (facilityRating != null) 'facility_rating': facilityRating,
        if (comfortRating != null) 'comfort_rating': comfortRating,
        if (content != null) 'content': content,
        if (photos != null) 'photos': photos,
      };
      final response = await _dioClient.put('${ApiConstants.reviews}/$id', data: payload);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '修改评价失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteReview(int id) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.reviews}/$id');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除评价失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> replyReview({
    required int id,
    required String reply,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.reviews}/$id/reply',
        data: {'reply': reply},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '回复评价失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getAppeals({
    int? hotelId,
    String? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.reviews}/appeals',
        queryParameters: {
          if (hotelId != null) 'hotel_id': hotelId,
          if (status != null) 'status': status,
          'page': page,
          'pageSize': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }

      debugPrint('获取申诉列表接口返回非200状态: ${response.statusCode}, ${response.data}');
      return ApiResult.success(_getEmptyAppealsData());
    } catch (e) {
      debugPrint('获取申诉列表失败: $e');
      return ApiResult.success(_getEmptyAppealsData());
    }
  }

  Map<String, dynamic> _getEmptyAppealsData() {
    return {
      'list': <Map<String, dynamic>>[],
      'total': 0,
    };
  }

  Future<ApiResult<void>> createAppeal({
    required int reviewId,
    required String appealReason,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.reviews}/appeals',
        data: {
          'review_id': reviewId,
          'appeal_reason': appealReason,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '提交申诉失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> handleAppeal({
    required int id,
    required String action,
    String? handleReason,
  }) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.reviews}/appeals/$id',
        data: {
          'action': action,
          if (handleReason != null) 'handle_reason': handleReason,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '处理申诉失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getAllReviews({
    int? hotelId,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.reviews,
        queryParameters: {
          if (hotelId != null) 'hotel_id': hotelId,
          'page': page,
          'pageSize': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取评价列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService());
