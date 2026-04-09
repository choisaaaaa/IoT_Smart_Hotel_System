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
            if (bookingId != null) 'order_id': bookingId,
            if (hotelId != null) 'hotel_id': hotelId,
            if (rating != null) 'score': rating,
            if (content != null) 'content': content,
            'order_type': 'booking',
            if (images != null && images.isNotEmpty) 'photos': images,
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
        ApiConstants.reviews,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取我的评价失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getReviewStats(int hotelId) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.reviews,
        queryParameters: {'hotel_id': hotelId, 'pageSize': 200},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        List<dynamic> reviews = [];
        if (data is List) {
          reviews = List<dynamic>.from(data);
        } else if (data is Map) {
          reviews = List<dynamic>.from(data['list'] ?? []);
        }

        double totalScore = 0;
        int count = reviews.length;
        for (final r in reviews) {
          totalScore += (r['score'] as num?)?.toDouble() ?? 0;
        }

        return ApiResult.success({
          'average_score': count > 0 ? totalScore / count : 0,
          'total_reviews': count,
          'score_distribution': {},
        });
      }
      return ApiResult.failure(response.data['message'] ?? '获取评价统计失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService());
