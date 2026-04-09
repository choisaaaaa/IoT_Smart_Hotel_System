import 'package:dio/dio.dart';

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? code;

  ApiResult({
    required this.success,
    this.data,
    this.message,
    this.code,
  });

  factory ApiResult.success(T data, {int code = 200}) {
    return ApiResult<T>(
      success: true,
      data: data,
      code: code,
    );
  }

  factory ApiResult.failure(String message, {int code = -1}) {
    return ApiResult<T>(
      success: false,
      message: message,
      code: code,
    );
  }

  factory ApiResult.fromResponse(Response response) {
    final data = response.data as Map<String, dynamic>;
    final code = data['code'] ?? response.statusCode ?? 200;
    final message = data['message']?.toString() ?? '';
    final resultData = data['data'];

    if (code == 200 || code == 201) {
      if (resultData is T) {
        return ApiResult<T>.success(resultData, code: code);
      }
      try {
        return ApiResult<T>.success(resultData as T, code: code);
      } catch (e) {
        return ApiResult<T>.failure('数据类型转换失败', code: code);
      }
    }
    return ApiResult<T>.failure(message, code: code);
  }
}
