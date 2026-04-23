import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/storage/local_storage.dart';
import '../../services/auth_service.dart';
import '../../services/hotel_service.dart';
import '../../services/room_service.dart';
import '../../services/device_service.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/auth/auth_state_notifier.dart';
import 'device_monitor_page.dart';
import 'room_manage_page.dart';
import 'hotel_edit_page.dart';
import 'reports_page.dart';
import 'environment_monitor_page.dart';
import 'floor_manage_page.dart';
import 'price_calendar_page.dart';
import 'coupon_manage_page.dart';
import 'user_manage_page.dart';
import 'room_type_manage_page.dart';
import 'review_manage_page.dart';
import 'knowledge_base_manage_page.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedIndex = 0;
  bool _showMoreMenu = false;

  final List<_NavItem> _mainNavItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: '总览'),
    _NavItem(icon: Icons.devices_rounded, label: '设备'),
    _NavItem(icon: Icons.door_back_door_rounded, label: '房间'),
  ];

  final List<_MoreItem> _moreItems = const [
    _MoreItem(icon: Icons.hotel_rounded, label: '酒店信息', pageKey: 'hotel'),
    _MoreItem(icon: Icons.assessment_rounded, label: '报表', pageKey: 'reports'),
    _MoreItem(icon: Icons.rate_review_rounded, label: '评价管理', pageKey: 'review_manage'),
    _MoreItem(icon: Icons.thermostat_rounded, label: '环境', pageKey: 'environment'),
    _MoreItem(icon: Icons.layers_rounded, label: '楼层', pageKey: 'floor'),
    _MoreItem(icon: Icons.price_check_rounded, label: '价格', pageKey: 'price'),
    _MoreItem(icon: Icons.local_offer_rounded, label: '优惠券', pageKey: 'coupon'),
    _MoreItem(icon: Icons.people_rounded, label: '用户', pageKey: 'user'),
    _MoreItem(icon: Icons.hotel_rounded, label: '房型', pageKey: 'room_type'),
    _MoreItem(icon: Icons.menu_book_rounded, label: '知识库', pageKey: 'knowledge_base'),
  ];

  late final List<Widget> _mainPages;

  @override
  void initState() {
    super.initState();
    _mainPages = [
      const _DashboardContent(),
      const DeviceMonitorPage(),
      const RoomManagePage(),
    ];
  }

  void _onNavTap(int index) {
    if (index == 3) {
      setState(() => _showMoreMenu = !_showMoreMenu);
    } else {
      setState(() {
        _selectedIndex = index;
        _showMoreMenu = false;
      });
    }
  }

  void _navigateToMorePage(String pageKey) {
    setState(() => _showMoreMenu = false);
    Widget page;
    switch (pageKey) {
      case 'hotel': page = const HotelEditPage(); break;
      case 'reports': page = const ReportsPage(); break;
      case 'review_manage': page = const AdminReviewManagePage(); break;
      case 'environment': page = const EnvironmentMonitorPage(); break;
      case 'floor': page = const FloorManagePage(); break;
      case 'price': page = const PriceCalendarPage(); break;
      case 'coupon': page = const CouponManagePage(); break;
      case 'user': page = const UserManagePage(); break;
      case 'room_type': page = const RoomTypeManagePage(); break;
      case 'knowledge_base': page = const KnowledgeBaseManagePage(); break;
      default: return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('慧宿 - 管理端', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
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
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _selectedIndex < _mainPages.length ? _mainPages[_selectedIndex] : const _DashboardContent(),
          ),
          if (_showMoreMenu)
            GestureDetector(
              onTap: () => setState(() => _showMoreMenu = false),
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
          if (_showMoreMenu)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: _buildMoreMenu(),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex > 2 ? 3 : _selectedIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 12),
          items: [
            ..._mainNavItems.map((item) => BottomNavigationBarItem(icon: Icon(item.icon), label: item.label)),
            const BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: '更多'),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenu() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: _moreItems.map((item) => GestureDetector(
            onTap: () => _navigateToMorePage(item.pageKey),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(item.icon, size: 24, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(item.label, style: GoogleFonts.notoSansSc(fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          )).toList(),
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

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _MoreItem {
  final IconData icon;
  final String label;
  final String pageKey;
  const _MoreItem({required this.icon, required this.label, required this.pageKey});
}

class _DashboardContent extends ConsumerStatefulWidget {
  const _DashboardContent();

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _roomDistribution;
  Map<String, dynamic> _deviceStats = {};
  List<dynamic> _todayActivities = [];
  List<dynamic> _weeklyRevenue = []; // 周营收数据
  bool _isLoading = true;
  bool _isMonthlyView = true; // true = 月视图, false = 周视图
  double _todayRevenueFromReport = 0;
  double _monthRevenueFromReport = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 获取当前酒店ID
      final hotelIdStr = await LocalStorage().read('hotel_id');
      final hotelId = hotelIdStr != null ? int.tryParse(hotelIdStr) : null;

      // 并行加载统计数据和报表数据（包含周营收）
      final statsResult = await ref.read(hotelServiceProvider).getDashboardStats();
      final distResult = await ref.read(roomServiceProvider).getRoomStatusDistribution();
      final reportsRes = await ref.read(hotelServiceProvider).getReports(hotelId: hotelId);

      if (reportsRes.success && reportsRes.data != null) {
        final reportData = reportsRes.data!;
        // 优先使用报表接口的营收数据
        final todayRev = reportData['today_revenue'];
        final monthRev = reportData['month_revenue'];
        if (todayRev != null) {
          _todayRevenueFromReport = (todayRev is num) ? todayRev.toDouble() : double.tryParse(todayRev.toString()) ?? 0;
        }
        if (monthRev != null) {
          _monthRevenueFromReport = (monthRev is num) ? monthRev.toDouble() : double.tryParse(monthRev.toString()) ?? 0;
        }
        final trendData = reportData['revenue_trend'] as List<dynamic>? ?? [];
        _weeklyRevenue = trendData.map((e) {
          if (e is Map) {
            final rev = e['revenue'];
            if (rev is num) return rev.toDouble();
            if (rev is String) return double.tryParse(rev) ?? 0;
          }
          return 0.0;
        }).toList();
      }
      final deviceResult = await ref.read(deviceServiceProvider).getAllDevices();

      List<dynamic> activities = [];
      try {
        final dio = DioClient();
        final res = await dio.get('${ApiConstants.hotel}/statistics');
        if (res.statusCode == 200 && res.data['code'] == 200) {
          final data = res.data['data'];
          final recentBookings = data?['recent_bookings'] as List<dynamic>? ?? [];
          for (final b in recentBookings.take(5)) {
            activities.add({
              'title': '${b['guest_name'] ?? '客人'} 预订 ${b['room_number'] ?? '房间'}',
              'time': _formatTime(b['created_at']),
              'icon': Icons.add_business_rounded,
              'color': AppColors.info,
            });
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _stats = statsResult.success ? statsResult.data : null;
          _roomDistribution = distResult.success ? distResult.data : null;
          _todayActivities = activities;
        });

        if (deviceResult.success) {
          final devices = deviceResult.data ?? [];
          int online = 0, offline = 0, warning = 0;
          for (final d in devices) {
            final status = d['status'] ?? d['device_status'] ?? 'offline';
            if (status == 'online') {
              online++;
            } else if (status == 'warning') {
              warning++;
            } else {
              offline++;
            }
          }
          setState(() {
            _deviceStats = {'online': online, 'offline': offline, 'warning': warning, 'total': devices.length};
          });
        }
      }
    } catch (e) {
      debugPrint('dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(dynamic time) {
    if (time == null) return '';
    try {
      final dt = DateTime.parse(time.toString());
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      return '${diff.inDays}天前';
    } catch (_) {
      return '';
    }
  }

  void _navigateToTab(int tabIndex) {
    final parent = context.findAncestorStateOfType<_AdminDashboardPageState>();
    parent?.setState(() {
      parent._selectedIndex = tabIndex;
      parent._showMoreMenu = false;
    });
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
    final onlineDevices = (_deviceStats['online'] ?? 0).toString();
    final todayBookings = _stats?['today_bookings']?.toString() ?? '0';

    // 优先使用报表接口的营收数据，如果没有则使用dashboard stats的数据
    final todayRevenueVal = _todayRevenueFromReport > 0 ? _todayRevenueFromReport : _stats?['today_revenue'];
    final todayRevenue = todayRevenueVal != null
        ? (todayRevenueVal is num ? todayRevenueVal.toDouble() : double.tryParse(todayRevenueVal.toString()) ?? 0)
        : 0;

    final monthRevenueVal = _monthRevenueFromReport > 0 ? _monthRevenueFromReport : _stats?['month_revenue'];
    final monthRevenue = monthRevenueVal != null
        ? (monthRevenueVal is num ? monthRevenueVal.toDouble() : double.tryParse(monthRevenueVal.toString()) ?? 0)
        : 0;

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
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(context, '总房间数', totalRooms, Icons.door_back_door, Colors.blue, onTap: () => _navigateToTab(2)),
                _buildStatCard(context, '入住率', occupancyRate, Icons.trending_up, Colors.green, onTap: () => _navigateToTab(2)),
                _buildStatCard(context, '今日收入', '¥${todayRevenue.toStringAsFixed(0)}', Icons.payments, AppColors.primary),
                _buildStatCard(context, '本月收入', '¥${monthRevenue.toStringAsFixed(0)}', Icons.account_balance_wallet, AppColors.primaryDark),
                _buildStatCard(context, '在线设备', onlineDevices, Icons.devices, Colors.indigo, onTap: () => _navigateToTab(1)),
                _buildStatCard(context, '今日预订', todayBookings, Icons.calendar_today, Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            _buildRevenueTrendSection(),
            const SizedBox(height: 24),
            _buildChartSection(context),
            const SizedBox(height: 24),
            _buildDevicePieSection(),
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

  Widget _buildRevenueTrendSection() {
    final monthlyTrend = _stats?['monthly_revenue'] as List<dynamic>? ?? [];
    final displayTrend = _isMonthlyView ? monthlyTrend : _getWeeklyData(monthlyTrend);
    final spots = <FlSpot>[];
    if (displayTrend.isNotEmpty) {
      for (int i = 0; i < displayTrend.length; i++) {
        final value = displayTrend[i];
        double numValue = 0;
        if (value is num) {
          numValue = value.toDouble();
        } else if (value is String) {
          numValue = double.tryParse(value) ?? 0;
        }
        spots.add(FlSpot(i.toDouble(), numValue));
      }
    } else {
      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), (1000 + i * 800 + (i % 3) * 500).toDouble()));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('营收趋势', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              _buildToggleButton(),
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
                    final labels = _isMonthlyView 
                        ? (displayTrend.isNotEmpty ? List.generate(displayTrend.length, (i) => '${i + 1}日') : ['1日', '5日', '10日', '15日', '20日', '25日', '30日'])
                        : ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
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

  List<dynamic> _getWeeklyData(List<dynamic> monthlyData) {
    // 优先使用从报表接口获取的真实周数据
    if (_weeklyRevenue.isNotEmpty) {
      return _weeklyRevenue;
    }
    // 如果没有周数据，则使用月数据的最后7个作为降级方案
    if (monthlyData.isEmpty) return [];
    if (monthlyData.length >= 7) {
      return monthlyData.sublist(monthlyData.length - 7);
    }
    return monthlyData;
  }

  Widget _buildToggleButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption('月', true),
          _buildToggleOption('周', false),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isMonthly) {
    final isSelected = _isMonthlyView == isMonthly;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMonthlyView = isMonthly;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansSc(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    final dist = _roomDistribution?['distribution'] as Map<String, dynamic>? ?? {};
    final available = dist['available'] ?? 0;
    final occupied = dist['occupied'] ?? 0;
    final cleaning = dist['cleaning'] ?? 0;
    final maintenance = dist['maintenance'] ?? 0;
    final reserved = dist['reserved'] ?? 0;

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
                  if (reserved > 0) PieChartSectionData(value: reserved.toDouble(), color: Colors.orange, title: '预订', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  if (cleaning > 0) PieChartSectionData(value: cleaning.toDouble(), color: AppColors.roomCleaning, title: '清扫', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  if (maintenance > 0) PieChartSectionData(value: maintenance.toDouble(), color: AppColors.roomMaintenance, title: '维修', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildLegend(AppColors.roomAvailable, '空闲 $available'),
              _buildLegend(AppColors.roomOccupied, '已入住 $occupied'),
              _buildLegend(AppColors.roomCleaning, '清扫中 $cleaning'),
              if (maintenance > 0) _buildLegend(AppColors.roomMaintenance, '维修 $maintenance'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDevicePieSection() {
    final online = _deviceStats['online'] ?? 0;
    final offline = _deviceStats['offline'] ?? 0;
    final warning = _deviceStats['warning'] ?? 0;
    final total = _deviceStats['total'] ?? 0;

    if (total == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('设备在线状态', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(onTap: () => _navigateToTab(1), child: Text('查看详情', style: TextStyle(color: AppColors.primary, fontSize: 12))),
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
                  if (warning > 0) PieChartSectionData(value: warning.toDouble(), color: AppColors.deviceWarning, title: '告警', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  if (offline > 0) PieChartSectionData(value: offline.toDouble(), color: AppColors.deviceOffline, title: '离线', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(AppColors.deviceOnline, '在线 $online'),
              const SizedBox(width: 12),
              if (warning > 0) ...[_buildLegend(AppColors.deviceWarning, '告警 $warning'), const SizedBox(width: 12)],
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

  Widget _buildActivitySection(BuildContext context) {
    final activities = _todayActivities.isNotEmpty
        ? _todayActivities
        : [
            {'title': '101房 灯光已开启', 'time': '2分钟前', 'icon': Icons.lightbulb_outline, 'color': Colors.green},
            {'title': '202房 温度异常告警', 'time': '15分钟前', 'icon': Icons.warning_amber_rounded, 'color': Colors.red},
            {'title': '305房 客人已退房', 'time': '1小时前', 'icon': Icons.logout_rounded, 'color': Colors.blue},
            {'title': '新预订：401房', 'time': '2小时前', 'icon': Icons.add_business_rounded, 'color': Colors.orange},
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('今日动态', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()));
                },
                child: Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...activities.map((a) => _ActivityItem(
            title: a['title'] ?? '',
            time: a['time'] ?? '',
            icon: a['icon'] ?? Icons.info,
            color: a['color'] ?? AppColors.primary,
          )),
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
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
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

    return Scaffold(
      appBar: AppBar(title: const Text('审核管理'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: RefreshIndicator(
        onRefresh: _loadApplications,
        child: DefaultTabController(
          length: 2,
          child: Column(children: [
            TabBar(tabs: [Tab(text: '待审核 (${pending.length})'), Tab(text: '已审核 (${reviewed.length})')], labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSecondary, indicatorColor: AppColors.primary),
            Expanded(child: TabBarView(children: [_buildList(pending, true), _buildList(reviewed, false)])),
          ]),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> apps, bool showActions) {
    if (apps.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.fact_check_outlined, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), Text('暂无数据', style: TextStyle(color: Colors.grey[500]))]));
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
              Text('申请人: ${app['username'] ?? '-'} | ${DateUtils.formatDateDynamic(app['created_at'])}'),
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
