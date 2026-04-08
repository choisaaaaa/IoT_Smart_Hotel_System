import 'package:dio/dio.dart';
import '../storage/local_storage.dart';

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
    if (err.response?.statusCode == 401) {
      await _clearAuthData();
    }
    handler.next(err);
  }

  Future<void> _clearAuthData() async {
    await _localStorage.clearTokens();
    await _localStorage.remove('user_info');
  }
}
