import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../models/hotel.dart';
import '../models/room.dart';
import '../models/room_type.dart';

class HotelService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<Hotel>>> getHotels({
    String? city,
    String? keyword,
    double? lat,
    double? lng,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (lat != null) queryParams['lat'] = lat;
      if (lng != null) queryParams['lng'] = lng;
      final destination = keyword ?? city;
      if (destination != null) queryParams['destination'] = destination;

      final response = await _dioClient.get(
        '${ApiConstants.hotels}/search',
        queryParameters: queryParams..removeWhere((key, value) => value == null),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final rawList = response.data['data']['hotels'] ?? [];
        debugPrint('DEBUG: getHotels - rawList.length=${rawList.length}');
        debugPrint('DEBUG: getHotels - rawList=$rawList');
        try {
          final hotels = List<Map<String, dynamic>>.from(rawList)
              .map((h) => Hotel.fromJson(h))
              .toList();
          return ApiResult.success(hotels);
        } catch (e, stackTrace) {
          debugPrint('DEBUG: getHotels - parse error=$e');
          debugPrint('DEBUG: getHotels - stackTrace=$stackTrace');
          return ApiResult.failure('解析酒店数据失败: $e');
        }
      }
      return ApiResult.failure(response.data['message'] ?? '获取酒店列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Hotel>> getHotelById(int hotelId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.hotels}/$hotelId');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(
            Hotel.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return ApiResult.failure(response.data['message'] ?? '获取酒店详情失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<RoomType>>> getRoomAvailability(
      int hotelId, String checkIn, String checkOut) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.hotels}/$hotelId/rooms/availability',
        queryParameters: {
          'check_in': checkIn,
          'check_out': checkOut,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        List<dynamic> rawList;
        if (data is Map && data.containsKey('roomTypes')) {
          rawList = List<dynamic>.from(data['roomTypes'] ?? []);
        } else if (data is Map && data.containsKey('rooms')) {
          rawList = List<dynamic>.from(data['rooms'] ?? []);
        } else if (data is Map && data.containsKey('list')) {
          rawList = List<dynamic>.from(data['list'] ?? []);
        } else if (data is List) {
          rawList = List<dynamic>.from(data);
        } else {
          rawList = [];
        }
        final roomTypes = rawList
            .map((r) => RoomType.fromJson(r as Map<String, dynamic>))
            .toList();
        return ApiResult.success(roomTypes);
      }
      return ApiResult.failure(response.data['message'] ?? '获取房型余量失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getRoomAvailabilityRaw(
      int hotelId, String checkIn, String checkOut) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.hotels}/$hotelId/rooms/availability',
        queryParameters: {'check_in': checkIn, 'check_out': checkOut},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取房型余量失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<Room>>> getHotelRooms(int hotelId) async {
    try {
      final response = await _dioClient.get(
        '${ApiConstants.hotels}/$hotelId/rooms',
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        List<dynamic> rawList;
        if (data is Map && data.containsKey('list')) {
          rawList = List<dynamic>.from(data['list'] ?? []);
        } else if (data is List) {
          rawList = List<dynamic>.from(data);
        } else {
          rawList = [];
        }
        final rooms = rawList
            .map((r) => Room.fromJson(r as Map<String, dynamic>))
            .toList();
        return ApiResult.success(rooms);
      }
      return ApiResult.failure(response.data['message'] ?? '获取房间列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getStatistics() async {
    try {
      final response = await _dioClient.get('${ApiConstants.hotel}/statistics');

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

  Future<ApiResult<Map<String, dynamic>>> getGlobalStatistics() async {
    try {
      final response = await _dioClient.get('${ApiConstants.hotel}/statistics');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取全局统计数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getDashboardStats() async {
    try {
      final response = await _dioClient.get('${ApiConstants.hotel}/statistics');
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
          if (status == 'checked_out') todayCheckout = count;
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
        stats['total_revenue'] = raw['total_revenue'] ?? 0;
        stats['total_orders'] = raw['total_orders'] ?? 0;
        stats['monthly_revenue'] = raw['monthly_revenue'] ?? [];

        return ApiResult.success(stats);
      }
      return ApiResult.failure(response.data['message'] ?? '获取统计数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<dynamic>>> getTodayArrivals() async {
    try {
      // 获取今日日期
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final response = await _dioClient.get(
        ApiConstants.bookings,
        queryParameters: {
          'status': 'confirmed',
          'check_in_date': todayStr,
          'pageSize': 50,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final list = data['list'] ?? data['bookings'] ?? [];
        return ApiResult.success(List<dynamic>.from(list));
      }
      return ApiResult.failure(response.data['message'] ?? '获取今日到店列表失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> updateHotelInfo(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put(ApiConstants.hotel, data: data);

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
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
    try {
      final response = await _dioClient.get('${ApiConstants.hotel}/statistics', queryParameters: {
        'year': year,
        'month': month,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取报表数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getReports({int? hotelId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (hotelId != null) queryParams['hotel_id'] = hotelId;
      
      final response = await _dioClient.get('${ApiConstants.hotel}/reports', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(response.data['data'] as Map<String, dynamic>);
      }
      return ApiResult.failure(response.data['message'] ?? '获取报表数据失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getHotelImages(int hotelId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.hotels}/$hotelId/images');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        List<dynamic> rawList;
        if (data is List) {
          rawList = List<dynamic>.from(data);
        } else if (data is Map && data.containsKey('list')) {
          rawList = List<dynamic>.from(data['list'] ?? []);
        } else {
          rawList = [];
        }
        return ApiResult.success(List<Map<String, dynamic>>.from(rawList.cast<Map<String, dynamic>>()));
      }
      return ApiResult.failure(response.data['message'] ?? '获取酒店图片失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> addHotelImage(int hotelId, String imageUrl, {String? category, int? sortOrder}) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.hotels}/$hotelId/images',
        data: {
          'image_url': imageUrl,
          if (category != null) 'category': category,
          if (sortOrder != null) 'sort_order': sortOrder,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '添加酒店图片失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> deleteHotelImage(int hotelId, int imageId) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.hotels}/$hotelId/images/$imageId');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '删除酒店图片失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final hotelServiceProvider = Provider((ref) => HotelService());
