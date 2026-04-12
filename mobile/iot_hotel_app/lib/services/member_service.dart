import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../models/member.dart';
import '../models/coupon.dart';

class MemberService {
  final DioClient _dioClient = DioClient();
  Member? _cachedMember;
  Member? get cachedMember => _cachedMember;

  Future<ApiResult<List<dynamic>>> getMemberList({String? search}) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.members,
        queryParameters: {if (search != null) 'search': search},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        List<dynamic> rawList;
        if (data is List) {
          rawList = List<dynamic>.from(data);
        } else if (data is Map && data.containsKey('list')) {
          rawList = List<dynamic>.from(data['list'] ?? []);
        } else {
          rawList = [];
        }
        return ApiResult.success(rawList);
      }
      return ApiResult.failure(response.data['message'] ?? '获取会员列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Member>> getMyAssets() async {
    try {
      final response = await _dioClient.get('${ApiConstants.members}/me');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        _cachedMember = Member.fromJson(response.data['data'] as Map<String, dynamic>);
        return ApiResult.success(_cachedMember!);
      }
      return ApiResult.failure(response.data['message'] ?? '获取资产失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Member>> recharge(double amount) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.members}/recharge',
        data: {'amount': amount},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final member = Member.fromJson(response.data['data'] as Map<String, dynamic>);
        _cachedMember = member;
        return ApiResult.success(member);
      }
      return ApiResult.failure(response.data['message'] ?? '充值失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<Coupon>>> getMyCoupons() async {
    try {
      final response = await _dioClient.get('${ApiConstants.coupons}/me');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        List<dynamic> rawList;
        if (data is List) {
          rawList = List<dynamic>.from(data);
        } else if (data is Map && data.containsKey('list')) {
          rawList = List<dynamic>.from(data['list'] ?? []);
        } else {
          rawList = [];
        }
        final coupons = rawList
            .map((c) => Coupon.fromJson(c as Map<String, dynamic>))
            .toList();
        return ApiResult.success(coupons);
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
          await prefs.setString('last_checkin_date', today);
          return CheckinResult(
            alreadyCheckedIn: data['already_checked_in'] ?? false,
            experience: data['experience'] ?? 10,
            couponName: data['coupon_name'],
          );
        }
      } else if (response.data['code'] == 400 || response.data['message']?.toString().contains('今日已签到') == true) {
        await prefs.setString('last_checkin_date', today);
        return CheckinResult(alreadyCheckedIn: true, experience: 0, couponName: null);
      }
    } catch (e) {
      debugPrint('Backend checkin failed: $e');
      final lastCheckin = prefs.getString('last_checkin_date') ?? '';
      if (lastCheckin == today) {
        return CheckinResult(alreadyCheckedIn: true, experience: 0, couponName: null);
      }
    }

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

final myAssetsProvider = FutureProvider<ApiResult<Member>>((ref) async {
  final service = ref.watch(memberServiceProvider);
  return service.getMyAssets();
});
