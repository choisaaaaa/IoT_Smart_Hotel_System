import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class UploadService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> uploadImage(dynamic formData, {String? folder}) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.upload}/image',
        data: formData,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '上传图片失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final uploadServiceProvider = Provider((ref) => UploadService());
