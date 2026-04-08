import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class MemberService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> getMyAssets() async {
    try {
      // 获取会员信息和资产
      final response = await _dioClient.get(ApiConstants.members);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取资产失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getMyCoupons() async {
    try {
      final response = await _dioClient.get(ApiConstants.coupons);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']));
      }
      return ApiResult.failure(response.data['message'] ?? '获取优惠券失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}
