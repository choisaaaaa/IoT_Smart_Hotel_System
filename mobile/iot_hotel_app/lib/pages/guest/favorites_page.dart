import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/auth/auth_state_notifier.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  String get _favKey {
    final userId = ref.read(authStateProvider).userId ?? 'guest';
    return '${AppConstants.favoriteHotelsKey}_$userId';
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_favKey) ?? '[]';
      final List<dynamic> decoded = jsonDecode(raw);
      setState(() => _favorites = decoded.cast<Map<String, dynamic>>().toList());
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(int index) async {
    final removed = _favorites[index];
    setState(() => _favorites.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favKey, jsonEncode(_favorites));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已取消收藏'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              setState(() => _favorites.insert(index, removed));
              await prefs.setString(_favKey, jsonEncode(_favorites));
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('我收藏的', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: AppColors.textHint.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('暂无收藏', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('浏览酒店时点击爱心即可收藏', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final fav = _favorites[index];
                      final imageUrl = fav['image'] is String && (fav['image'] as String).isNotEmpty
                          ? fav['image']
                          : 'https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=400&q=80';
                      return Dismissible(
                        key: ValueKey(fav['id']),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeFavorite(index),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppColors.error,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: GestureDetector(
                          onTap: () => context.push('/hotel-detail', extra: {'hotelId': fav['id']}),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                  child: Image.network(
                                    imageUrl,
                                    width: 100,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 100,
                                      height: 80,
                                      color: AppColors.divider,
                                      child: const Icon(Icons.hotel, color: AppColors.textHint),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fav['name'] ?? '智联酒店',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${fav['star'] ?? 5}星级',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      if (fav['location'] != null && fav['location'].toString().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          fav['location'].toString(),
                                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.favorite, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
