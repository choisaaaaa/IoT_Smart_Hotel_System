import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class PriceCalendarService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getPriceCalendar({
    required int roomTypeId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.priceCalendar,
        queryParameters: {
          'room_type_id': roomTypeId,
          'start_date': startDate,
          'end_date': endDate,
        }..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) {
          return ApiResult.success(List<dynamic>.from(data));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取价格日历失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> setPriceForDate({
    required int roomTypeId,
    required String date,
    required double basePrice,
    double? discountRate,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.priceCalendar,
        data: {
          'room_type_id': roomTypeId,
          'date': date,
          'base_price': basePrice,
          'discount_rate': discountRate ?? 1.0,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '设置价格失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> updatePriceForDate({
    required int priceId,
    required double basePrice,
    double? discountRate,
  }) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.priceCalendar}/$priceId',
        data: {
          'base_price': basePrice,
          'discount_rate': discountRate ?? 1.0,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '更新价格失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deletePriceForDate(int priceId) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.priceCalendar}/$priceId');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除价格失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getMemberDiscounts() async {
    try {
      final response = await _dioClient.get('${ApiConstants.priceCalendar}/member-discounts');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取会员折扣失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final priceCalendarServiceProvider = Provider<PriceCalendarService>((ref) => PriceCalendarService());
