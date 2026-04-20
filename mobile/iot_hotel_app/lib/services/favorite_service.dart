import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';
import '../models/hotel.dart';

class FavoriteService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<Hotel>>> getFavorites() async {
    try {
      final response = await _dioClient.get(ApiConstants.favorites);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final rawList = response.data['data'] as List<dynamic>? ?? [];
        final hotels = rawList
            .map((h) => Hotel.fromJson(h as Map<String, dynamic>))
            .toList();
        return ApiResult.success(hotels);
      }
      return ApiResult.failure(response.data['message'] ?? '获取收藏列表失败');
    } catch (e) {
      debugPrint('getFavorites error: $e');
      return ApiResult.failure('获取收藏列表失败');
    }
  }

  Future<ApiResult<void>> addFavorite(int hotelId) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.favorites,
        data: {'hotel_id': hotelId},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '收藏失败');
    } catch (e) {
      debugPrint('addFavorite error: $e');
      return ApiResult.failure('收藏失败');
    }
  }

  Future<ApiResult<void>> removeFavorite(int hotelId) async {
    try {
      final response = await _dioClient.delete('${ApiConstants.favorites}/$hotelId');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '取消收藏失败');
    } catch (e) {
      debugPrint('removeFavorite error: $e');
      return ApiResult.failure('取消收藏失败');
    }
  }

  Future<bool> isFavorite(int hotelId) async {
    try {
      final response = await _dioClient.get('${ApiConstants.favorites}/check/$hotelId');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return response.data['data']['is_favorite'] == true ||
            response.data['data']['is_favorite'] == 1;
      }
      return false;
    } catch (e) {
      debugPrint('isFavorite error: $e');
      return false;
    }
  }
}

final favoriteServiceProvider = Provider<FavoriteService>((ref) => FavoriteService());

final favoritesProvider = FutureProvider<List<Hotel>>((ref) async {
  final service = ref.read(favoriteServiceProvider);
  final result = await service.getFavorites();
  return result.data ?? [];
});
