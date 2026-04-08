import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, ref),
            _buildSearchCard(context),
            _buildQuickActions(),
            _buildBanner(),
            _buildMemberPrivilege(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    
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
                  future: authService.getCurrentUser(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final displayName = user?.username ?? '游客';
                    final roleName = user?.role == 'admin' ? '系统管理员' : user?.role == 'staff' ? '金会员' : '普通会员';
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('早上好,', style: GoogleFonts.notoSansSc(color: Colors.white, fontSize: 16)),
                        Text('$roleName $displayName 先生', style: GoogleFonts.notoSansSc(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                Text('国内/国际', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                SizedBox(width: 24),
                Text('时租房', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                SizedBox(width: 24),
                Text('公寓', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
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
            const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('今天入住', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text('4月8日', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text('1晚', style: TextStyle(color: AppColors.textHint)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('明天离店', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text('4月9日', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionItem(Icons.calendar_today_outlined, '会员签到'),
          _buildActionItem(Icons.business_outlined, '企业预订'),
          _buildActionItem(Icons.shopping_cart_outlined, '华住商城'),
          _buildActionItem(Icons.bookmark_outline, '收藏/足迹'),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 28, color: AppColors.textPrimary),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textPrimary)),
      ],
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

  Widget _buildMemberPrivilege() {
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
                  const Text('金会员', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF795548))),
                  const SizedBox(width: 8),
                  Text('您可享受85项特权', style: TextStyle(fontSize: 12, color: Colors.brown.withValues(alpha: 0.7))),
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
