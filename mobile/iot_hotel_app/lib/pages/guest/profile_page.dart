import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/logic/member_logic.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/auth_service.dart';
import '../../services/member_service.dart';
import '../../services/favorite_service.dart';

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
    final authState = ref.watch(authStateProvider);
    
    if (!authState.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildGuestProfile(context),
      );
    }

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
              _buildMemberCard(context, ref),
              _buildAssetStats(context, ref),
              _buildOrderSection(context),
              _buildFavoritesRow(context, ref),
              _buildToolSection(context, ref),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestProfile(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 250,
          floating: false,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary, Color(0xFF30CFD0)],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '游客模式',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '登录后可享受完整服务',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton(
                              onPressed: () => context.push('/login'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('立即登录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () => context.push('/register'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('注册账号', style: TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildGuestInfoCard(),
              const SizedBox(height: 16),
              _buildGuestFeatures(),
              const SizedBox(height: 16),
              _buildGuestTools(context),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('游客权益', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildGuestFeatureItem(Icons.visibility_outlined, '浏览酒店信息', '查看所有酒店详情、房型和价格'),
          _buildGuestFeatureItem(Icons.search_outlined, '搜索酒店', '根据条件筛选心仪酒店'),
          _buildGuestFeatureItem(Icons.reviews_outlined, '查看评价', '浏览其他用户的评价和反馈'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '登录后即可享受预订、会员权益、订单管理等完整服务',
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestFeatures() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('会员特权', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPrivilegeItem(Icons.discount_outlined, '订房折扣')),
              Expanded(child: _buildPrivilegeItem(Icons.stars_outlined, '积分抵扣')),
              Expanded(child: _buildPrivilegeItem(Icons.card_membership_outlined, '会员等级')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegeItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildGuestTools(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('快捷入口', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildGuestToolItem(Icons.hotel_outlined, '酒店列表', onTap: () => context.push('/hotel-list'))),
              Expanded(child: _buildGuestToolItem(Icons.search_outlined, '搜索酒店', onTap: () => context.push('/hotel-list'))),
              Expanded(child: _buildGuestToolItem(Icons.reviews_outlined, '查看评价', onTap: () {})),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuestToolItem(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
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
                final user = snapshot.data;
                final displayName = user?.username ?? '未登录';
                return GestureDetector(
                  onTap: () => context.push('/personal-info'),
                  child: Row(
                    children: [
                      Flexible(child: Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildModeSwitchButton(context, ref),
          const SizedBox(width: 12),
          _buildHeaderIcon(Icons.settings_outlined, '设置', onTap: () => _showLogoutConfirmation(context, ref)),
          const SizedBox(width: 12),
          _buildHeaderIcon(Icons.headset_mic_outlined, '客服'),
        ],
      ),
    );
  }

  Widget _buildModeSwitchButton(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentMode = authState.currentMode;

    String modeLabel;
    switch (currentMode) {
      case AppMode.guest:
        modeLabel = '游客';
        break;
      case AppMode.customer:
        modeLabel = '顾客';
        break;
      case AppMode.reception:
        modeLabel = '前台';
        break;
      case AppMode.manager:
        modeLabel = '管理';
        break;
      case AppMode.system:
        modeLabel = '系统';
        break;
    }

    return InkResponse(
      onTap: () => _showModeSwitchDialog(context, ref),
      radius: 30,
      highlightColor: AppColors.primary.withValues(alpha: 0.1),
      splashColor: AppColors.primary.withValues(alpha: 0.2),
      child: Column(
        children: [
          Icon(Icons.swap_horiz, size: 24, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(modeLabel, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showModeSwitchDialog(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authStateProvider);
    final modes = [
      if (authState.canSwitchTo(AppMode.guest)) AppMode.guest,
      if (authState.canSwitchTo(AppMode.customer)) AppMode.customer,
      if (authState.canSwitchTo(AppMode.reception)) AppMode.reception,
      if (authState.canSwitchTo(AppMode.manager)) AppMode.manager,
      if (authState.canSwitchTo(AppMode.system)) AppMode.system,
    ];

    final modeLabels = {
      AppMode.guest: {'label': '游客模式', 'desc': '浏览酒店和房型信息', 'icon': Icons.visibility_outlined},
      AppMode.customer: {'label': '顾客端', 'desc': '预订、入住、客房服务', 'icon': Icons.person_outline},
      AppMode.reception: {'label': '前台端', 'desc': '前台接待、客房管理', 'icon': Icons.desktop_windows_outlined},
      AppMode.manager: {'label': '管理端', 'desc': '酒店管理、数据报表', 'icon': Icons.admin_panel_settings_outlined},
      AppMode.system: {'label': '系统管理', 'desc': '系统管理、酒店审核', 'icon': Icons.security_outlined},
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('切换模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: modes.map((mode) {
            final info = modeLabels[mode]!;
            final isCurrent = authState.currentMode == mode;
            return ListTile(
              leading: Icon(info['icon'] as IconData, color: isCurrent ? AppColors.primary : AppColors.textSecondary),
              title: Text(info['label'] as String, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? AppColors.primary : AppColors.textPrimary)),
              subtitle: Text(info['desc'] as String, style: const TextStyle(fontSize: 12)),
              trailing: isCurrent ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              onTap: () {
                ref.read(authStateProvider.notifier).switchMode(mode);
                Navigator.pop(ctx);
                _navigateToCurrentMode(context, mode);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _navigateToCurrentMode(BuildContext context, AppMode mode) {
    switch (mode) {
      case AppMode.guest:
      case AppMode.customer:
        context.go('/');
        break;
      case AppMode.reception:
        context.go('/reception');
        break;
      case AppMode.manager:
        context.go('/admin');
        break;
      case AppMode.system:
        context.go('/system');
        break;
    }
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

  Widget _buildMemberCard(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(myAssetsProvider);

    return assetsAsync.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (err, stack) => const SizedBox.shrink(),
      data: (apiResult) {
        if (!apiResult.success) return const SizedBox.shrink();
        final member = apiResult.data;
        if (member == null) return const SizedBox.shrink();
        final int currentExp = member.experience.floor();
        
        final level = MemberLevel.fromKey(member.memberLevel);
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

  Widget _buildAssetStats(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(myAssetsProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: assetsAsync.when(
        loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
        error: (err, stack) => const SizedBox.shrink(),
        data: (apiResult) {
          final member = apiResult.data;
          final points = member?.points ?? 0;
          final coupons = member?.couponCount ?? 0;
          final balance = member?.balance ?? 0.0;
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAssetItem(coupons.toString(), '优惠券', onTap: () => context.push('/coupons')),
              _buildAssetItem(points.toString(), '积分', onTap: () {}),
              _buildAssetItem('¥$balance', '余额', onTap: () => context.push('/wallet')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAssetItem(String value, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
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
              _buildOrderItem(Icons.account_balance_wallet_outlined, '待支付', onTap: () => context.push('/orders?tab=1')),
              _buildOrderItem(Icons.hotel_outlined, '待入住', onTap: () => context.push('/orders?tab=2')),
              _buildOrderItem(Icons.rate_review_outlined, '待评价', onTap: () => context.push('/orders?tab=4')),
              _buildOrderItem(Icons.receipt_long_outlined, '待开票', onTap: () => context.push('/orders?tab=3')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(IconData icon, String label, {VoidCallback? onTap}) {
    return InkResponse(
      onTap: onTap,
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

  Widget _buildFavoritesRow(BuildContext context, WidgetRef ref) {
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
                    future: _getFavoritesCount(ref),
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
              onTap: () => context.push('/my-reviews'),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_outlined, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text('最近浏览 >', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getFavoritesCount(WidgetRef ref) async {
    try {
      final result = await ref.read(favoriteServiceProvider).getFavorites();
      return result.data?.length ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildToolSection(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('常用工具', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            children: [
              _buildToolItem(Icons.person_outline_rounded, '账号管理', onTap: () => context.push('/personal-info')),
              _buildToolItem(Icons.people_outline_rounded, '常旅客', onTap: () => context.push('/frequent-guests')),
              _buildToolItem(Icons.receipt_long_outlined, '我的订单', onTap: () => context.push('/orders')),
              _buildToolItem(Icons.history_outlined, '最近浏览', onTap: () => context.push('/recent-browsing')),
              _buildToolItem(Icons.qr_code_scanner_rounded, '扫一扫', onTap: () => context.push('/qr-scanner')),
              _buildToolItem(Icons.headset_mic_outlined, '在线客服', onTap: () => context.push('/ai-butler')),
              _buildToolItem(Icons.notifications_outlined, '消息中心', onTap: () => context.push('/notifications')),
              _buildToolItem(Icons.card_travel_outlined, '自助退房', onTap: () => context.push('/orders')),
              _buildToolItem(Icons.update_outlined, '在线续住', onTap: () => context.push('/orders')),
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
