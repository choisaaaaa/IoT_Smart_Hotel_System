import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class PaymentService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> createPayment(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.payments, data: data);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建支付订单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> pay(int paymentId, {String? transactionNo}) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.payments}$paymentId/pay',
        data: {'transaction_no': transactionNo},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '支付失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getPaymentStatus(String paymentId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.payments}$paymentId');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
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
      return ApiResult.failure(response.data['message'] ?? '获取支付历史失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> refundPayment(int bookingId, {String? reason}) async {
    try {
      final cancelResult = await _dioClient.put(
        '${ApiConstants.bookings}$bookingId/cancel',
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
}

final paymentServiceProvider = Provider((ref) => PaymentService());
