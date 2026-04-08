import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _showLogoutConfirmation(BuildContext context) {
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
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/login');
            },
            child: const Text('确定', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildMemberCard(),
            _buildAssetStats(),
            _buildPointsBanner(),
            _buildOrderSection(context),
            _buildFavoritesRow(),
            _buildToolsGrid(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          const Expanded(
            child: Text('谭** >', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          _buildHeaderIcon(Icons.grid_view_rounded, '会员码'),
          const SizedBox(width: 20),
          _buildHeaderIcon(Icons.settings_outlined, '设置', onTap: () => _showLogoutConfirmation(context)),
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

  Widget _buildMemberCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBE9E7), Color(0xFFFFF3E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('金会员', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF795548))),
                  SizedBox(width: 8),
                  Text('3/40', style: TextStyle(fontSize: 12, color: Color(0xFFBCAAA4))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF795548),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('会员中心', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBenefitItem(Icons.percent, '房费8.8折'),
              _buildBenefitItem(Icons.restaurant, '1份免费早餐'),
              _buildBenefitItem(Icons.access_time, '延迟退房至14:00'),
            ],
          ),
        ],
      ),
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

  Widget _buildAssetStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('2', '张', '优惠券'),
          _buildStatItem('3,522', '', '积分', showBadge: true),
          _buildStatItem('1', '张', '卡包'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String unit, String label, {bool showBadge = false}) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (unit.isNotEmpty) Text(unit, style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (showBadge)
              Positioned(
                top: -10,
                right: -30,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('可抵35元', style: TextStyle(color: Colors.white, fontSize: 8)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildPointsBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.purple, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('1902积分新到账，可抵19元', style: TextStyle(fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text('去使用', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('酒店订单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  _buildSubTab('商城订单'),
                  _buildDivider(),
                  _buildSubTab('服务订单'),
                  _buildDivider(),
                  _buildSubTab('全部', active: true, onTap: () => context.push('/orders')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOrderIcon(Icons.payment_outlined, '待支付'),
              _buildOrderIcon(Icons.hotel_outlined, '待入住'),
              _buildOrderIcon(Icons.chat_bubble_outline, '待评价'),
              _buildOrderIcon(Icons.receipt_long_outlined, '待开票'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(String label, {bool active = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: active ? AppColors.textPrimary : AppColors.textHint,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 10,
      width: 1,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildOrderIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 28, color: AppColors.textPrimary),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildFavoritesRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Row(
              children: [
                Icon(Icons.star_border, size: 18),
                SizedBox(width: 4),
                Text('我收藏的 0 >', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Container(width: 1, height: 20, color: AppColors.divider),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 18),
                SizedBox(width: 4),
                Text('我看过的 19 >', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsGrid() {
    final tools = [
      {'icon': Icons.verified_user_outlined, 'label': '贵即赔'},
      {'icon': Icons.account_balance_wallet_outlined, 'label': '我的储值'},
      {'icon': Icons.shopping_bag_outlined, 'label': '华住商城'},
      {'icon': Icons.school_outlined, 'label': '学生认证'},
      {'icon': Icons.favorite_outline, 'label': '华住会公益'},
      {'icon': Icons.business_center_outlined, 'label': '华住商旅'},
      {'icon': Icons.info_outline, 'label': '了解华住会'},
      {'icon': Icons.language, 'label': '华住世界'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('常用工具', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 20,
              crossAxisSpacing: 10,
            ),
            itemCount: tools.length,
            itemBuilder: (context, index) {
              return Column(
                children: [
                  Icon(tools[index]['icon'] as IconData, size: 28),
                  const SizedBox(height: 8),
                  Text(tools[index]['label'] as String, style: const TextStyle(fontSize: 11)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
