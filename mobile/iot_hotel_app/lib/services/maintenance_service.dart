import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class MaintenanceService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getWorkOrders({
    int page = 1,
    int pageSize = 10,
    String? status,
    String? type,
    int? roomId,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.maintenance,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'status': status,
          'type': type,
          'room_id': roomId,
        }..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取工单列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getMaintenanceList({
    int page = 1,
    int pageSize = 10,
    String? status,
    String? type,
    int? roomId,
  }) async {
    return getWorkOrders(page: page, pageSize: pageSize, status: status, type: type, roomId: roomId);
  }

  Future<ApiResult<Map<String, dynamic>>> createWorkOrder(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.maintenance, data: data);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建工单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createMaintenance(Map<String, dynamic> data) async {
    return createWorkOrder(data);
  }

  Future<ApiResult<void>> updateWorkOrderStatus(int workOrderId, String status, {String? remark}) async {
    try {
      final String endpoint;
      final Map<String, dynamic> data = {};

      if (status == 'assigned') {
        endpoint = '${ApiConstants.maintenance}/$workOrderId/assign';
        data['repairer'] = remark ?? '前台';
      } else if (status == 'processing') {
        endpoint = '${ApiConstants.maintenance}/$workOrderId/status';
        data['status'] = 'processing';
      } else if (status == 'completed') {
        endpoint = '${ApiConstants.maintenance}/$workOrderId/complete';
      } else {
        endpoint = '${ApiConstants.maintenance}/$workOrderId/status';
        data['status'] = status;
      }

      final response = await _dioClient.put(endpoint, data: data);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '更新工单状态失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateMaintenanceStatus(int workOrderId, String status, {String? remark}) async {
    return updateWorkOrderStatus(workOrderId, status, remark: remark);
  }

  Future<ApiResult<Map<String, dynamic>>> getWorkOrderById(int workOrderId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.maintenance}/$workOrderId');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取工单详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteWorkOrder(int workOrderId) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.maintenance}/$workOrderId');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除工单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final maintenanceServiceProvider = Provider((ref) => MaintenanceService());
