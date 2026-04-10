import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/hotel_service.dart';
import '../../services/room_service.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/auth/auth_state_notifier.dart';
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
    NavigationItem(icon: Icons.fact_check_rounded, label: '审核'),
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
      const _AdminReviewTab(),
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
              } else if (value == 'switch_mode') {
                _showModeSwitchDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'switch_mode', child: Row(children: [Icon(Icons.swap_horiz), SizedBox(width: 8), Text('切换模式')])),
              const PopupMenuItem(value: 'profile', child: Text('个人信息')),
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

  void _showModeSwitchDialog() {
    final authState = ref.read(authStateProvider);
    final modes = <AppMode, String>{
      AppMode.customer: '顾客端',
      AppMode.reception: '前台端',
      AppMode.manager: '管理端',
      AppMode.guest: '游客端',
    };

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('切换模式'),
        children: modes.entries.where((e) => authState.canSwitchTo(e.key)).map((e) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).switchMode(e.key);
              _navigateToMode(e.key);
            },
            child: Row(children: [
              Icon(_modeIcon(e.key), color: AppColors.primary),
              const SizedBox(width: 12),
              Text(e.value, style: const TextStyle(fontSize: 16)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  IconData _modeIcon(AppMode mode) {
    switch (mode) {
      case AppMode.guest: return Icons.visibility_outlined;
      case AppMode.customer: return Icons.person_outline;
      case AppMode.reception: return Icons.support_agent_outlined;
      case AppMode.manager: return Icons.admin_panel_settings_outlined;
      case AppMode.system: return Icons.security_outlined;
    }
  }

  void _navigateToMode(AppMode mode) {
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
}

class NavigationItem {
  final IconData icon;
  final String label;
  const NavigationItem({required this.icon, required this.label});
}

class _DashboardContent extends ConsumerStatefulWidget {
  const _DashboardContent();

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _roomDistribution;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final statsResult = await ref.read(hotelServiceProvider).getDashboardStats();
      final distResult = await ref.read(roomServiceProvider).getRoomStatusDistribution();

      if (mounted) {
        setState(() {
          _stats = statsResult.success ? statsResult.data : null;
          _roomDistribution = distResult.success ? distResult.data : null;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToTab(int tabIndex) {
    final parent = context.findAncestorStateOfType<_AdminDashboardPageState>();
    parent?.setState(() => parent._selectedIndex = tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    final totalRooms = _stats?['total_rooms']?.toString() ?? '0';
    final occupancyRateVal = _stats?['occupancy_rate'];
    final rateDouble = occupancyRateVal != null ? (double.tryParse(occupancyRateVal.toString()) ?? 0) : 0;
    final occupancyRate = '${(rateDouble * 100).toStringAsFixed(0)}%';
    final onlineDevices = _stats?['online_devices']?.toString() ?? '0';
    final todayBookings = _stats?['today_bookings']?.toString() ?? '0';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
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
                _buildStatCard(context, '总房间数', totalRooms, Icons.door_back_door, Colors.blue, onTap: () => _navigateToTab(2)),
                _buildStatCard(context, '入住率', occupancyRate, Icons.trending_up, Colors.green, onTap: () => _navigateToTab(2)),
                _buildStatCard(context, '在线设备', onlineDevices, Icons.devices, Colors.indigo, onTap: () => _navigateToTab(1)),
                _buildStatCard(context, '今日预订', todayBookings, Icons.calendar_today, Colors.orange, onTap: () => _navigateToTab(4)),
              ],
            ),
            const SizedBox(height: 24),
            _buildChartSection(context),
            const SizedBox(height: 24),
            _buildActivitySection(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                if (onTap != null) const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
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
      ),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    final available = _roomDistribution?['available'] ?? 60;
    final occupied = _roomDistribution?['occupied'] ?? 30;
    final cleaning = _roomDistribution?['cleaning'] ?? 10;

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
                  if (available > 0) PieChartSectionData(value: available.toDouble(), color: AppColors.roomAvailable, title: '空闲', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  if (occupied > 0) PieChartSectionData(value: occupied.toDouble(), color: AppColors.roomOccupied, title: '已入', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  if (cleaning > 0) PieChartSectionData(value: cleaning.toDouble(), color: AppColors.roomCleaning, title: '清扫', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
              GestureDetector(onTap: () => _navigateToTab(4), child: Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12))),
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

class _AdminReviewTab extends StatefulWidget {
  const _AdminReviewTab();
  @override
  State<_AdminReviewTab> createState() => _AdminReviewTabState();
}

class _AdminReviewTabState extends State<_AdminReviewTab> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    try {
      final dio = DioClient();
      final res = await dio.get(ApiConstants.authRoleApplications);
      if (res.statusCode == 200 && res.data['code'] == 200) {
        setState(() => _applications = List<Map<String, dynamic>>.from(res.data['data'] ?? []));
      }
    } catch (e) {
      debugPrint('Error loading applications: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewApplication(int id, String status, {String? note}) async {
    try {
      final dio = DioClient();
      final res = await dio.put('${ApiConstants.authRoleApplications}/$id/review', data: {
        'status': status,
        if (note != null) 'review_note': note,
      });
      if (res.statusCode == 200 && res.data['code'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'approved' ? '已通过' : '已拒绝'), backgroundColor: AppColors.success));
          _loadApplications();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作异常：$e')));
    }
  }

  void _showReviewDialog(Map<String, dynamic> app) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('审核申请 #${app['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('申请人: ${app['username'] ?? '-'}'),
            Text('类型: ${app['application_type'] == 'create_hotel' ? '创建酒店' : '绑定员工'}'),
            if (app['target_hotel_name'] != null) Text('酒店: ${app['target_hotel_name']}'),
            if (app['reason'] != null) Text('理由: ${app['reason']}'),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: '审核备注 (可选)'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () { Navigator.pop(ctx); _reviewApplication(app['id'], 'rejected', note: noteCtrl.text.trim()); }, child: const Text('拒绝', style: TextStyle(color: AppColors.error))),
          FilledButton(onPressed: () { Navigator.pop(ctx); _reviewApplication(app['id'], 'approved', note: noteCtrl.text.trim()); }, child: const Text('通过')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final pending = _applications.where((a) => a['status'] == 'pending').toList();
    final reviewed = _applications.where((a) => a['status'] != 'pending').toList();

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: DefaultTabController(
        length: 2,
        child: Column(children: [
          const TabBar(tabs: [Tab(text: '待审核'), Tab(text: '已审核')]),
          Expanded(child: TabBarView(children: [_buildList(pending, true), _buildList(reviewed, false)])),
        ]),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> apps, bool showActions) {
    if (apps.isEmpty) return const Center(child: Text('暂无数据'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      itemBuilder: (ctx, i) {
        final app = apps[i];
        final status = app['status'] ?? 'pending';
        Color sc; String st;
        switch (status) {
          case 'approved': sc = AppColors.success; st = '已通过'; break;
          case 'rejected': sc = AppColors.error; st = '已拒绝'; break;
          default: sc = AppColors.warning; st = '待审核';
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(app['application_type'] == 'create_hotel' ? Icons.add_business : Icons.badge, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(app['application_type'] == 'create_hotel' ? '创建酒店: ${app['hotel_name'] ?? '-'}' : '绑定员工: ${app['target_hotel_name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(st, style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 8),
              Text('申请人: ${app['username'] ?? '-'} | ${app['created_at']?.toString().substring(0, 10) ?? '-'}'),
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [OutlinedButton(onPressed: () => _showReviewDialog(app), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary), child: const Text('审核'))]),
              ],
            ]),
          ),
        );
      },
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
