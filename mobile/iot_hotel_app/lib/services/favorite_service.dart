import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../models/hotel.dart';

class FavoriteService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<Hotel>>> getFavorites() async {
    try {
      final response = await _dioClient.get('${ApiConstants.hotels}/favorites');
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
        final hotels = rawList
            .map((h) => Hotel.fromJson(h as Map<String, dynamic>))
            .toList();
        return ApiResult.success(hotels);
      }
      return ApiResult.failure(response.data['message'] ?? '获取收藏列表失败');
    } catch (e) {
      return _getLocalFavorites();
    }
  }

  Future<ApiResult<void>> addFavorite(int hotelId) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.hotels}/favorites',
        data: {'hotel_id': hotelId},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        await _addLocalFavorite(hotelId);
        return ApiResult.success(null);
      }
      await _addLocalFavorite(hotelId);
      return ApiResult.success(null);
    } catch (e) {
      await _addLocalFavorite(hotelId);
      return ApiResult.success(null);
    }
  }

  Future<ApiResult<void>> removeFavorite(int hotelId) async {
    try {
      final response = await _dioClient.delete(
        '${ApiConstants.hotels}/favorites/$hotelId',
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        await _removeLocalFavorite(hotelId);
        return ApiResult.success(null);
      }
      await _removeLocalFavorite(hotelId);
      return ApiResult.success(null);
    } catch (e) {
      await _removeLocalFavorite(hotelId);
      return ApiResult.success(null);
    }
  }

  Future<bool> isFavorite(int hotelId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorite_hotel_ids') ?? '[]';
    final List<dynamic> ids = jsonDecode(raw);
    return ids.contains(hotelId);
  }

  Future<void> _addLocalFavorite(int hotelId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorite_hotel_ids') ?? '[]';
    final List<dynamic> ids = jsonDecode(raw);
    if (!ids.contains(hotelId)) {
      ids.add(hotelId);
      await prefs.setString('favorite_hotel_ids', jsonEncode(ids));
    }
  }

  Future<void> _removeLocalFavorite(int hotelId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorite_hotel_ids') ?? '[]';
    final List<dynamic> ids = jsonDecode(raw);
    ids.remove(hotelId);
    await prefs.setString('favorite_hotel_ids', jsonEncode(ids));
  }

  Future<ApiResult<List<Hotel>>> _getLocalFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('favorite_hotel_ids') ?? '[]';
      final List<dynamic> ids = jsonDecode(raw);
      if (ids.isEmpty) return ApiResult.success([]);

      final List<Hotel> hotels = [];
      for (final id in ids) {
        try {
          final response = await _dioClient.get('${ApiConstants.hotels}/$id');
          if (response.statusCode == 200 && response.data['code'] == 200) {
            hotels.add(Hotel.fromJson(response.data['data'] as Map<String, dynamic>));
          }
        } catch (_) {}
      }
      return ApiResult.success(hotels);
    } catch (e) {
      return ApiResult.success([]);
    }
  }
}

final favoriteServiceProvider = Provider<FavoriteService>((ref) => FavoriteService());

final favoritesProvider = FutureProvider<List<Hotel>>((ref) async {
  final service = ref.read(favoriteServiceProvider);
  final result = await service.getFavorites();
  return result.data ?? [];
});
