import 'package:flutter/foundation.dart';
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
    String? checkInDate,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.bookings,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'status': status,
          'guest_name': guestName,
          'check_in_date': checkInDate,
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
      final response = await _dioClient.get('${ApiConstants.bookings}/$id');
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
        '${ApiConstants.bookings}/lookup',
        queryParameters: {'keyword': keyword},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '查询订单失败');
    } catch (e) {
      try {
        final listResponse = await _dioClient.get(
          ApiConstants.bookings,
          queryParameters: {'pageSize': 50},
        );
        if (listResponse.statusCode == 200 && listResponse.data['code'] == 200) {
          final data = listResponse.data['data'];
          List<dynamic> bookings = [];
          if (data is Map && data.containsKey('list')) {
            bookings = List<dynamic>.from(data['list'] ?? []);
          } else if (data is List) {
            bookings = List<dynamic>.from(data);
          }
          for (final b in bookings) {
            if (b['id']?.toString() == keyword ||
                b['booking_number']?.toString() == keyword ||
                b['booking_no']?.toString() == keyword ||
                b['guest_phone']?.toString() == keyword ||
                b['guest_name']?.toString() == keyword) {
              return ApiResult.success(Map<String, dynamic>.from(b));
            }
          }
        }
      } catch (_) {}
      return ApiResult.failure('未找到匹配的预订');
    }
  }

  Future<ApiResult<void>> confirmBooking(int id) async {
    try {
      final response = await _dioClient.put('${ApiConstants.bookings}/$id/confirm');
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
      final response = await _dioClient.put('${ApiConstants.bookings}/$id/checkin');
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
      final response = await _dioClient.put('${ApiConstants.bookings}/$id/checkout');
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
      final response = await _dioClient.put('${ApiConstants.bookings}/$id/cancel');
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
      final response = await _dioClient.post('${ApiConstants.bookings}/$bookingId/checkin-online', data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '在线入住办理失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> selfCheckout(int bookingId, {
    String? invoiceTitle,
    String? invoiceTaxNumber,
    String? invoiceType,
    String? remark,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (invoiceTitle != null) data['invoice_title'] = invoiceTitle;
      if (invoiceTaxNumber != null) data['invoice_tax_number'] = invoiceTaxNumber;
      if (invoiceType != null) data['invoice_type'] = invoiceType;
      if (remark != null) data['checkout_remark'] = remark;
      final response = await _dioClient.put(
        '${ApiConstants.bookings}/$bookingId/checkout',
        data: data.isNotEmpty ? data : null,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>? ?? {});
      }
      return ApiResult.failure(response.data['message'] ?? '自助退房失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> extendStay(int bookingId, {
    required DateTime newCheckOutDate,
  }) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.bookings}/$bookingId/extend',
        data: {'check_out_date': newCheckOutDate.toIso8601String().split('T')[0]},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>? ?? {});
      }
      return ApiResult.failure(response.data['message'] ?? '续住申请失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  /// 拒绝预入住申请
  Future<ApiResult<void>> rejectPreCheckin(int bookingId) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.bookings}/$bookingId/reject-pre-checkin',
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '拒绝预入住失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  /// 计算预订价格
  Future<ApiResult<Map<String, dynamic>>> calculatePrice({
    required int roomId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    String? guestPhone,
    int? couponId,
    int? usedPoints,
    int? ratePlanId,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.bookings}/calculate-price',
        data: {
          'room_id': roomId,
          'check_in_date': checkInDate.toIso8601String().split('T')[0],
          'check_out_date': checkOutDate.toIso8601String().split('T')[0],
          if (guestPhone != null) 'guest_phone': guestPhone,
          if (couponId != null) 'coupon_id': couponId,
          if (usedPoints != null) 'used_points': usedPoints,
          if (ratePlanId != null) 'rate_plan_id': ratePlanId,
        },
      );
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '计算价格失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>?>> getMyCurrentStay() async {
    List<dynamic> extractList(dynamic data) {
      if (data is Map && data.containsKey('list')) {
        return List<dynamic>.from(data['list'] ?? []);
      } else if (data is List) {
        return List<dynamic>.from(data);
      }
      return [];
    }

    try {
      final response = await _dioClient.get(
        ApiConstants.bookings,
        queryParameters: {'status': 'checked_in', 'pageSize': 10},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final list = extractList(response.data['data']);
        final checkedIn = list.where((b) => b['status'] == 'checked_in').toList();
        if (checkedIn.isNotEmpty) {
          return ApiResult.success(Map<String, dynamic>.from(checkedIn.first));
        }
      }
    } catch (e) {
      debugPrint('getMyCurrentStay attempt 1 failed: $e');
    }

    try {
      final response = await _dioClient.get(
        ApiConstants.bookings,
        queryParameters: {'pageSize': 50},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final list = extractList(response.data['data']);
        final checkedIn = list.where((b) => b['status'] == 'checked_in').toList();
        if (checkedIn.isNotEmpty) {
          return ApiResult.success(Map<String, dynamic>.from(checkedIn.first));
        }
      }
    } catch (e) {
      debugPrint('getMyCurrentStay attempt 2 failed: $e');
    }

    try {
      final meResponse = await _dioClient.get(ApiConstants.authMe);
      if (meResponse.statusCode == 200 && meResponse.data['code'] == 200) {
        final userData = meResponse.data['data'];
        final keyword = userData['phone'] ?? userData['username'] ?? '';
        if (keyword.isNotEmpty) {
          final lookupResponse = await _dioClient.get(
            '${ApiConstants.bookings}/lookup',
            queryParameters: {'keyword': keyword},
          );
          if (lookupResponse.statusCode == 200 && lookupResponse.data['code'] == 200) {
            final lookupData = lookupResponse.data['data'];
            if (lookupData != null && lookupData['status'] == 'checked_in') {
              final fullResponse = await _dioClient.get('${ApiConstants.bookings}/${lookupData['id']}');
              if (fullResponse.statusCode == 200 && fullResponse.data['code'] == 200) {
                return ApiResult.success(Map<String, dynamic>.from(fullResponse.data['data']));
              }
              return ApiResult.success(Map<String, dynamic>.from(lookupData));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('getMyCurrentStay attempt 3 failed: $e');
    }

    return ApiResult.success(null);
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
