import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class DeliveryService {
  final DioClient _dioClient = DioClient();

  static const List<Map<String, dynamic>> deliveryItemCatalog = [
    {'id': 1, 'name': '矿泉水', 'category': 'beverage', 'price': 3.0},
    {'id': 2, 'name': '可乐', 'category': 'beverage', 'price': 5.0},
    {'id': 3, 'name': '橙汁', 'category': 'beverage', 'price': 8.0},
    {'id': 4, 'name': '咖啡', 'category': 'beverage', 'price': 10.0},
    {'id': 5, 'name': '方便面', 'category': 'food', 'price': 6.0},
    {'id': 6, 'name': '饼干', 'category': 'food', 'price': 5.0},
    {'id': 7, 'name': '水果拼盘', 'category': 'food', 'price': 15.0},
    {'id': 8, 'name': '毛巾', 'category': 'daily', 'price': 0.0},
    {'id': 9, 'name': '洗漱套装', 'category': 'daily', 'price': 0.0},
    {'id': 10, 'name': '拖鞋', 'category': 'daily', 'price': 0.0},
    {'id': 11, 'name': '充电器', 'category': 'other', 'price': 10.0},
    {'id': 12, 'name': '数据线', 'category': 'other', 'price': 8.0},
  ];

  Future<ApiResult<List<dynamic>>> getDeliveryOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? itemCategory,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (status != null) queryParams['status'] = status;
      if (itemCategory != null) queryParams['item_category'] = itemCategory;

      final response = await _dioClient.get(
        ApiConstants.delivery,
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
      return ApiResult.failure(response.data['message'] ?? '获取配送订单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createDeliveryOrder(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(ApiConstants.delivery, data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '创建配送订单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> completeDeliveryOrder(int id) async {
    try {
      final response = await _dioClient.put('${ApiConstants.delivery}/$id/complete');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '完成配送失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateDeliveryStatus(int id, String status) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.delivery}/$id/status',
        data: {'status': status},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '更新配送状态失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final deliveryServiceProvider = Provider((ref) => DeliveryService());
