import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<ApiResult<Map<String, dynamic>>> lookupBooking(String keyword) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.bookings}lookup',
        queryParameters: {'keyword': keyword},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '查询订单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> confirmBooking(int id) async {
    try {
      final response = await _dioClient.put('${ApiConstants.bookings}$id/confirm');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '确认预订失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> checkin(int id) async {
    try {
      final response = await _dioClient.put('${ApiConstants.bookings}$id/checkin');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '办理入住失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> checkout(int id) async {
    try {
      final response = await _dioClient.put('${ApiConstants.bookings}$id/checkout');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '办理退房失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> cancelBooking(int id) async {
    try {
      final response = await _dioClient.put('${ApiConstants.bookings}$id/cancel');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '取消预订失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> checkinOnline(int bookingId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post('${ApiConstants.bookings}$bookingId/checkin-online', data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '在线入住办理失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final bookingServiceProvider = Provider<BookingService>((ref) => BookingService());

final userBookingsProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.read(bookingServiceProvider);
  final result = await service.getBookings();
  if (result.success) {
    return result.data?['list'] as List<dynamic>? ?? [];
  }
  return <dynamic>[];
});

final receptionBookingsProvider = FutureProvider.autoDispose.family<List<dynamic>, Map<String, dynamic>>((ref, params) async {
  final service = ref.read(bookingServiceProvider);
  final result = await service.getBookings(
    page: params['page'] ?? 1,
    pageSize: params['pageSize'] ?? 10,
    status: params['status'],
    guestName: params['guestName'],
  );
  if (result.success) {
    return result.data?['list'] as List<dynamic>? ?? [];
  }
  return <dynamic>[];
});
