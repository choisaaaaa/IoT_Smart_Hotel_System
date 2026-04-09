import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class ReviewService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getHotelReviews(int hotelId, {
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
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取评价列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createReview({
    Map<String, dynamic>? data,
    int? bookingId,
    int? hotelId,
    int? rating,
    String? content,
    int? serviceRating,
    int? cleanlinessRating,
    int? facilityRating,
    List<String>? images,
  }) async {
    try {
      final payload = data ??
          {
            if (bookingId != null) 'booking_id': bookingId,
            if (hotelId != null) 'hotel_id': hotelId,
            if (rating != null) 'rating': rating,
            if (content != null) 'content': content,
            if (serviceRating != null) 'service_rating': serviceRating,
            if (cleanlinessRating != null) 'cleanliness_rating': cleanlinessRating,
            if (facilityRating != null) 'facility_rating': facilityRating,
            if (images != null && images.isNotEmpty) 'images': images,
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

  Future<ApiResult<List<dynamic>>> getMyReviews({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.reviews}my',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取我的评价失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getReviewStats(int hotelId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.reviews}hotel/$hotelId/stats');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取评价统计失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService());
