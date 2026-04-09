import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class UploadService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> uploadImage(File imageFile, {
    String? folder,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path),
        if (folder != null) 'folder': folder,
      });

      final response = await _dioClient.post(
        '${ApiConstants.upload}image',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '上传图片失败');
    } catch (e) {
      return ApiResult.failure('上传图片失败：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> uploadImages(List<File> imageFiles, {
    String? folder,
  }) async {
    try {
      final formData = FormData.fromMap({
        'files': await Future.wait(
          imageFiles.map((file) => MultipartFile.fromFile(file.path)),
        ),
        if (folder != null) 'folder': folder,
      });

      final response = await _dioClient.post(
        '${ApiConstants.upload}images',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '批量上传图片失败');
    } catch (e) {
      return ApiResult.failure('批量上传图片失败：$e');
    }
  }

  Future<ApiResult<void>> deleteImage(String imageUrl) async {
    try {
      final response = await _dioClient.delete(
        '${ApiConstants.upload}image',
        queryParameters: {'url': imageUrl},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除图片失败');
    } catch (e) {
      return ApiResult.failure('删除图片失败：$e');
    }
  }
}

final uploadServiceProvider = Provider((ref) => UploadService());
