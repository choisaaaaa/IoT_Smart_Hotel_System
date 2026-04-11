import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class CouponService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getCoupons({String? status, int? hotelId}) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.coupons,
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (hotelId != null) 'hotel_id': hotelId,
        },
      );
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

  Future<ApiResult<List<dynamic>>> getHotels() async {
    try {
      final response = await _dioClient.get('${ApiConstants.coupons}hotels');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取酒店列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> redeemCoupon(int id) async {
    try {
      final response = await _dioClient.post('${ApiConstants.coupons}$id/redeem');
      if (response.statusCode == 200 && response.data['code'] == 200) return ApiResult.success(null);
      return ApiResult.failure(response.data['message'] ?? '核销失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> redeemCouponByCode(String code) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.coupons}redeem',
        data: {'code': code},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '核销失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteCoupon(int id) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.coupons}$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除优惠券失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> distributeCoupon(int couponId, String phone) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.coupons}issue-to-user',
        data: {'coupon_id': couponId, 'phone': phone},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '发放优惠券失败');
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

  Future<ApiResult<Map<String, dynamic>>> updateCoupon(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put('${ApiConstants.coupons}$id', data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '更新优惠券失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getCouponStats() async {
    try {
      final response = await _dioClient.get('${ApiConstants.coupons}stats');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取优惠券统计失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final couponServiceProvider = Provider((ref) => CouponService());
