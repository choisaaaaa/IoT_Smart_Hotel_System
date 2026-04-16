import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../models/booking.dart';

class BookingService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<Booking>>> getBookings({
    int page = 1,
    int pageSize = 10,
    String? status,
    String? guestName,
    String? checkInDate,
    int? hotelId,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'pageSize': pageSize,
        'status': status,
        'guest_name': guestName,
        'check_in_date': checkInDate,
        'hotel_id': hotelId,
      }..removeWhere((key, value) => value == null);
      debugPrint('DEBUG: getBookings - queryParams=$queryParams');
      final response = await _dioClient.get(
        ApiConstants.bookings,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        debugPrint('DEBUG: getBookings - data=$data');
        List<dynamic> rawList;
        if (data is Map && data.containsKey('list')) {
          rawList = List<dynamic>.from(data['list'] ?? []);
        } else if (data is List) {
          rawList = List<dynamic>.from(data);
        } else if (data is Map && data.containsKey('bookings')) {
          rawList = List<dynamic>.from(data['bookings'] ?? []);
        } else {
          rawList = [];
        }
        debugPrint('DEBUG: getBookings - rawList.length=${rawList.length}');
        try {
          final bookings = rawList
              .map((b) => Booking.fromJson(b as Map<String, dynamic>))
              .toList();
          return ApiResult.success(bookings);
        } catch (e, stackTrace) {
          debugPrint('DEBUG: getBookings - parse error=$e');
          debugPrint('DEBUG: getBookings - stackTrace=$stackTrace');
          return ApiResult.failure('解析订单数据失败: $e');
        }
      }
      return ApiResult.failure(response.data['message'] ?? '获取订单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Booking>> getBookingById(int id) async {
    try {
      final response = await _dioClient.get('${ApiConstants.bookings}/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(
            Booking.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return ApiResult.failure(response.data['message'] ?? '获取详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Booking>> createBooking(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.bookings, data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(
            Booking.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return ApiResult.failure(response.data['message'] ?? '创建订单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Booking>> lookupBooking(String keyword) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.bookings}/lookup',
        queryParameters: {'keyword': keyword},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(
            Booking.fromJson(response.data['data'] as Map<String, dynamic>));
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
              return ApiResult.success(
                  Booking.fromJson(Map<String, dynamic>.from(b)));
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

  Future<ApiResult<void>> checkin(int id, {String? guestName, String? guestPhone, String? guestIdNumber}) async {
    try {
      // 确保总是发送一个对象，避免后端接收不到 body
      final data = <String, dynamic>{};
      if (guestName != null && guestName.isNotEmpty) data['guest_name'] = guestName;
      if (guestPhone != null && guestPhone.isNotEmpty) data['guest_phone'] = guestPhone;
      if (guestIdNumber != null && guestIdNumber.isNotEmpty) data['guest_id_number'] = guestIdNumber;
      
      final response = await _dioClient.put(
        '${ApiConstants.bookings}/$id/checkin',
        data: data,
      );
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

  Future<ApiResult<Booking>> checkinOnline(
      int bookingId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(
          '${ApiConstants.bookings}/$bookingId/checkin-online',
          data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(
            Booking.fromJson(response.data['data'] as Map<String, dynamic>));
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
    int? couponId,
    int? usedPoints,
    String? paymentMethod,
  }) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.bookings}/$bookingId/extend',
        data: {
          'new_check_out_date': newCheckOutDate.toIso8601String().split('T')[0],
          if (couponId != null) 'coupon_id': couponId,
          if (usedPoints != null && usedPoints > 0) 'used_points': usedPoints,
          if (paymentMethod != null) 'payment_method': paymentMethod,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>? ?? {});
      }
      return ApiResult.failure(response.data['message'] ?? '续住申请失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> calculateExtendPrice(int bookingId, {
    required DateTime newCheckOutDate,
    int? couponId,
    int? usedPoints,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.bookings}/$bookingId/extend-price',
        data: {
          'new_check_out_date': newCheckOutDate.toIso8601String().split('T')[0],
          if (couponId != null) 'coupon_id': couponId,
          if (usedPoints != null && usedPoints > 0) 'used_points': usedPoints,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '计算续住价格失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

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
      final queryParams = <String, dynamic>{
        'room_id': roomId,
        'check_in_date': checkInDate.toIso8601String().split('T')[0],
        'check_out_date': checkOutDate.toIso8601String().split('T')[0],
      };
      if (guestPhone != null) queryParams['guest_phone'] = guestPhone;
      if (couponId != null) queryParams['coupon_id'] = couponId;
      if (usedPoints != null) queryParams['used_points'] = usedPoints;
      if (ratePlanId != null) queryParams['rate_plan_id'] = ratePlanId;

      final response = await _dioClient.get(
        '${ApiConstants.bookings}/calculate-price',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '计算价格失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Booking?>> getMyCurrentStay() async {
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
          return ApiResult.success(
              Booking.fromJson(Map<String, dynamic>.from(checkedIn.first)));
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
          return ApiResult.success(
              Booking.fromJson(Map<String, dynamic>.from(checkedIn.first)));
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
                return ApiResult.success(
                    Booking.fromJson(Map<String, dynamic>.from(fullResponse.data['data'])));
              }
              return ApiResult.success(
                  Booking.fromJson(Map<String, dynamic>.from(lookupData)));
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

final userBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final service = ref.read(bookingServiceProvider);
  final result = await service.getBookings();
  if (result.success) {
    return result.data ?? [];
  }
  return <Booking>[];
});

final receptionBookingsProvider = FutureProvider.autoDispose.family<List<Booking>, Map<String, dynamic>>((ref, params) async {
  final service = ref.read(bookingServiceProvider);
  final result = await service.getBookings(
    page: params['page'] ?? 1,
    pageSize: params['pageSize'] ?? 10,
    status: params['status'],
    guestName: params['guestName'],
  );
  if (result.success) {
    return result.data ?? [];
  }
  return <Booking>[];
});
