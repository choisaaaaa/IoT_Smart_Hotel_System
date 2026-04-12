import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_state_notifier.dart';
import '../storage/local_storage.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';

class AuthInterceptor extends Interceptor {
  final LocalStorage _localStorage = LocalStorage();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _localStorage.getToken();
    if (token != null && token.isNotEmpty) { options.headers['Authorization'] = 'Bearer $token'; }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final statusCode = err.response?.statusCode;
    
    // 屏蔽环境监测API的错误日志
    if (!path.contains('/environment')) {
      debugPrint('✗ $statusCode ${path.split('/').last}');
    }

    if (statusCode == 401) {
      final isAuthMe = path.contains(ApiConstants.authMe);
      final isAuthLogin = path.contains(ApiConstants.authLogin);
      
      if (isAuthMe || isAuthLogin) {
        debugPrint('🚪 401 auth fail, logout');
        await _clearAuthData();
        authStateNotifier.clearAuth();
        
        final context = AppRouter.navigatorKey.currentContext;
        if (context != null) {
          Future.microtask(() {
            if (context.mounted) {
              context.go('/login');
            }
          });
        }
      }
    }
    handler.next(err);
  }

  Future<void> _clearAuthData() async {
    await _localStorage.clearTokens();
    await _localStorage.remove(AppConstants.userInfoKey);
  }
}

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
