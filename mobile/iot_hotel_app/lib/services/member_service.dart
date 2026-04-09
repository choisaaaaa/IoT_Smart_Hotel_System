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
      final response = await _dioClient.get('${ApiConstants.members}me');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        _assets = response.data['data'] as Map<String, dynamic>;
        return ApiResult.success(_assets!);
      }
      return ApiResult.failure(response.data['message'] ?? '获取资产失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getMyCoupons() async {
    try {
      final response = await _dioClient.get('${ApiConstants.coupons}me');
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
    final lastCheckin = prefs.getString('last_checkin_date') ?? '';
    if (lastCheckin == today) {
      return CheckinResult(alreadyCheckedIn: true, experience: 0, couponName: null);
    }

    try {
      final response = await _dioClient.post('${ApiConstants.members}checkin');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          return CheckinResult(
            alreadyCheckedIn: data['already_checked_in'] ?? false,
            experience: data['experience'] ?? 10,
            couponName: data['coupon_name'],
          );
        }
      }
    } catch (e) {
      debugPrint('Backend checkin not available, using local fallback: $e');
    }

    final expGain = 10 + (DateTime.now().weekday == 7 ? 20 : 0);
    final currentExp = prefs.getInt('checkin_experience') ?? 0;
    await prefs.setInt('checkin_experience', currentExp + expGain);
    await prefs.setString('last_checkin_date', today);
    final checkinDays = prefs.getInt('checkin_streak') ?? 0;
    final lastDate = lastCheckin.isNotEmpty ? DateTime.tryParse(lastCheckin) : null;
    if (lastDate != null && DateTime.now().difference(lastDate).inDays == 1) {
      await prefs.setInt('checkin_streak', checkinDays + 1);
    } else {
      await prefs.setInt('checkin_streak', 1);
    }
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
