import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class UserService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getUsers({
    int page = 1,
    int pageSize = 10,
    String? role,
    String? keyword,
    String? status,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.users,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'role': role,
          'keyword': keyword,
          'status': status,
        }..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取用户列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getUserById(int userId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.users}$userId');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取用户详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createUser(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.users, data: data);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建用户失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateUser(int userId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put('${ApiConstants.users}$userId', data: data);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '更新用户失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateUserRole(int userId, String role) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.users}$userId/role',
        data: {'role': role},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '更新角色失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> disableUser(int userId, {String? reason}) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.users}$userId/disable',
        data: {'reason': reason},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '禁用用户失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> enableUser(int userId) async {
    try {
      final response = await _dioClient.post('${ApiConstants.users}$userId/enable');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '启用用户失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final userServiceProvider = Provider((ref) => UserService());
