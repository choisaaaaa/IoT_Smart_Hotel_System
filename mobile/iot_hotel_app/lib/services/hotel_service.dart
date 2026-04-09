import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class HotelService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getHotels({
    String? city,
    double? lat,
    double? lng,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.hotels}search',
        queryParameters: {
          'destination': city,
          'lat': lat,
          'lng': lng,
          'page': page,
          'pageSize': pageSize,
        }..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']['hotels'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取酒店列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getHotelById(int hotelId) async {
    try {
      final response = await _dioClient.get(ApiConstants.hotel);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取酒店详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getRoomAvailability(int hotelId, String checkIn, String checkOut) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.rooms,
        queryParameters: {
          'pageSize': 100,
        },
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
      return ApiResult.failure(response.data['message'] ?? '获取房型余量失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getStatistics() async {
    try {
      final response = await _dioClient.get('${ApiConstants.hotel}statistics');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取统计数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getHotelInfo() async {
    try {
      final response = await _dioClient.get(ApiConstants.hotel);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取酒店信息失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getDashboardStats() async {
    try {
      final response = await _dioClient.get('${ApiConstants.hotel}statistics');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final raw = response.data['data'] as Map<String, dynamic>;
        final Map<String, dynamic> stats = {};

        final rooms = raw['rooms'] as List<dynamic>? ?? [];
        int totalRooms = 0;
        int availableRooms = 0;
        int occupiedRooms = 0;
        for (final r in rooms) {
          final count = (r['count'] as num?)?.toInt() ?? 0;
          totalRooms += count;
          final status = r['room_status']?.toString() ?? '';
          if (status == 'available') availableRooms = count;
          if (status == 'occupied') occupiedRooms = count;
        }

        final bookings = raw['bookings'] as List<dynamic>? ?? [];
        int todayCheckin = 0;
        int todayCheckout = 0;
        int currentGuests = 0;
        for (final b in bookings) {
          final count = (b['count'] as num?)?.toInt() ?? 0;
          final status = b['status']?.toString() ?? '';
          if (status == 'confirmed') todayCheckin = count;
          if (status == 'checked_in') currentGuests = count;
        }

        stats['total_rooms'] = totalRooms;
        stats['available_rooms'] = availableRooms;
        stats['occupied_rooms'] = occupiedRooms;
        stats['occupancy_rate'] = totalRooms > 0 ? occupiedRooms / totalRooms : 0;
        stats['today_checkin'] = todayCheckin;
        stats['today_checkout'] = todayCheckout;
        stats['current_guests'] = currentGuests;
        stats['pending_tasks'] = raw['pending_maintenance'] ?? 0;
        stats['today_bookings'] = todayCheckin;
        stats['online_devices'] = 0;

        return ApiResult.success(stats);
      }
      return ApiResult.failure(response.data['message'] ?? '获取统计数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getTodayArrivals() async {
    try {
      final response = await _dioClient.get(
        ApiConstants.bookings,
        queryParameters: {'status': 'confirmed', 'pageSize': 50},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']['list'] ?? []));
      }
      return ApiResult.failure(response.data['message'] ?? '获取今日到店列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> updateHotelInfo(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put(ApiConstants.hotel, data: data);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '更新酒店信息失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getMonthlyReport({
    required String year,
    required String month,
  }) async {
    return getStatistics();
  }
}

final hotelServiceProvider = Provider((ref) => HotelService());
