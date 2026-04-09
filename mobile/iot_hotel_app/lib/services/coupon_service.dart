import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class CouponService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getCoupons() async {
    try {
      final response = await _dioClient.get(ApiConstants.coupons);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) return ApiResult.success(List<dynamic>.from(data));
        return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取优惠券列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> receiveCoupon(int couponId) async {
    try {
      final response = await _dioClient.post('${ApiConstants.coupons}$couponId/receive');
      if (response.statusCode == 200 && response.data['code'] == 200) return ApiResult.success(null);
      return ApiResult.failure(response.data['message'] ?? '领取优惠券失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createCoupon(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.coupons, data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建优惠券失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final couponServiceProvider = Provider((ref) => CouponService());
