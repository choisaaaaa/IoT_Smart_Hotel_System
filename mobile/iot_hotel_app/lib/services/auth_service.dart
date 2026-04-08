import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../core/constants/app_constants.dart';
import '../core/storage/local_storage.dart';
import '../../models/user.dart';

class AuthService {
  final DioClient _dioClient = DioClient();
  final LocalStorage _localStorage = LocalStorage();

  Future<ApiResult<Map<String, dynamic>>> login(String username, String password) async {
    try {
      final response = await _dioClient.post(ApiConstants.authLogin, data: {
        'username': username,
        'password': password,
      });
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        await _localStorage.saveToken(data['token']);
        if (data['sessionToken'] != null) {
          await _localStorage.saveSessionToken(data['sessionToken']);
        }
        await _localStorage.save(AppConstants.userInfoKey, jsonEncode(data['user']));
         return ApiResult.success(data as Map<String, dynamic>);
       }
       return ApiResult.failure(response.data['message'] ?? '登录失败');
     } catch (e) {
       return ApiResult.failure('网络错误：$e');
     }
   }
 
   Future<ApiResult<Map<String, dynamic>>> register(String username, String password, String? email) async {
     try {
       final response = await _dioClient.post(ApiConstants.authRegister, data: {
         'username': username,
         'password': password,
         'email': email,
       });
 
       if (response.statusCode == 200 && response.data['code'] == 200) {
         return ApiResult.success(response.data['data'] as Map<String, dynamic>);
       }
       return ApiResult.failure(response.data['message'] ?? '注册失败');
     } catch (e) {
       return ApiResult.failure('网络错误：$e');
     }
   }

  Future<void> logout() async {
    try { await _dioClient.post(ApiConstants.authLogout); } catch (_) {}
    await _localStorage.clearTokens();
    await _localStorage.remove(AppConstants.userInfoKey);
  }

  Future<bool> isLoggedIn() async { final token = await _localStorage.getToken(); return token != null && token.isNotEmpty; }

  Future<User?> getCurrentUser() async {
    final userInfoStr = await _localStorage.read(AppConstants.userInfoKey);
    if (userInfoStr != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        return User.fromJson(userMap);
      } catch (e) {
        debugPrint('Error decoding user info: $e');
      }
    }
    return null;
  }

  Future<String?> getUserRole() async { final user = await getCurrentUser(); return user?.role; }
}
