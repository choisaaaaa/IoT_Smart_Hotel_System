import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/favorite_service.dart';
import '../../models/hotel.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  List<Hotel> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(favoriteServiceProvider).getFavorites();
      if (mounted) {
        setState(() => _favorites = result.data ?? []);
      }
    } catch (e) {
      debugPrint('favorites: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(int index) async {
    final removed = _favorites[index];
    setState(() => _favorites.removeAt(index));

    final result = await ref.read(favoriteServiceProvider).removeFavorite(removed.id);

    if (!result.success && mounted) {
      setState(() => _favorites.insert(index, removed));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取消收藏失败，请重试')),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已取消收藏 ${removed.hotelName}'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              final addResult = await ref.read(favoriteServiceProvider).addFavorite(removed.id);
              if (addResult.success) {
                setState(() => _favorites.insert(index, removed));
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (!authState.isAuthenticated) {
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
          title: const Text('我的收藏', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_outline, size: 80, color: AppColors.textHint.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text('请先登录后查看收藏', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/login'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('立即登录'),
              ),
            ],
          ),
        ),
      );
    }

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
        title: const Text('我的收藏', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_outline, size: 64, color: AppColors.textHint.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('暂无收藏的酒店', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go('/hotel-list'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('去发现酒店'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) => _buildFavoriteCard(_favorites[index], index),
                  ),
                ),
    );
  }

  Widget _buildFavoriteCard(Hotel hotel, int index) {
    return Dismissible(
      key: ValueKey(hotel.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _removeFavorite(index),
      child: GestureDetector(
        onTap: () => context.push('/hotel-detail', extra: {'hotelId': hotel.id}),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                width: 120,
                height: 100,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                      hotel.displayImage.isNotEmpty
                          ? hotel.displayImage
                          : 'https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=400&q=80',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hotel.hotelName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(hotel.effectiveStar, (_) => const Icon(Icons.star, color: AppColors.gold, size: 14)),
                          const SizedBox(width: 4),
                          Text(hotel.effectiveRating.toStringAsFixed(1), style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(hotel.displayAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (hotel.price != null)
                            Row(
                              children: [
                                const Text('¥', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(hotel.price!.toStringAsFixed(0), style: const TextStyle(color: AppColors.secondary, fontSize: 18, fontWeight: FontWeight.bold)),
                                const Text('起', style: TextStyle(color: AppColors.secondary, fontSize: 10)),
                              ],
                            )
                          else
                            const SizedBox.shrink(),
                          IconButton(
                            icon: const Icon(Icons.favorite, color: AppColors.error, size: 20),
                            onPressed: () => _removeFavorite(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
