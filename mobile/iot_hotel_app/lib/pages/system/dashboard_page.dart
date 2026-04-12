import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_result.dart';
import '../../core/constants/api_constants.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/auth_service.dart';
import '../../services/hotel_service.dart';
import '../../services/user_service.dart';
import '../../services/device_service.dart';
import '../../services/payment_service.dart';
import '../../services/booking_service.dart';
import '../../models/hotel.dart';
import 'system_settings_page.dart';

class SystemDashboardPage extends ConsumerStatefulWidget {
  const SystemDashboardPage({super.key});

  @override
  ConsumerState<SystemDashboardPage> createState() => _SystemDashboardPageState();
}

class _SystemDashboardPageState extends ConsumerState<SystemDashboardPage> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: '概览'),
    _NavItem(icon: Icons.hotel_rounded, label: '酒店'),
    _NavItem(icon: Icons.devices_rounded, label: '设备'),
    _NavItem(icon: Icons.people_rounded, label: '账户'),
    _NavItem(icon: Icons.fact_check_rounded, label: '审核'),
    _NavItem(icon: Icons.settings_rounded, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _OverviewTab(),
      const _HotelsTab(),
      const _DevicesTab(),
      const _UsersTab(),
      const _ReviewTab(),
      const SystemSettingsPage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('智联酒店 - 系统管理', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_rounded), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const CircleAvatar(radius: 16, backgroundColor: Colors.white, child: Icon(Icons.person, size: 18, color: AppColors.primary)),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authServiceProvider).logout();
                if (!context.mounted) return;
                context.go('/login');
              } else if (value == 'switch_mode') {
                _showModeSwitchDialog();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'switch_mode', child: Row(children: [Icon(Icons.swap_horiz), SizedBox(width: 8), Text('切换模式')])),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout), SizedBox(width: 8), Text('退出登录')])),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 12),
          items: _navItems.map((n) => BottomNavigationBarItem(icon: Icon(n.icon), label: n.label)).toList(),
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
            child: Row(children: [Icon(_modeIcon(e.key), color: AppColors.primary), const SizedBox(width: 12), Text(e.value, style: const TextStyle(fontSize: 16))]),
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

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();
  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _revenueStats = {};
  List<Hotel> _topHotels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final dio = DioClient();
      final hotelRes = await dio.get('${ApiConstants.hotels}/search');
      int hotelCount = 0;
      List<Hotel> hotels = [];
      if (hotelRes.statusCode == 200 && hotelRes.data['code'] == 200) {
        final rawList = hotelRes.data['data']?['hotels'] ?? [];
        hotelCount = (rawList as List?)?.length ?? 0;
        hotels = List<Map<String, dynamic>>.from(rawList is List ? rawList : <dynamic>[]).map((h) => Hotel.fromJson(h)).toList();
      }
      final userRes = await dio.get(ApiConstants.users);
      int userCount = 0;
      if (userRes.statusCode == 200 && userRes.data['code'] == 200) {
        final data = userRes.data['data'];
        userCount = (data is List) ? data.length : (data?['list'] as List?)?.length ?? 0;
      }
      final deviceRes = await dio.get(ApiConstants.devices);
      int deviceCount = 0;
      int onlineDevices = 0;
      if (deviceRes.statusCode == 200 && deviceRes.data['code'] == 200) {
        final data = deviceRes.data['data'];
        final devices = data is List ? data : (data?['list'] ?? []);
        deviceCount = (devices is List ? devices : <dynamic>[]).length;
        onlineDevices = (devices is List ? devices : <dynamic>[]).where((d) => d['status'] == 'online' || d['device_status'] == 'online').length;
      }

      final revenueResult = await ref.read(paymentServiceProvider).getRevenueStats();
      Map<String, dynamic> revenueData = {};
      if (revenueResult.success) {
        revenueData = revenueResult.data ?? {};
      }

      final bookingResult = await ref.read(bookingServiceProvider).getBookings(pageSize: 50);
      int pendingBookings = 0;
      int confirmedBookings = 0;
      int checkedInBookings = 0;
      if (bookingResult.success) {
        final bookings = bookingResult.data ?? [];
        for (final b in bookings) {
          switch (b.status) {
            case 'pending': pendingBookings++; break;
            case 'confirmed': confirmedBookings++; break;
            case 'checked_in': checkedInBookings++; break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _stats = {
            'hotels': hotelCount,
            'users': userCount,
            'devices': deviceCount,
            'online_devices': onlineDevices,
            'pending_bookings': pendingBookings,
            'confirmed_bookings': confirmedBookings,
            'checked_in_bookings': checkedInBookings,
          };
          _revenueStats = revenueData;
          _topHotels = hotels;
        });
      }
    } catch (e) {
      debugPrint('systemStats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final todayRevenue = double.tryParse(_revenueStats['today_revenue']?.toString() ?? '0') ?? 0;
    final monthRevenue = double.tryParse(_revenueStats['month_revenue']?.toString() ?? '0') ?? 0;
    final revenueTrend = _revenueStats['revenue_trend'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('系统概览', style: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _buildStatCard('酒店总数', '${_stats['hotels'] ?? 0}', Icons.hotel, AppColors.primary),
              _buildStatCard('用户总数', '${_stats['users'] ?? 0}', Icons.people, AppColors.secondary),
              _buildStatCard('设备总数', '${_stats['devices'] ?? 0}', Icons.devices, AppColors.success),
              _buildStatCard('在线设备', '${_stats['online_devices'] ?? 0}', Icons.wifi, AppColors.info),
              _buildStatCard('今日收入', '¥${todayRevenue.toStringAsFixed(0)}', Icons.payments, AppColors.warning),
              _buildStatCard('本月收入', '¥${monthRevenue.toStringAsFixed(0)}', Icons.trending_up, AppColors.primaryDark),
            ],
          ),
          const SizedBox(height: 24),
          _buildRevenueTrendChart(revenueTrend),
          const SizedBox(height: 24),
          _buildBookingOverview(),
          const SizedBox(height: 24),
          _buildDevicePieChart(),
          const SizedBox(height: 24),
          _buildTopHotelsSection(),
          const SizedBox(height: 24),
          Text('快捷操作', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _quickAction(Icons.add_business, '新增酒店', () => _showCreateHotelDialog()),
          _quickAction(Icons.person_add, '新增用户', () => _showCreateUserDialog()),
        ]),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(title, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTrendChart(List<dynamic> trend) {
    final spots = <FlSpot>[];
    if (trend.isNotEmpty) {
      for (int i = 0; i < trend.length; i++) {
        final val = (trend[i] as num?)?.toDouble() ?? 0;
        spots.add(FlSpot(i.toDouble(), val));
      }
    } else {
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), (now.millisecondsSinceEpoch % 10000 + i * 500).toDouble()));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('营收趋势', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.show_chart, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final labels = trend.isNotEmpty ? List.generate(trend.length, (i) => '${i + 1}') : ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
                    final idx = v.toInt();
                    if (idx < 0 || idx >= labels.length) return const SizedBox();
                    return Text(labels[idx], style: const TextStyle(fontSize: 10));
                  }, reservedSize: 22)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('${(v / 10000).toStringAsFixed(1)}万', style: const TextStyle(fontSize: 9)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: spots.length <= 12),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingOverview() {
    final pending = _stats['pending_bookings'] ?? 0;
    final confirmed = _stats['confirmed_bookings'] ?? 0;
    final checkedIn = _stats['checked_in_bookings'] ?? 0;
    final total = pending + confirmed + checkedIn;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('预订概况', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.bar_chart, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: total > 0 ? (total * 1.2).toDouble() : 10,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    switch (v.toInt()) {
                      case 0: return const Text('待付款', style: TextStyle(fontSize: 11));
                      case 1: return const Text('已支付', style: TextStyle(fontSize: 11));
                      case 2: return const Text('已入住', style: TextStyle(fontSize: 11));
                      default: return const SizedBox();
                    }
                  }, reservedSize: 28)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: pending.toDouble(), color: AppColors.warning, width: 32, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: confirmed.toDouble(), color: AppColors.info, width: 32, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: checkedIn.toDouble(), color: AppColors.success, width: 32, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicePieChart() {
    final online = _stats['online_devices'] ?? 0;
    final total = _stats['devices'] ?? 0;
    final offline = total - online;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('设备在线率', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.pie_chart_outline, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  if (online > 0) PieChartSectionData(value: online.toDouble(), color: AppColors.deviceOnline, title: '在线', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  if (offline > 0) PieChartSectionData(value: offline.toDouble(), color: AppColors.deviceOffline, title: '离线', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  if (total == 0) PieChartSectionData(value: 1, color: AppColors.textHint, title: '暂无', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(AppColors.deviceOnline, '在线 $online'),
              const SizedBox(width: 16),
              _buildLegend(AppColors.deviceOffline, '离线 $offline'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]);
  }

  Widget _buildTopHotelsSection() {
    if (_topHotels.isEmpty) return const SizedBox();
    final top5 = _topHotels.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('酒店排行', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('共${_topHotels.length}家', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          ...top5.asMap().entries.map((entry) {
            final idx = entry.key;
            final hotel = entry.value;
            final colors = [AppColors.warning, AppColors.textSecondary, AppColors.bronze, AppColors.textHint, AppColors.textHint];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: colors[idx].withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Center(child: Text('${idx + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors[idx]))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(hotel.hotelName, style: const TextStyle(fontWeight: FontWeight.w500))),
                Text('${hotel.effectiveStar}星', style: const TextStyle(color: AppColors.warning, fontSize: 12)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: AppColors.primary), title: Text(label), trailing: const Icon(Icons.chevron_right), onTap: onTap);
  }

  void _showCreateHotelDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String selectedStar = '5';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增酒店'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '酒店名称 *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: '酒店地址', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '联系电话', border: OutlineInputBorder(), prefixText: '+86 '), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: '所在城市', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStar,
                  decoration: const InputDecoration(labelText: '星级', border: OutlineInputBorder()),
                  items: ['1', '2', '3', '4', '5'].map((s) => DropdownMenuItem(value: s, child: Text('$s星级'))).toList(),
                  onChanged: (v) => setDialogState(() => selectedStar = v ?? '5'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final dio = DioClient();
                  final res = await dio.post(ApiConstants.hotels, data: {
                    'hotel_name': nameCtrl.text.trim(),
                    'hotel_address': addressCtrl.text.trim(),
                    'hotel_phone': phoneCtrl.text.trim(),
                    'city': cityCtrl.text.trim(),
                    'hotel_star': int.tryParse(selectedStar) ?? 5,
                  });
                  if (res.statusCode == 200 && res.data['code'] == 200) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('酒店创建成功'), backgroundColor: AppColors.success));
                      _loadStats();
                    }
                  } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? '创建失败')));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建失败，请重试')));
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateUserDialog() {
    final usernameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRole = 'customer';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增用户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: '用户名 *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '手机号 *', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: '邮箱', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: '角色', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'customer', child: Text('顾客')),
                    DropdownMenuItem(value: 'staff', child: Text('前台员工')),
                    DropdownMenuItem(value: 'hotel_admin', child: Text('酒店管理员')),
                    DropdownMenuItem(value: 'system_admin', child: Text('系统管理员')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v ?? 'customer'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await ref.read(userServiceProvider).createUser({
                  'username': usernameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'role': selectedRole,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result.success ? '用户创建成功' : (result.message ?? '创建失败')),
                    backgroundColor: result.success ? AppColors.success : AppColors.error,
                  ));
                  if (result.success) _loadStats();
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotelsTab extends ConsumerStatefulWidget {
  const _HotelsTab();
  @override
  ConsumerState<_HotelsTab> createState() => _HotelsTabState();
}

class _HotelsTabState extends ConsumerState<_HotelsTab> {
  List<Hotel> _hotels = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _cityFilter;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(hotelServiceProvider).getHotels(
        keyword: _searchQuery.isNotEmpty ? _searchQuery : null,
        city: _cityFilter,
        pageSize: 100,
      );
      if (result.success && mounted) {
        setState(() => _hotels = result.data ?? []);
      }
    } catch (e) {
      debugPrint('hotels: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _cities {
    final cities = _hotels.map((h) => h.city ?? '').where((c) => c.isNotEmpty).toSet().toList();
    cities.sort();
    return cities;
  }

  List<Hotel> get _filteredHotels {
    if (_searchQuery.isEmpty && _cityFilter == null) return _hotels;
    return _hotels.where((h) {
      final matchCity = _cityFilter == null || h.city == _cityFilter;
      final matchSearch = _searchQuery.isEmpty ||
          h.hotelName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          h.displayAddress.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCity && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        _buildSearchBar(),
        if (_cities.isNotEmpty) _buildCityFilter(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadHotels,
                  child: _filteredHotels.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.hotel_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('暂无酒店', style: TextStyle(color: Colors.grey[500])),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredHotels.length,
                          itemBuilder: (ctx, i) => _HotelCard(
                            hotel: _filteredHotels[i],
                            onEdit: () => _showEditHotelDialog(_filteredHotels[i]),
                            onDelete: () => _deleteHotel(_filteredHotels[i]),
                          ),
                        ),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditHotelDialog(null),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('新增酒店'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索酒店名称/地址',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (v) { _searchQuery = v; _loadHotels(); },
      ),
    );
  }

  Widget _buildCityFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FilterChip(label: '全部', isSelected: _cityFilter == null, onTap: () { setState(() => _cityFilter = null); }),
          const SizedBox(width: 8),
          ..._cities.map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterChip(label: c, isSelected: _cityFilter == c, onTap: () { setState(() => _cityFilter = c); }),
          )),
        ]),
      ),
    );
  }

  void _showEditHotelDialog(Hotel? hotel) {
    final isEdit = hotel != null;
    final nameCtrl = TextEditingController(text: hotel?.hotelName ?? '');
    final addressCtrl = TextEditingController(text: hotel?.hotelAddress ?? '');
    final phoneCtrl = TextEditingController(text: hotel?.hotelPhone ?? '');
    final cityCtrl = TextEditingController(text: hotel?.city ?? '');
    final descCtrl = TextEditingController(text: hotel?.description ?? '');
    String selectedStar = (hotel?.hotelStar ?? 5).toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(isEdit ? '编辑酒店' : '新增酒店', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 20),
                  Flexible(child: SingleChildScrollView(child: Column(children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '酒店名称 *', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: '酒店地址', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '联系电话', border: OutlineInputBorder(), prefixText: '+86 '), keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: '所在城市', border: OutlineInputBorder()))),
                      const SizedBox(width: 12),
                      Expanded(child: DropdownButtonFormField<String>(
                        initialValue: selectedStar,
                        decoration: const InputDecoration(labelText: '星级', border: OutlineInputBorder()),
                        items: ['1', '2', '3', '4', '5'].map((s) => DropdownMenuItem(value: s, child: Text('$s星级'))).toList(),
                        onChanged: (v) => setModalState(() => selectedStar = v ?? '5'),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '酒店描述', border: OutlineInputBorder()), maxLines: 3),
                  ]))),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final data = {
                        'hotel_name': nameCtrl.text.trim(),
                        'hotel_address': addressCtrl.text.trim(),
                        'hotel_phone': phoneCtrl.text.trim(),
                        'city': cityCtrl.text.trim(),
                        'hotel_star': int.tryParse(selectedStar) ?? 5,
                        'description': descCtrl.text.trim(),
                      };
                      try {
                        final dio = DioClient();
                        ApiResult<Map<String, dynamic>> result;
                        if (isEdit) {
                          final res = await dio.put('${ApiConstants.hotels}/${hotel.id}', data: data);
                          result = (res.statusCode == 200 && res.data['code'] == 200)
                              ? ApiResult.success(res.data['data'])
                              : ApiResult.failure(res.data['message'] ?? '更新失败');
                        } else {
                          final res = await dio.post(ApiConstants.hotels, data: data);
                          result = (res.statusCode == 200 && res.data['code'] == 200)
                              ? ApiResult.success(res.data['data'])
                              : ApiResult.failure(res.data['message'] ?? '创建失败');
                        }
                        if (result.success) {
                          _loadHotels();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? '酒店已更新' : '酒店已创建'), backgroundColor: AppColors.success));
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(isEdit ? '保存修改' : '创建酒店'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteHotel(Hotel hotel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除酒店"${hotel.hotelName}"吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final dio = DioClient();
        final res = await dio.delete('${ApiConstants.hotels}/${hotel.id}');
        if (res.statusCode == 200 && res.data['code'] == 200) {
          _loadHotels();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('酒店已删除'), backgroundColor: AppColors.success));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? '删除失败')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey[300]!),
        ),
        child: Text(label, style: GoogleFonts.notoSansSc(fontSize: 13, color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _HotelCard extends StatelessWidget {
  final Hotel hotel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _HotelCard({required this.hotel, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: hotel.displayImage.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(hotel.displayImage, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.hotel, color: AppColors.primary, size: 28)))
                : const Icon(Icons.hotel, color: AppColors.primary, size: 28),
          ),
          title: Row(children: [
            Expanded(child: Text(hotel.hotelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                const Icon(Icons.star, size: 12, color: AppColors.warning),
                Text('${hotel.effectiveStar}', style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Row(children: [Icon(Icons.location_on, size: 14, color: Colors.grey[500]), const SizedBox(width: 4), Expanded(child: Text(hotel.displayAddress, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis))]),
            if (hotel.city != null) Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [Icon(Icons.location_city, size: 14, color: Colors.grey[500]), const SizedBox(width: 4), Text(hotel.city!, style: TextStyle(color: Colors.grey[600], fontSize: 13))])),
          ]),
        ),
        const Divider(height: 1),
        Row(children: [
          Expanded(child: TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit, size: 18), label: const Text('编辑'))),
          const SizedBox(width: 1, height: 40, child: VerticalDivider()),
          Expanded(child: TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete, size: 18, color: Colors.red), label: const Text('删除', style: TextStyle(color: Colors.red)))),
        ]),
      ]),
    );
  }
}

class _DevicesTab extends ConsumerStatefulWidget {
  const _DevicesTab();
  @override
  ConsumerState<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends ConsumerState<_DevicesTab> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _statusFilter;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(deviceServiceProvider).getAllDevices(status: _statusFilter);
      if (result.success && mounted) {
        setState(() => _devices = List<Map<String, dynamic>>.from(result.data ?? []));
      }
    } catch (e) {
      debugPrint('devices: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _deviceTypes {
    final types = _devices.map((d) => d['device_type']?.toString() ?? '').where((t) => t.isNotEmpty).toSet().toList();
    types.sort();
    return types;
  }

  int get _onlineCount => _devices.where((d) => d['status'] == 'online' || d['device_status'] == 'online').length;
  int get _offlineCount => _devices.length - _onlineCount;

  List<Map<String, dynamic>> get _filteredDevices {
    return _devices.where((d) {
      final matchStatus = _statusFilter == null || d['status'] == _statusFilter || d['device_status'] == _statusFilter;
      final matchType = _typeFilter == null || d['device_type'] == _typeFilter;
      final matchSearch = _searchQuery.isEmpty ||
          (d['device_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (d['device_id'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchStatus && matchType && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildStatsBar(),
      _buildSearchBar(),
      _buildFilterBar(),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDevices,
                child: _filteredDevices.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.devices_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('暂无设备', style: TextStyle(color: Colors.grey[500])),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredDevices.length,
                        itemBuilder: (ctx, i) {
                          final d = _filteredDevices[i];
                          final status = d['status'] ?? d['device_status'] ?? 'unknown';
                          Color statusColor;
                          switch (status) {
                            case 'online': statusColor = AppColors.success; break;
                            case 'offline': statusColor = AppColors.textHint; break;
                            default: statusColor = AppColors.warning;
                          }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.devices, color: statusColor),
                              title: Text(d['device_name'] ?? d['name'] ?? '设备${d['id']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('ID: ${d['id']} | ${d['device_type'] ?? ''}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    ]);
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(child: _miniStat('总设备', _devices.length, Icons.devices, AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _miniStat('在线', _onlineCount, Icons.wifi, AppColors.success)),
        const SizedBox(width: 12),
        Expanded(child: _miniStat('离线', _offlineCount, Icons.wifi_off, AppColors.textHint)),
      ]),
    );
  }

  Widget _miniStat(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索设备名称/ID',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Text('状态:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(width: 6),
          _FilterChip(label: '全部', isSelected: _statusFilter == null, onTap: () { setState(() => _statusFilter = null); }),
          const SizedBox(width: 6),
          _FilterChip(label: '在线', isSelected: _statusFilter == 'online', onTap: () { setState(() => _statusFilter = 'online'); }),
          const SizedBox(width: 6),
          _FilterChip(label: '离线', isSelected: _statusFilter == 'offline', onTap: () { setState(() => _statusFilter = 'offline'); }),
          if (_deviceTypes.isNotEmpty) ...[
            const SizedBox(width: 16),
            Text('类型:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(width: 6),
            _FilterChip(label: '全部', isSelected: _typeFilter == null, onTap: () { setState(() => _typeFilter = null); }),
            ..._deviceTypes.take(4).map((t) => Padding(padding: const EdgeInsets.only(left: 6), child: _FilterChip(label: t, isSelected: _typeFilter == t, onTap: () { setState(() => _typeFilter = t); }))),
          ],
        ]),
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();
  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final result = await ref.read(userServiceProvider).getUsers(role: _roleFilter, pageSize: 100);
    if (result.success && mounted) {
      setState(() => _users = result.data ?? []);
    }
    setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((u) {
      final username = (u['username'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return username.contains(query) || phone.contains(query) || email.contains(query);
    }).toList();
  }

  Color _roleColor(String? role) {
    final normalized = AppRoles.normalize(role);
    switch (normalized) {
      case AppRoles.systemAdmin: return AppColors.error;
      case AppRoles.hotelAdmin: return AppColors.primary;
      case AppRoles.staff: return AppColors.secondary;
      default: return AppColors.success;
    }
  }

  String _roleLabel(String? role) => AppRoles.displayName(AppRoles.normalize(role));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildSearchBar(),
      _buildFilterBar(),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadUsers,
                child: _filteredUsers.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('暂无用户', style: TextStyle(color: Colors.grey[500])),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (ctx, i) {
                          final u = _filteredUsers[i];
                          final role = u['role'] ?? 'customer';
                          final isActive = u['is_active'] ?? u['status'] != 'disabled';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: _roleColor(role).withValues(alpha: 0.1), child: Icon(Icons.person, color: _roleColor(role))),
                              title: Row(children: [
                                Text(u['username'] ?? '未知', style: const TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: _roleColor(role).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Text(_roleLabel(role), style: TextStyle(color: _roleColor(role), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                if (!isActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                    child: const Text('已禁用', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ]),
                              subtitle: Text('${u['phone'] ?? '-'} | ${u['email'] ?? '-'}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit': _showEditUserDialog(u); break;
                                    case 'disable': _toggleUserStatus(u); break;
                                    case 'role': _showRoleChangeDialog(u); break;
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                                  PopupMenuItem(value: 'disable', child: Text(isActive ? '禁用' : '启用')),
                                  const PopupMenuItem(value: 'role', child: Text('修改角色')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    ]);
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索用户名/手机号/邮箱',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FilterChip(label: '全部', isSelected: _roleFilter == null, onTap: () { setState(() => _roleFilter = null); _loadUsers(); }),
          const SizedBox(width: 8),
          _FilterChip(label: '顾客', isSelected: _roleFilter == 'customer', onTap: () { setState(() => _roleFilter = 'customer'); _loadUsers(); }),
          const SizedBox(width: 8),
          _FilterChip(label: '前台', isSelected: _roleFilter == 'staff', onTap: () { setState(() => _roleFilter = 'staff'); _loadUsers(); }),
          const SizedBox(width: 8),
          _FilterChip(label: '酒店管理员', isSelected: _roleFilter == 'hotel_admin', onTap: () { setState(() => _roleFilter = 'hotel_admin'); _loadUsers(); }),
          const SizedBox(width: 8),
          _FilterChip(label: '系统管理员', isSelected: _roleFilter == 'system_admin', onTap: () { setState(() => _roleFilter = 'system_admin'); _loadUsers(); }),
        ]),
      ),
    );
  }

  void _showEditUserDialog(dynamic user) {
    final usernameCtrl = TextEditingController(text: user['username'] ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('编辑用户', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 20),
                TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: '用户名', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: '邮箱', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final result = await ref.read(userServiceProvider).updateUser(
                      user['id'],
                      {
                        'username': usernameCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                      },
                    );
                    if (result.success) {
                      _loadUsers();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('用户已更新'), backgroundColor: AppColors.success));
                    } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '更新失败')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('保存修改'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(dynamic user) async {
    final isActive = user['is_active'] ?? user['status'] != 'disabled';
    final result = isActive
        ? await ref.read(userServiceProvider).disableUser(user['id'])
        : await ref.read(userServiceProvider).enableUser(user['id']);
    if (result.success) {
      _loadUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isActive ? '用户已禁用' : '用户已启用'), backgroundColor: AppColors.success));
    }
  }

  void _showRoleChangeDialog(dynamic user) {
    String selectedRole = AppRoles.normalize(user['role']);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('修改角色 - ${user['username']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[AppRoles.customer, AppRoles.staff, AppRoles.hotelAdmin, AppRoles.systemAdmin].map((role) => ListTile(
                title: Text(AppRoles.displayName(role)),
                trailing: selectedRole == role ? const Icon(Icons.check_circle, color: AppColors.primary) : const Icon(Icons.radio_button_unchecked, color: AppColors.textHint),
                onTap: () => setDialogState(() => selectedRole = role),
              )),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await ref.read(userServiceProvider).updateUserRole(user['id'], selectedRole);
                if (result.success) {
                  _loadUsers();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('角色已更新'), backgroundColor: AppColors.success));
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '更新失败')));
                }
              },
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTab extends StatefulWidget {
  const _ReviewTab();
  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final dio = DioClient();
      final res = await dio.get(ApiConstants.authRoleApplications);
      if (res.statusCode == 200 && res.data['code'] == 200) {
        setState(() => _applications = List<Map<String, dynamic>>.from(res.data['data'] ?? []));
      }
    } catch (e) {
      debugPrint('applications: $e');
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'approved' ? '已通过' : '已拒绝'), backgroundColor: AppColors.success));
        _loadApplications();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? '操作失败')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  Future<void> _batchReview(List<Map<String, dynamic>> apps, String status) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'approved' ? '批量通过' : '批量拒绝'),
        content: Text('确定要${status == 'approved' ? '通过' : '拒绝'}${apps.length}条申请吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirm == true) {
      for (final app in apps) {
        await _reviewApplication(app['id'], status);
      }
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
            _buildInfoRow('申请人', app['username'] ?? '-'),
            _buildInfoRow('类型', app['application_type'] == 'create_hotel' ? '创建酒店' : '绑定员工'),
            if (app['hotel_name'] != null) _buildInfoRow('酒店名', app['hotel_name']),
            if (app['hotel_address'] != null) _buildInfoRow('酒店地址', app['hotel_address']),
            if (app['target_hotel_name'] != null) _buildInfoRow('目标酒店', app['target_hotel_name']),
            if (app['reason'] != null) _buildInfoRow('理由', app['reason']),
            if (app['created_at'] != null) _buildInfoRow('申请时间', app['created_at'].toString().substring(0, 19)),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: '审核备注 (可选)', border: OutlineInputBorder()), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _reviewApplication(app['id'], 'rejected', note: noteCtrl.text.trim()); },
            child: const Text('拒绝', style: TextStyle(color: AppColors.error)),
          ),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); _reviewApplication(app['id'], 'approved', note: noteCtrl.text.trim()); },
            child: const Text('通过'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 80, child: Text('$label:', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final pendingApps = _applications.where((a) => a['status'] == 'pending').toList();
    final reviewedApps = _applications.where((a) => a['status'] != 'pending').toList();

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: DefaultTabController(
        length: 2,
        child: Column(children: [
          Container(
            color: Colors.white,
            child: TabBar(
              tabs: [
                Tab(text: '待审核 (${pendingApps.length})'),
                Tab(text: '已审核 (${reviewedApps.length})'),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
            ),
          ),
          if (pendingApps.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton.icon(onPressed: () => _batchReview(pendingApps, 'approved'), icon: const Icon(Icons.check_circle, size: 18), label: const Text('全部通过'), style: TextButton.styleFrom(foregroundColor: AppColors.success)),
                TextButton.icon(onPressed: () => _batchReview(pendingApps, 'rejected'), icon: const Icon(Icons.cancel, size: 18), label: const Text('全部拒绝'), style: TextButton.styleFrom(foregroundColor: AppColors.error)),
              ]),
            ),
          Expanded(child: TabBarView(children: [
            _buildAppList(pendingApps, showActions: true),
            _buildAppList(reviewedApps, showActions: false),
          ])),
        ]),
      ),
    );
  }

  Widget _buildAppList(List<Map<String, dynamic>> apps, {required bool showActions}) {
    if (apps.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.fact_check_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('暂无数据', style: TextStyle(color: Colors.grey[500])),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      itemBuilder: (ctx, i) {
        final app = apps[i];
        final status = app['status'] ?? 'pending';
        Color statusColor;
        String statusText;
        switch (status) {
          case 'approved': statusColor = AppColors.success; statusText = '已通过'; break;
          case 'rejected': statusColor = AppColors.error; statusText = '已拒绝'; break;
          default: statusColor = AppColors.warning; statusText = '待审核';
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 8),
              Text('申请人: ${app['username'] ?? '-'} | 时间: ${app['created_at']?.toString().substring(0, 10) ?? '-'}'),
              if (app['reason'] != null) Text('理由: ${app['reason']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              if (app['review_note'] != null) Text('审核备注: ${app['review_note']}', style: const TextStyle(color: AppColors.info, fontSize: 13)),
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(onPressed: () => _showReviewDialog(app), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary), child: const Text('审核')),
                ]),
              ],
            ]),
          ),
        );
      },
    );
  }
}
