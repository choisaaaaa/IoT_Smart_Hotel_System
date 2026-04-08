import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';

class ReceptionDashboardPage extends ConsumerStatefulWidget {
  const ReceptionDashboardPage({super.key});

  @override
  ConsumerState<ReceptionDashboardPage> createState() => _ReceptionDashboardPageState();
}

class _ReceptionDashboardPageState extends ConsumerState<ReceptionDashboardPage> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: '总览'),
    _NavItem(icon: Icons.how_to_reg_rounded, label: '入住退房'),
    _NavItem(icon: Icons.calendar_month_rounded, label: '预订'),
    _NavItem(icon: Icons.door_back_door_rounded, label: '客房'),
    _NavItem(icon: Icons.build_rounded, label: '工单'),
    _NavItem(icon: Icons.delivery_dining_rounded, label: '送物'),
    _NavItem(icon: Icons.receipt_long_rounded, label: '账单'),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _ReceptionHomeContent(),
      const CheckInOutPage(),
      const BookingsPage(),
      const RoomAvailabilityPage(),
      const WorkOrdersPage(),
      const DeliveryOrdersPage(),
      const BillsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('智联酒店 - 前台端', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_rounded), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 18, color: Colors.white)),
            onSelected: (value) async { 
              if (value == 'logout') {
                await ref.read(authServiceProvider).logout();
                if (mounted) context.go('/login');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('个人信息')),
              const PopupMenuItem(value: 'logout', child: Text('退出登录')),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 10),
          items: _navItems.map((item) => BottomNavigationBarItem(icon: Icon(item.icon), label: item.label)).toList(),
        ),
      ),
    );
  }
}

class _ReceptionHomeContent extends StatelessWidget {
  const _ReceptionHomeContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日概况', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _QuickStatCard(title: '今日入住', value: '12', icon: Icons.login_rounded, color: AppColors.success),
              _QuickStatCard(title: '今日退房', value: '8', icon: Icons.logout_rounded, color: AppColors.error),
              _QuickStatCard(title: '在住客人', value: '86', icon: Icons.people_rounded, color: AppColors.info),
              _QuickStatCard(title: '待处理事项', value: '5', icon: Icons.pending_actions_rounded, color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 24),
          _buildTaskCard(context),
          const SizedBox(height: 24),
          _buildArrivalCard(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('待处理工单', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('3个加急', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 16),
          _WorkOrderItem(room: '305房', type: '维修', desc: '空调不制冷', time: '10分钟前', urgent: true),
          const Divider(height: 1),
          _WorkOrderItem(room: '102房', type: '清洁', desc: '退房清洁', time: '30分钟前', urgent: false),
          const Divider(height: 1),
          _WorkOrderItem(room: '201房', type: '送物', desc: '毛巾+矿泉水', time: '1小时前', urgent: false),
        ],
      ),
    );
  }

  Widget _buildArrivalCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('今日预订到店', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          ...['张三 · 101房 · 14:00', '李四 · 203房 · 15:00', '王五 · 302房 · 18:00'].map(
            (b) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(radius: 14, backgroundColor: AppColors.background, child: Icon(Icons.person_outline, size: 16)),
              title: Text(b, style: GoogleFonts.notoSansSc(fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _QuickStatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.1))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(title, style: GoogleFonts.notoSansSc(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkOrderItem extends StatelessWidget {
  final String room, type, desc, time;
  final bool urgent;
  const _WorkOrderItem({required this.room, required this.type, required this.desc, required this.time, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$room · $type', style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (urgent) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(4)), child: const Text('加急', style: TextStyle(color: Colors.white, fontSize: 8)))]
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(time, style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _NavItem { final IconData icon; final String label; const _NavItem({required this.icon, required this.label}); }

class CheckInOutPage extends StatelessWidget { const CheckInOutPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('入住退房')), body: Center(child: Text('入住退房功能开发中...', style: TextStyle(color: AppColors.textSecondary)))); }
class BookingsPage extends StatelessWidget { const BookingsPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('预订管理')), body: Center(child: Text('预订管理功能开发中...', style: TextStyle(color: AppColors.textSecondary)))); }
class RoomAvailabilityPage extends StatelessWidget { const RoomAvailabilityPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('客房余量')), body: Center(child: Text('客房余量功能开发中...', style: TextStyle(color: AppColors.textSecondary)))); }
class WorkOrdersPage extends StatelessWidget { const WorkOrdersPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('工单处理')), body: Center(child: Text('工单处理功能开发中...', style: TextStyle(color: AppColors.textSecondary)))); }
class DeliveryOrdersPage extends StatelessWidget { const DeliveryOrdersPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('客房送物')), body: Center(child: Text('送物订单功能开发中...', style: TextStyle(color: AppColors.textSecondary)))); }
class BillsPage extends StatelessWidget { const BillsPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('账单报表')), body: Center(child: Text('账单报表功能开发中...', style: TextStyle(color: AppColors.textSecondary)))); }
