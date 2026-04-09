import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'core/network/dio_client.dart';
import 'core/network/api_interceptor.dart';
import 'core/auth/auth_state_notifier.dart';
import 'core/storage/local_storage.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/api_constants.dart';

class IoTHotelApp extends ConsumerStatefulWidget {
  const IoTHotelApp({super.key});

  @override
  ConsumerState<IoTHotelApp> createState() => _IoTHotelAppState();
}

class _IoTHotelAppState extends ConsumerState<IoTHotelApp> {
  @override
  void initState() {
    super.initState();
    DioClient().init();
    _restoreAuthState();
  }

  Future<void> _restoreAuthState() async {
    try {
      final localStorage = LocalStorage();
      final token = await localStorage.getToken();
      if (token == null || token.isEmpty) {
        authStateNotifier.clearAuth();
        return;
      }

      final userInfoStr = await localStorage.read(AppConstants.userInfoKey);
      if (userInfoStr != null) {
        final Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        authStateNotifier.setAuth(
          token: token,
          userId: userMap['id']?.toString() ?? '',
          username: userMap['username'] as String? ?? '',
          role: userMap['role'] as String? ?? 'user',
          phone: userMap['phone'] as String?,
          uid: userMap['uid'] as String?,
        );
      }

      try {
        final dio = DioClient();
        final response = await dio.get(ApiConstants.authMe);
        if (response.statusCode == 200 && response.data['code'] == 200) {
          final data = response.data['data'];
          final user = data['user'] as Map<String, dynamic>?;
          if (user != null) {
            await localStorage.save(AppConstants.userInfoKey, jsonEncode(user));
            authStateNotifier.setAuth(
              token: token,
              userId: user['id']?.toString() ?? '',
              username: user['username'] as String? ?? '',
              role: user['role'] as String? ?? 'user',
              phone: user['phone'] as String?,
              uid: user['uid'] as String?,
            );
          }
        }
      } catch (e) {
        debugPrint('Refresh auth state from server failed: $e');
      }
    } catch (e) {
      debugPrint('Restore auth state failed: $e');
      authStateNotifier.clearAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '智联酒店',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        return Navigator(
          key: AppRouter.navigatorKey,
          onDidRemovePage: (Page<void> page) {},
          pages: [
            MaterialPage(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
