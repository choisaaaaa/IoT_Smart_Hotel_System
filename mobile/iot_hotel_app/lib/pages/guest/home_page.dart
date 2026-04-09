import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/member_service.dart';
import '../../core/logic/member_logic.dart';
import '../../models/user.dart';
import '../../core/network/api_result.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(memberServiceProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context, ref),
              _buildSearchCard(context),
              _buildQuickActions(context),
              _buildBanner(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final memberService = ref.watch(memberServiceProvider);
    
    return Container(
      width: double.infinity,
      height: 260,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.white],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FutureBuilder(
                  future: Future.wait([
                    authService.getCurrentUser(),
                    memberService.getMyAssets(),
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final user = snapshot.data?[0] as User?;
                    final assetsResult = snapshot.data?[1] as ApiResult?;
                    final assets = assetsResult?.data ?? {};
                    
                    final displayName = user?.username ?? '游客';
                    final double totalSpent = double.tryParse(assets['total_spent']?.toString() ?? '0') ?? 0;
                    final level = MemberLevel.fromExperience(totalSpent.floor());
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('早上好,', style: GoogleFonts.notoSansSc(color: Colors.white, fontSize: 16)),
                        Text('${level.label} $displayName ${user != null ? '先生/女士' : ''}', style: GoogleFonts.notoSansSc(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                    SizedBox(width: 16),
                    Icon(Icons.notifications_none, color: Colors.white, size: 28),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final format = DateFormat('M月d日');

    return Transform.translate(
      offset: const Offset(0, -40),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Text('酒店预订', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('珠海', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('位置/酒店/关键词', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
                    ],
                  ),
                ),
                Icon(Icons.my_location, color: AppColors.primary.withValues(alpha: 0.6)),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('今天入住', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(format.format(now), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Text('1晚', style: TextStyle(color: AppColors.textHint)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('明天离店', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(format.format(tomorrow), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => context.push('/hotel-list'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                ),
                child: const Text('查询', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionItem(Icons.calendar_today_outlined, '会员签到', onTap: () => context.push('/member')),
          _buildActionItem(Icons.bookmark_outline, '收藏/足迹', onTap: () => context.push('/favorites')),
          _buildActionItem(Icons.headset_mic_outlined, '联系客服', onTap: () {}),
          _buildActionItem(Icons.help_outline, '使用帮助', onTap: () {}),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature功能即将上线，敬请期待'),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _buildActionItem(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textPrimary),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent]),
        ),
        child: const Text('把春天装进眼睛里\n花间赏花季邀您入画', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMemberPrivilege(WidgetRef ref) {
    final memberService = ref.watch(memberServiceProvider);

    return FutureBuilder(
      future: memberService.getMyAssets(),
      builder: (context, snapshot) {
        final assets = (snapshot.data as ApiResult?)?.data ?? {};
        final double totalSpent = double.tryParse(assets['total_spent']?.toString() ?? '0') ?? 0;
        final level = MemberLevel.fromExperience(totalSpent.floor());

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.gold),
                        child: const Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Text(level.label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF795548))),
                      const SizedBox(width: 8),
                      Text('您可享受${level.index * 20 + 5}项特权', style: TextStyle(fontSize: 12, color: Colors.brown.withValues(alpha: 0.7))),
                    ],
                  ),
                  const Text('更多玩法 >', style: TextStyle(fontSize: 12, color: Colors.brown)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildPrivilegeItem('月月领券', '每月1号见'),
                  _buildPrivilegeItem('积分游乐园', '抽10000积分'),
                  _buildPrivilegeItem('超值特权卡', '积分间夜限时加倍'),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildPrivilegeItem(String title, String sub) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown)),
          Text(sub, style: const TextStyle(fontSize: 10, color: Colors.brown)),
        ],
      ),
    );
  }
}
