import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
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
      final refreshToken = await _localStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final response = await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)).post('/auth/refresh', data: {'refresh_token': refreshToken});
          if (response.statusCode == 200) {
            final newToken = response.data['data']['token'];
            final newRefreshToken = response.data['data']['refresh_token'];
            await _localStorage.saveToken(newToken);
            await _localStorage.saveRefreshToken(newRefreshToken);
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
            handler.resolve(await dio.fetch(err.requestOptions));
            return;
          }
        } catch (_) {}
      }
      await _clearAuthData();
    }
    handler.next(err);
  }

  Future<void> _clearAuthData() async {
    await _localStorage.clearTokens();
    await _localStorage.remove('user_info');
  }
}
