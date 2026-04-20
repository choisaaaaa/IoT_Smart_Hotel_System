import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class PaymentService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> createPayment(Map<String, dynamic> data) async {
    try {
      debugPrint('💳 [PaymentService] Creating payment with data: $data');
      final response = await _dioClient.post(ApiConstants.payments, data: data);
      debugPrint('💳 [PaymentService] Response: status=${response.statusCode}, data=${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建支付订单失败');
    } on DioException catch (e) {
      final serverMsg = e.response?.data?['message']?.toString();
      if (serverMsg != null && serverMsg.isNotEmpty) {
        return ApiResult.failure(serverMsg);
      }
      return ApiResult.failure('网络错误，请重试');
    } catch (e) {
      debugPrint('💳 [PaymentService] Error creating payment: $e');
      return ApiResult.failure('创建支付订单失败');
    }
  }

  Future<ApiResult<void>> pay(int paymentId, {String? transactionNo}) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.payments}/$paymentId/pay',
        data: {'transaction_no': transactionNo},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '支付失败');
    } on DioException catch (e) {
      final serverMsg = e.response?.data?['message']?.toString();
      if (serverMsg != null && serverMsg.isNotEmpty) {
        return ApiResult.failure(serverMsg);
      }
      return ApiResult.failure('网络错误，请重试');
    } catch (e) {
      return ApiResult.failure('支付失败：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getPaymentStatus(String paymentId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.payments}/$paymentId');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      try {
        final bookingResponse = await _dioClient.get(
          ApiConstants.bookings,
          queryParameters: {'pageSize': 50},
        );
        if (bookingResponse.statusCode == 200 && bookingResponse.data['code'] == 200) {
          final data = bookingResponse.data['data'];
          List<dynamic> bookings = [];
          if (data is Map && data.containsKey('list')) {
            bookings = List<dynamic>.from(data['list'] ?? []);
          } else if (data is List) {
            bookings = List<dynamic>.from(data);
          }
          for (final b in bookings) {
            if (b['payment_id']?.toString() == paymentId || b['id']?.toString() == paymentId) {
              return ApiResult.success({
                'id': b['payment_id'] ?? b['id'],
                'status': b['payment_status'] ?? b['status'] == 'confirmed' ? 'paid' : 'pending',
                'amount': b['total_price'],
              });
            }
          }
        }
      } catch (_) {}
      return ApiResult.failure(response.data['message'] ?? '获取支付状态失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getPaymentHistory({
    int page = 1,
    int pageSize = 10,
    String? status,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.payments,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'status': status,
        }..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
      }

      try {
        final bookingResponse = await _dioClient.get(
          ApiConstants.bookings,
          queryParameters: {'page': page, 'pageSize': pageSize},
        );
        if (bookingResponse.statusCode == 200 && bookingResponse.data['code'] == 200) {
          final data = bookingResponse.data['data'];
          List<dynamic> bookings = [];
          if (data is Map && data.containsKey('list')) {
            bookings = List<dynamic>.from(data['list'] ?? []);
          } else if (data is List) {
            bookings = List<dynamic>.from(data);
          }
          return ApiResult.success(bookings.where((b) {
            if (status != null && b['payment_status'] != status && b['status'] != status) return false;
            return b['total_price'] != null;
          }).map((b) => {
            'id': b['payment_id'] ?? b['id'],
            'order_type': 'booking',
            'order_id': b['id'],
            'amount': b['total_price'],
            'status': b['payment_status'] ?? (b['status'] == 'confirmed' ? 'paid' : 'pending'),
            'payment_method': b['payment_method'],
            'created_at': b['created_at'],
          }).toList());
        }
      } catch (_) {}

      return ApiResult.failure(response.data['message'] ?? '获取支付历史失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> refundPayment(int bookingId, {String? reason}) async {
    try {
      final cancelResult = await _dioClient.put(
        '${ApiConstants.bookings}/$bookingId/cancel',
        data: {'reason': reason},
      );
      if (cancelResult.statusCode == 200 && cancelResult.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(cancelResult.data['message'] ?? '退款/取消失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getRevenueStats({String? range}) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.payments}/stats/revenue',
        queryParameters: {
          if (range != null) 'range': range,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.success({
        'today_revenue': 0.0,
        'month_revenue': 0.0,
        'pending_bills': 0,
        'revenue_trend': <dynamic>[],
        'income_breakdown': <String, dynamic>{},
      });
    } catch (e) {
      return ApiResult.success({
        'today_revenue': 0.0,
        'month_revenue': 0.0,
        'pending_bills': 0,
        'revenue_trend': <dynamic>[],
        'income_breakdown': <String, dynamic>{},
      });
    }
  }

  Future<ApiResult<List<dynamic>>> getBills({int? limit}) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.payments,
        queryParameters: {
          'pageSize': limit ?? 20,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
      }
      return ApiResult.success(<dynamic>[]);
    } catch (e) {
      return ApiResult.success(<dynamic>[]);
    }
  }
}

final paymentServiceProvider = Provider((ref) => PaymentService());
