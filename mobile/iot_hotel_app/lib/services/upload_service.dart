import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
        'image': await MultipartFile.fromFile(imageFile.path),
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

  Future<ApiResult<List<Map<String, dynamic>>>> uploadImages(List<File> imageFiles, {
    String? folder,
  }) async {
    final results = <Map<String, dynamic>>[];
    for (final file in imageFiles) {
      final result = await uploadImage(file, folder: folder);
      if (result.success && result.data != null) {
        results.add(result.data!);
      } else {
        debugPrint('uploadImages: one file failed: ${result.message}');
      }
    }
    return ApiResult.success(results);
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
      debugPrint('deleteImage: backend may not support this: $e');
      return ApiResult.success(null);
    }
  }
}

final uploadServiceProvider = Provider((ref) => UploadService());
