import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'api_interceptor.dart';
import '../constants/api_constants.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  DioClient._internal();

  late final Dio dio;

  static String _utf8Decoder(List<int> responseBytes, RequestOptions options, ResponseBody? responseBody) {
    return utf8.decode(responseBytes, allowMalformed: true);
  }

  void init() {
    // 配置HTTP客户端，支持HTTPS证书验证
    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // 生产环境应该严格验证证书，开发环境可以暂时允许
        if (kDebugMode) {
          // 开发环境：允许自签名证书（仅用于本地测试）
          return host == 'localhost' || host == '127.0.0.1';
        }
        // 生产环境：严格验证证书
        return false;
      };

    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
      },
      responseDecoder: _utf8Decoder,
    ))
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => httpClient,
      );

    dio.interceptors.addAll([
      AuthInterceptor(),
      _ResponseNormalizer(),
      _CompactLogInterceptor(),
    ]);
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.post(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.put(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.patch(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.delete(path, data: data, queryParameters: queryParameters, options: options);
  }
}

class _ResponseNormalizer extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true && data['code'] == null) {
      response.data = {
        'code': 200,
        'data': data['data'],
        'message': data['message'] ?? '操作成功',
      };
    }
    handler.next(response);
  }
}

class _CompactLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.uri.path;
    // 屏蔽环境监测API的请求日志
    if (!path.contains('/environment')) {
      debugPrint('→ ${options.method} $path');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final code = response.statusCode ?? 0;
    final path = response.requestOptions.uri.path;
    // 屏蔽环境监测API的响应日志
    if (!path.contains('/environment')) {
      debugPrint('← $code ${path.split('/').last}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final code = err.response?.statusCode ?? 0;
    final path = err.requestOptions.uri.path;
    final msg = err.response?.data?['message'] ?? err.message ?? '';
    // 屏蔽环境监测API的错误日志
    if (!path.contains('/environment')) {
      debugPrint('✗ $code ${path.split('/').last} - $msg');
      debugPrint('✗ 完整路径: $path');
    }
    handler.next(err);
  }
}
