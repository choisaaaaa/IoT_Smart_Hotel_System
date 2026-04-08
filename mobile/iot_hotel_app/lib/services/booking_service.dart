import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class BookingService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> getBookings({
    int page = 1,
    int pageSize = 10,
    String? status,
    String? guestName,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.bookings,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'status': status,
          'guest_name': guestName,
        }..removeWhere((key, value) => value == null),
      );
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取订单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getBookingById(int id) async {
    try {
      final response = await _dioClient.get('${ApiConstants.bookings}$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createBooking(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.bookings, data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建订单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}
