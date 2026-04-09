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

  static bool isResponseSuccess(Map<String, dynamic>? data) {
    if (data == null) return false;
    final code = data['code'];
    if (code == 200 || code == 201) return true;
    if (data['success'] == true) return true;
    return false;
  }

  static String? getResponseMessage(Map<String, dynamic>? data) {
    if (data == null) return null;
    return data['message']?.toString();
  }

  factory ApiResult.fromResponse(Response response) {
    final data = response.data as Map<String, dynamic>?;
    if (data == null) {
      return ApiResult<T>.failure('响应数据为空');
    }

    final code = data['code'] ?? response.statusCode ?? 200;
    final message = data['message']?.toString() ?? '';
    final resultData = data['data'];

    final isSuccess = (code == 200 || code == 201) || data['success'] == true;

    if (isSuccess) {
      if (resultData is T) {
        return ApiResult<T>.success(resultData, code: code is int ? code : 200);
      }
      try {
        return ApiResult<T>.success(resultData as T, code: code is int ? code : 200);
      } catch (e) {
        return ApiResult<T>.failure('数据类型转换失败', code: code is int ? code : 200);
      }
    }
    return ApiResult<T>.failure(message.isNotEmpty ? message : '操作失败', code: code is int ? code : -1);
  }
}
