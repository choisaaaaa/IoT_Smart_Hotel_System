import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class DeliveryService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getDeliveryOrders({
    int page = 1,
    int pageSize = 10,
    String? status,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.delivery,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'status': status,
        }..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取送物订单失败');
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
      return ApiResult.failure(response.data['message'] ?? '创建送物订单失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> createDelivery(Map<String, dynamic> data) async {
    return createDeliveryOrder(data);
  }

  Future<ApiResult<void>> updateDeliveryStatus(int deliveryId, String status) async {
    try {
      final response = await _dioClient.put(
        '${ApiConstants.delivery}$deliveryId/complete',
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '更新送物状态失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateOrderStatus(int deliveryId, String status) async {
    return updateDeliveryStatus(deliveryId, status);
  }

  static const List<Map<String, dynamic>> deliveryItemCatalog = [
    {'id': 1, 'name': '矿泉水', 'category': '饮品', 'price': 5},
    {'id': 2, 'name': '毛巾', 'category': '日用品', 'price': 0},
    {'id': 3, 'name': '拖鞋', 'category': '日用品', 'price': 0},
    {'id': 4, 'name': '牙刷套装', 'category': '日用品', 'price': 0},
    {'id': 5, 'name': '充电器', 'category': '电子', 'price': 10},
    {'id': 6, 'name': '额外枕头', 'category': '床品', 'price': 0},
    {'id': 7, 'name': '咖啡', 'category': '饮品', 'price': 15},
    {'id': 8, 'name': '茶包', 'category': '饮品', 'price': 8},
  ];

  Future<ApiResult<List<dynamic>>> getDeliveryItems() async {
    return ApiResult.success(deliveryItemCatalog);
  }
}

final deliveryServiceProvider = Provider<DeliveryService>((ref) => DeliveryService());

final deliveryOrdersProvider = FutureProvider.autoDispose((ref) async {
  final result = await ref.read(deliveryServiceProvider).getDeliveryOrders();
  if (result.success) {
    return result.data ?? <dynamic>[];
  }
  return <dynamic>[];
});
