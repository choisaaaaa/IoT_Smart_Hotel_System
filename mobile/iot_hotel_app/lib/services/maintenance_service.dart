import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class MaintenanceService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getMaintenanceTickets({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? faultType,
    String? priority,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (status != null) queryParams['status'] = status;
      if (faultType != null) queryParams['fault_type'] = faultType;
      if (priority != null) queryParams['priority'] = priority;

      final response = await _dioClient.get(
        ApiConstants.maintenance,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is Map && data.containsKey('list')) {
          return ApiResult.success(List<dynamic>.from(data['list'] ?? []));
        } else if (data is List) {
          return ApiResult.success(List<dynamic>.from(data));
        }
        return ApiResult.success([]);
      }
      return ApiResult.failure(response.data['message'] ?? '获取维修工单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createMaintenanceTicket(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.maintenance, data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建维修工单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> assignMaintenance(int id, dynamic repairer) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.maintenance}/$id/assign',
        data: {'repairer': repairer},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '分配维修失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateMaintenanceStatus(int id, String status) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.maintenance}/$id/status',
        data: {'status': status},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '更新工单状态失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> completeMaintenance(int id) async {
    try {
      final response = await _dioClient.put('${ApiConstants.maintenance}/$id/complete');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '完成维修失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteMaintenance(int id) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.maintenance}/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除工单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getWorkOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? faultType,
    String? priority,
  }) async {
    return getMaintenanceTickets(
      page: page, pageSize: pageSize, status: status,
      faultType: faultType, priority: priority,
    );
  }

  Future<ApiResult<Map<String, dynamic>>> createWorkOrder(Map<String, dynamic> data) async {
    return createMaintenanceTicket(data);
  }

  Future<ApiResult<void>> updateWorkOrderStatus(int id, String status) async {
    return updateMaintenanceStatus(id, status);
  }
}

final maintenanceServiceProvider = Provider((ref) => MaintenanceService());
