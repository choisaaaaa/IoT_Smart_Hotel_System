import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logic/member_logic.dart';
import '../../services/auth_service.dart';
import '../../services/member_service.dart';
import '../../core/network/api_result.dart';
import '../../models/user.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: AppColors.surface.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('退出登录'),
          content: const Text('确定要退出当前账号吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(authServiceProvider).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              child: const Text('确定', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(memberServiceProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context, ref),
              _buildMemberCard(ref),
              _buildAssetStats(ref),
              _buildOrderSection(context),
              _buildFavoritesRow(context),
              _buildToolSection(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      color: Colors.transparent,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE1BEE7),
            child: Icon(Icons.person, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder(
              future: authService.getCurrentUser(),
              builder: (context, snapshot) {
                final user = snapshot.data as User?;
                final displayName = user?.username ?? '未登录';
                return Text('$displayName >', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
              },
            ),
          ),
          _buildHeaderIcon(Icons.grid_view_rounded, '会员码'),
          const SizedBox(width: 20),
          _buildHeaderIcon(Icons.settings_outlined, '设置', onTap: () => _showLogoutConfirmation(context, ref)),
          const SizedBox(width: 20),
          _buildHeaderIcon(Icons.headset_mic_outlined, '客服'),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, String label, {VoidCallback? onTap}) {
    return InkResponse(
      onTap: onTap,
      radius: 30,
      highlightColor: AppColors.primary.withValues(alpha: 0.1),
      splashColor: AppColors.primary.withValues(alpha: 0.2),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.textPrimary),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(WidgetRef ref) {
    final memberService = ref.watch(memberServiceProvider);

    return FutureBuilder(
      future: memberService.getMyAssets(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
        final apiResult = snapshot.data as ApiResult<Map<String, dynamic>>;
        if (!apiResult.success) return const SizedBox.shrink();
        final result = apiResult.data ?? {};
        final assets = result;
        final double totalSpent = double.tryParse(assets['total_spent']?.toString() ?? '0') ?? 0;
        final int currentExp = totalSpent.floor();
        
        final level = MemberLevel.fromExperience(currentExp);
        final nextExp = level.nextLevelExperience();
        final progress = (currentExp / nextExp).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // 毛玻璃背景效果
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [level.color.withValues(alpha: 0.7), level.color.withValues(alpha: 0.9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(level.label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('成长值 $currentExp/$nextExp', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                            InkWell(
                              onTap: () => context.push('/member'),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('会员中心', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text('享受 ${level.discount < 1.0 ? (level.discount * 10).toStringAsFixed(1) : '全'} 折优惠 & ${level.pointsMultiplier} 倍积分', 
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildAssetStats(WidgetRef ref) {
    final memberService = ref.watch(memberServiceProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: FutureBuilder(
        future: memberService.getMyAssets(),
        builder: (context, snapshot) {
          final assets = (snapshot.data as ApiResult<Map<String, dynamic>>?)?.data ?? {};
          final points = assets['points'] ?? '0';
          final coupons = assets['coupons_count'] ?? '0';
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAssetItem(coupons.toString(), '优惠券'),
              _buildAssetItem(points.toString(), '积分'),
              _buildAssetItem('0.00', '余额'),
              _buildAssetItem('5', '礼品卡'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAssetItem(String value, String label) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('酒店订单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () => context.push('/orders'),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Text('全部', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOrderItem(Icons.account_balance_wallet_outlined, '待支付'),
              _buildOrderItem(Icons.hotel_outlined, '待入住'),
              _buildOrderItem(Icons.rate_review_outlined, '待评价'),
              _buildOrderItem(Icons.receipt_long_outlined, '待开票'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(IconData icon, String label) {
    return InkResponse(
      onTap: () {},
      radius: 35,
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textPrimary),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFavoritesRow(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/favorites'),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_border_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  FutureBuilder<int>(
                    future: _getFavoritesCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text('我收藏的 $count >', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 16, color: AppColors.divider),
          Expanded(
            child: InkWell(
              onTap: () {},
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('我看过的 19 >', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getFavoritesCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.favoriteHotelsKey) ?? '[]';
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.length;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildToolSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('常用工具', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            children: [
              _buildToolItem(Icons.confirmation_num_outlined, '优惠券', onTap: () => context.push('/coupons')),
              _buildToolItem(Icons.people_outline, '常旅客', onTap: () => context.push('/frequent-guests')),
              _buildToolItem(Icons.notifications_outlined, '消息中心', onTap: () => context.push('/notifications')),
              _buildToolItem(Icons.logout_outlined, '自助退房', onTap: () => context.push('/orders')),
              _buildToolItem(Icons.more_time_outlined, '在线续住', onTap: () => context.push('/orders')),
              _buildToolItem(Icons.rate_review_outlined, '我的评价', onTap: () => context.push('/orders')),
              _buildToolItem(Icons.receipt_long_outlined, '发票管理', onTap: () {}),
              _buildToolItem(Icons.help_outline, '帮助中心', onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
