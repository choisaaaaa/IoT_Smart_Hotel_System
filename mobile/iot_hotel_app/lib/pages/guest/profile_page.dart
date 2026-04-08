import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';
import '../../core/logic/member_logic.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          // 刷新数据
          ref.invalidate(memberServiceProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context, ref),
              _buildMemberCard(ref),
              _buildAssetStats(ref),
              _buildPointsBanner(),
              _buildOrderSection(context),
              _buildFavoritesRow(),
              _buildToolsGrid(),
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
      color: Colors.white,
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
                final user = snapshot.data;
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
    return InkWell(
      onTap: onTap,
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
        final assets = snapshot.data?.data;
        // 使用 total_spent 作为经验值，如果没有则默认为 0
        final double totalSpent = double.tryParse(assets?['total_spent']?.toString() ?? '0') ?? 0;
        final int currentExp = totalSpent.floor();
        
        // 根据后端返回的 member_level 字符串映射等级，或者根据经验值重新计算
        final level = MemberLevel.fromExperience(currentExp);
        final nextExp = level.nextLevelExperience();
        final progress = (currentExp / nextExp).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [level.color.withValues(alpha: 0.8), level.color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: level.color.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('会员中心', style: TextStyle(color: Colors.white, fontSize: 12)),
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
        );
      }
    );
  }

  Widget _buildBenefitItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFFD84315)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFFD84315))),
      ],
    );
  }

  Widget _buildAssetStats(WidgetRef ref) {
    final memberService = ref.watch(memberServiceProvider);
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: FutureBuilder(
        future: memberService.getMyAssets(),
        builder: (context, snapshot) {
          final assets = snapshot.data?.data;
          final points = assets?['points'] ?? '3522';
          final coupons = assets?['coupons_count'] ?? '12';
          
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
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildPointsBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF4FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('1902积分新到账，可抵19元', style: TextStyle(color: AppColors.primary, fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('去使用', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('酒店订单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => context.push('/orders'),
                child: const Row(
                  children: [
                    Text('全部', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                  ],
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
    return Column(
      children: [
        Icon(icon, size: 28, color: AppColors.textPrimary),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildFavoritesRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                const Text('我收藏的 0 >', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(width: 1, height: 16, color: AppColors.divider),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                const Text('我看过的 19 >', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('常用工具', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 20,
            children: [
              _buildToolItem(Icons.verified_user_outlined, '质检合规'),
              _buildToolItem(Icons.account_balance_wallet_outlined, '我的储值卡'),
              _buildToolItem(Icons.storefront_outlined, '华住商城'),
              _buildToolItem(Icons.school_outlined, '学生认证'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
