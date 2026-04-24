import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../core/constants/app_constants.dart';
import '../core/auth/auth_state_notifier.dart';
import '../core/storage/local_storage.dart';
import '../models/user.dart';

class AuthService {
  final DioClient _dioClient = DioClient();
  final LocalStorage _localStorage = LocalStorage();

  Future<ApiResult<Map<String, dynamic>>> login(String username, String password) async {
    try {
      final response = await _dioClient.post(ApiConstants.authLogin, data: {
        'phone': username,
        'password': password,
      });
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        await _localStorage.saveToken(data['token']);
        if (data['sessionToken'] != null) {
          await _localStorage.saveSessionToken(data['sessionToken']);
        }
        await _localStorage.save(AppConstants.userInfoKey, jsonEncode(data['user']));
        final user = data['user'] as Map<String, dynamic>?;
        // 保存 hotel_id 到本地存储
        if (user?['hotel_id'] != null) {
          await _localStorage.save('hotel_id', user!['hotel_id'].toString());
        }
        authStateNotifier.setAuth(
          token: data['token'] as String? ?? '',
          userId: user?['id']?.toString() ?? '',
          username: user?['username'] as String? ?? '',
          role: user?['role'] as String? ?? 'customer',
          phone: user?['phone'] as String?,
          uid: user?['uid'] as String?,
        );
        // 登录成功后异步获取完整用户信息（包含会员等级、积分等）
        _syncMemberInfo();
        return ApiResult.success(data as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '登录失败');
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? '网络错误：${e.message}';
      return ApiResult.failure(message);
    } catch (e) {
      return ApiResult.failure('系统错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> sendResetCode(String phone) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.authResetPasswordSendCode,
        data: {'phone': phone},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 200) {
          return ApiResult.success(data['data'] ?? {'message': '验证码已发送'});
        } else {
          return ApiResult.failure(data['message'] ?? '发送验证码失败');
        }
      }
      return ApiResult.failure('服务器错误');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> resetPassword(String phone, String newPassword, {String? verificationCode}) async {
    try {
      final data = {
        'phone': phone,
        'new_password': newPassword,
      };
      if (verificationCode != null) {
        data['verification_code'] = verificationCode;
      }
      final response = await _dioClient.post(
        ApiConstants.authResetPassword,
        data: data,
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 200) {
          return ApiResult.success(data['data'] ?? {'message': '密码重置成功'});
        } else {
          return ApiResult.failure(data['message'] ?? '重置失败');
        }
      }
      return ApiResult.failure('服务器错误');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> register(String username, String password, String? email, {int? hotelId, String? phone, String? role}) async {
     try {
       final response = await _dioClient.post(ApiConstants.authRegister, data: {
         'username': username,
         'password': password,
         'email': email,
         if (hotelId != null) 'hotel_id': hotelId,
         if (phone != null) 'phone': phone,
         if (role != null) 'role': role,
       });
 
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '注册失败');
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? '注册失败：${e.message}';
      return ApiResult.failure(message);
    } catch (e) {
      return ApiResult.failure('系统错误：$e');
    }
  }

  Future<void> logout() async {
    try { await _dioClient.post(ApiConstants.authLogout); } catch (_) {}
    await _localStorage.clearTokens();
    await _localStorage.remove(AppConstants.userInfoKey);
    authStateNotifier.clearAuth();
  }

  Future<bool> isLoggedIn() async { final token = await _localStorage.getToken(); return token != null && token.isNotEmpty; }

  Future<User?> getCurrentUser() async {
    final userInfoStr = await _localStorage.read(AppConstants.userInfoKey);
    if (userInfoStr != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        return User.fromJson(userMap);
      } catch (e) {
        debugPrint('✗ decodeUser: $e');
      }
    }
    return null;
  }

  Future<String?> getUserRole() async { final user = await getCurrentUser(); return user?.role; }

  Future<ApiResult<Map<String, dynamic>>> getMe() async {
    try {
      final response = await _dioClient.get(ApiConstants.authMe);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>? ?? data;
        await _localStorage.save(AppConstants.userInfoKey, jsonEncode(userData));
        // 保存 hotel_id 到本地存储
        if (userData['hotel_id'] != null) {
          await _localStorage.save('hotel_id', userData['hotel_id'].toString());
        }
        return ApiResult.success(data);
      }
      return ApiResult.failure(response.data['message'] ?? '获取用户信息失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> refreshCurrentUser() async {
    final result = await getMe();
    if (result.success) {
      final userInfoStr = await _localStorage.read(AppConstants.userInfoKey);
      if (userInfoStr != null) {
        final Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        final token = await _localStorage.getToken();
        authStateNotifier.setAuth(
          token: token ?? '',
          userId: userMap['id']?.toString() ?? '',
          username: userMap['username'] as String? ?? '',
          role: userMap['role'] as String? ?? 'customer',
          phone: userMap['phone'] as String?,
          uid: userMap['uid'] as String?,
        );
      }
    }
    return result;
  }

  Future<int?> getCurrentHotelId() async {
    final hotelIdStr = await _localStorage.read('hotel_id');
    if (hotelIdStr != null && hotelIdStr.isNotEmpty) {
      return int.tryParse(hotelIdStr);
    }
    final userInfoStr = await _localStorage.read(AppConstants.userInfoKey);
    if (userInfoStr != null) {
      final Map<String, dynamic> userMap = jsonDecode(userInfoStr);
      final hotelId = userMap['hotel_id'];
      if (hotelId != null) {
        return hotelId is int ? hotelId : int.tryParse(hotelId.toString());
      }
    }
    return null;
  }

  Future<ApiResult<Map<String, dynamic>>> qrConfirm(String token) async {
    try {
      final response = await _dioClient.post(ApiConstants.authQrConfirm, data: {
        'token': token,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '扫码确认失败');
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? '网络错误：${e.message}';
      return ApiResult.failure(message);
    } catch (e) {
      return ApiResult.failure('系统错误：$e');
    }
  }

  /// 登录成功后异步同步完整用户信息（会员等级、积分等）
  Future<void> _syncMemberInfo() async {
    try {
      // 先通过 /auth/me 获取最新用户信息
      final meResult = await getMe();
      if (!meResult.success) return;

      // 尝试获取会员信息（如果后端支持 /members/me 或 /members/info）
      try {
        final memberResponse = await _dioClient.get('${ApiConstants.members}/me');
        if (memberResponse.statusCode == 200 && memberResponse.data['code'] == 200) {
          final memberData = memberResponse.data['data'];
          if (memberData != null) {
            // 将会员信息合并保存到本地
            await _localStorage.save('member_info', jsonEncode(memberData));
            debugPrint('会员信息已同步');
          }
        }
      } catch (_) {
        // 会员接口可能不存在或未开通，忽略错误
        debugPrint('会员信息接口不可用，跳过同步');
      }
    } catch (e) {
      debugPrint('同步用户信息失败: $e');
    }
  }

  /// 获取缓存的会员信息
  Future<Map<String, dynamic>?> getMemberInfo() async {
    final infoStr = await _localStorage.read('member_info');
    if (infoStr != null) {
      try {
        return jsonDecode(infoStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('解析会员信息失败: $e');
      }
    }
    return null;
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
