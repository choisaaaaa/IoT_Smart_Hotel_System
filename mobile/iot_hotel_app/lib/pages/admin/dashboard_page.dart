import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';
import 'device_monitor_page.dart';
import 'room_manage_page.dart';
import 'hotel_edit_page.dart';
import 'reports_page.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedIndex = 0;

  final List<NavigationItem> _navItems = const [
    NavigationItem(icon: Icons.dashboard_rounded, label: '总览'),
    NavigationItem(icon: Icons.devices_rounded, label: '设备'),
    NavigationItem(icon: Icons.door_back_door_rounded, label: '房间'),
    NavigationItem(icon: Icons.hotel_rounded, label: '酒店'),
    NavigationItem(icon: Icons.assessment_rounded, label: '报表'),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _DashboardContent(),
      const DeviceMonitorPage(),
      const RoomManagePage(),
      const HotelEditPage(),
      const ReportsPage(),
    ];
  }

  void _onNavTap(int index) { setState(() => _selectedIndex = index); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('智联酒店 - 管理端', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_rounded), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 18, color: Colors.white)),
            onSelected: (value) async { 
              if (value == 'logout') {
                await ref.read(authServiceProvider).logout();
                if (!context.mounted) return;
                context.go('/login');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('个人信息')),
              const PopupMenuItem(value: 'settings', child: Text('系统设置')),
              const PopupMenuItem(value: 'logout', child: Text('退出登录')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 12),
          items: _navItems.map((item) => BottomNavigationBarItem(icon: Icon(item.icon), label: item.label, activeIcon: Icon(item.icon, color: AppColors.primary))).toList(),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  const NavigationItem({required this.icon, required this.label});
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('数据概览', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(context, '总房间数', '120', Icons.door_back_door, Colors.blue),
              _buildStatCard(context, '入住率', '78%', Icons.trending_up, Colors.green),
              _buildStatCard(context, '在线设备', '45', Icons.devices, Colors.indigo),
              _buildStatCard(context, '今日预订', '18', Icons.calendar_today, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          _buildChartSection(context),
          const SizedBox(height: 24),
          _buildActivitySection(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: color)),
              const Icon(Icons.more_horiz, size: 16, color: AppColors.textHint),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.notoSansSc(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(title, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('房间状态分布', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.pie_chart_outline, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(value: 60, color: AppColors.roomAvailable, title: '空闲', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  PieChartSectionData(value: 30, color: AppColors.roomOccupied, title: '已入', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  PieChartSectionData(value: 10, color: AppColors.roomCleaning, title: '清扫', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(AppColors.roomAvailable, '空闲'),
              const SizedBox(width: 16),
              _buildLegend(AppColors.roomOccupied, '已入住'),
              const SizedBox(width: 16),
              _buildLegend(AppColors.roomCleaning, '清扫中'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]);
  }

  Widget _buildActivitySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('最近活动', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          _ActivityItem(title: '101房 灯光已开启', time: '2分钟前', icon: Icons.lightbulb_outline, color: Colors.green),
          _ActivityItem(title: '202房 温度异常告警', time: '15分钟前', icon: Icons.warning_amber_rounded, color: Colors.red),
          _ActivityItem(title: '305房 客人已退房', time: '1小时前', icon: Icons.logout_rounded, color: Colors.blue),
          _ActivityItem(title: '新预订：401房', time: '2小时前', icon: Icons.add_business_rounded, color: Colors.orange),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title, time;
  final IconData icon;
  final Color color;
  const _ActivityItem({required this.title, required this.time, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
        ],
      ),
    );
  }
}
