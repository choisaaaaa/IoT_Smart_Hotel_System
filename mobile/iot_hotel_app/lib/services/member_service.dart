import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class MemberService {
  final DioClient _dioClient = DioClient();
  Map<String, dynamic>? _assets;
  Map<String, dynamic>? get assets => _assets;

  Future<ApiResult<Map<String, dynamic>>> getMyAssets() async {
    try {
      final response = await _dioClient.get('${ApiConstants.members}/me');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        _assets = response.data['data'] as Map<String, dynamic>;
        return ApiResult.success(_assets!);
      }
      return ApiResult.failure(response.data['message'] ?? '获取资产失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> recharge(double amount) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.members}/recharge',
        data: {'amount': amount},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '充值失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getMyCoupons() async {
    try {
      final response = await _dioClient.get('${ApiConstants.coupons}/me');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']));
      }
      return ApiResult.failure(response.data['message'] ?? '获取优惠券失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<CheckinResult> checkin() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];

    try {
      final response = await _dioClient.post('${ApiConstants.members}/checkin');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          // 同步更新本地状态，确保即使不调用 getMyAssets 也能维持本地一致性
          await prefs.setString('last_checkin_date', today);
          return CheckinResult(
            alreadyCheckedIn: data['already_checked_in'] ?? false,
            experience: data['experience'] ?? 10,
            couponName: data['coupon_name'],
          );
        }
      } else if (response.data['code'] == 400 || response.data['message']?.toString().contains('今日已签到') == true) {
        // 后端明确返回已签到
        await prefs.setString('last_checkin_date', today);
        return CheckinResult(alreadyCheckedIn: true, experience: 0, couponName: null);
      }
    } catch (e) {
      debugPrint('Backend checkin failed: $e');
      // 如果后端失败，回退到本地检查
      final lastCheckin = prefs.getString('last_checkin_date') ?? '';
      if (lastCheckin == today) {
        return CheckinResult(alreadyCheckedIn: true, experience: 0, couponName: null);
      }
    }

    // 本地 fallback (仅当后端彻底不可用时)
    final expGain = 10 + (DateTime.now().weekday == 7 ? 20 : 0);
    await prefs.setString('last_checkin_date', today);
    return CheckinResult(alreadyCheckedIn: false, experience: expGain, couponName: null);
  }

  bool hasCheckedInToday(String? lastCheckinDate) {
    if (lastCheckinDate == null || lastCheckinDate.isEmpty) return false;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return lastCheckinDate == today;
  }
}

class CheckinResult {
  final bool alreadyCheckedIn;
  final int experience;
  final String? couponName;
  CheckinResult({required this.alreadyCheckedIn, required this.experience, this.couponName});
}

final memberServiceProvider = Provider<MemberService>((ref) => MemberService());

final myAssetsProvider = FutureProvider<ApiResult<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(memberServiceProvider);
  return service.getMyAssets();
});
