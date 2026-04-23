import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/hotel_service.dart';
import '../../services/maintenance_service.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';
import '../../services/delivery_service.dart';
import '../../services/environment_service.dart';
import 'checkin_out_page.dart';
import 'bookings_page.dart';
import 'room_availability_page.dart';
import 'device_management_page.dart';
import 'work_orders_page.dart';
import 'delivery_orders_page.dart';
import 'voice_calls_page.dart';
import 'bills_page.dart';
import 'price_settings_page.dart';
import '../admin/environment_monitor_page.dart';
import 'environment_monitor_page.dart';
import '../admin/price_calendar_page.dart';
import '../admin/coupon_manage_page.dart';

class ReceptionDashboardPage extends ConsumerStatefulWidget {
  const ReceptionDashboardPage({super.key});

  @override
  ConsumerState<ReceptionDashboardPage> createState() => ReceptionDashboardPageState();
}

class ReceptionDashboardPageState extends ConsumerState<ReceptionDashboardPage> {
  int _currentIndex = 0;
  int _notificationCount = 0;
  bool _hasEnvAlert = false;

  final List<_BottomNavItem> _bottomNavItems = const [
    _BottomNavItem(icon: Icons.dashboard_rounded, label: '总览', pageKey: 'dashboard'),
    _BottomNavItem(icon: Icons.how_to_reg_rounded, label: '接待', pageKey: 'checkin_out'),
    _BottomNavItem(icon: Icons.door_back_door_rounded, label: '客房', pageKey: 'rooms'),
    _BottomNavItem(icon: Icons.build_rounded, label: '工单', pageKey: 'work_orders'),
    _BottomNavItem(icon: Icons.receipt_long_rounded, label: '账单', pageKey: 'bills'),
  ];

  final List<_DrawerItemBase> _drawerItems = const [
    _DrawerItem(icon: Icons.calendar_month_rounded, label: '预订管理', pageKey: 'bookings'),
    _DrawerItem(icon: Icons.devices_rounded, label: '设备管理', pageKey: 'devices'),
    _DrawerItem(icon: Icons.delivery_dining_rounded, label: '客房送物', pageKey: 'delivery'),
    _DrawerItem(icon: Icons.phone_in_talk_rounded, label: '语音通话', pageKey: 'voice_calls'),
    _DrawerItem(icon: Icons.thermostat_rounded, label: '环境监测', pageKey: 'environment'),
    _DrawerItem(icon: Icons.security_rounded, label: '报警面板', pageKey: 'alarms'),
    _DividerItem(),
    _DrawerItem(icon: Icons.price_change_rounded, label: '房价设置', pageKey: 'price_settings'),
    _DrawerItem(icon: Icons.calendar_today_rounded, label: '价格日历', pageKey: 'price_calendar'),
    _DrawerItem(icon: Icons.local_offer_rounded, label: '优惠券管理', pageKey: 'coupons'),
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final maintenanceResult = await ref.read(maintenanceServiceProvider).getWorkOrders(status: 'pending', pageSize: 1);
      final deliveryResult = await ref.read(deliveryServiceProvider).getDeliveryOrders(status: 'pending', pageSize: 1);
      int count = 0;
      if (maintenanceResult.success) count += 1;
      if (deliveryResult.success) count += 1;
      try {
        final envResult = await ref.read(environmentServiceProvider).getEventLogs(limit: 5);
        if (envResult.success && (envResult.data?.isNotEmpty ?? false)) {
          _hasEnvAlert = true;
          count += 1;
        }
      } catch (_) {}
      if (mounted) setState(() => _notificationCount = count);
    } catch (e) {
      debugPrint('✗ notifications: $e');
    }
  }

  Widget _getPage(String pageKey) {
    switch (pageKey) {
      case 'dashboard':
        return const _ReceptionHomeContent();
      case 'checkin_out':
        return const CheckInOutPage();
      case 'rooms':
        return const RoomAvailabilityPage();
      case 'work_orders':
        return const WorkOrdersPage();
      case 'bills':
        return const BillsPage();
      case 'bookings':
        return const BookingsPage();
      case 'devices':
        return const DeviceManagementPage();
      case 'delivery':
        return const DeliveryOrdersPage();
      case 'voice_calls':
        return const VoiceCallsPage();
      case 'environment':
        return const EnvironmentMonitorPage();
      case 'alarms':
        return const ReceptionEnvironmentPage();
      case 'price_settings':
        return const PriceSettingsPage();
      case 'price_calendar':
        return const PriceCalendarPage();
      case 'coupons':
        return const CouponManagePage();
      default:
        return const _ReceptionHomeContent();
    }
  }

  void _navigateToPage(String pageKey) {
    final bottomIndex = _bottomNavItems.indexWhere((item) => item.pageKey == pageKey);
    if (bottomIndex >= 0) {
      setState(() => _currentIndex = bottomIndex);
    } else {
      // 先关闭抽屉，再显示页面
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showPageAsSheet(pageKey);
    }
  }

  void _showPageAsSheet(String pageKey) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _SubPageScaffold(
        title: _getPageTitle(pageKey),
        child: _getPage(pageKey),
      ),
    ));
  }

  String _getPageTitle(String pageKey) {
    switch (pageKey) {
      case 'bookings': return '预订管理';
      case 'devices': return '设备管理';
      case 'delivery': return '客房送物';
      case 'voice_calls': return '语音通话';
      case 'environment': return '环境监测';
      case 'alarms': return '报警面板';
      case 'price_settings': return '房价设置';
      case 'price_calendar': return '价格日历';
      case 'coupons': return '优惠券管理';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPageKey = _bottomNavItems[_currentIndex].pageKey;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('慧宿 · 前台端', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                onPressed: () => _showNotificationPanel(),
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text('$_notificationCount', style: const TextStyle(color: Colors.white, fontSize: 9), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
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
      drawer: _buildDrawer(),
      body: _getPage(currentPageKey),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _bottomNavItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == _currentIndex;
                return _BottomNavItemWidget(
                  icon: item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  onTap: () => setState(() => _currentIndex = index),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final authState = ref.read(authStateProvider);
    final username = authState.username;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.support_agent, size: 28, color: AppColors.primary)),
                  const SizedBox(height: 12),
                  Text(username ?? '前台员工', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Text('前台管理', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('更多功能', style: GoogleFonts.notoSansSc(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ),
                  ..._drawerItems.map((item) {
                    if (item is _DividerItem) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Divider(height: 1),
                      );
                    }
                    final drawerItem = item as _DrawerItem;
                    return ListTile(
                      leading: Icon(drawerItem.icon, size: 22, color: AppColors.textSecondary),
                      title: Text(drawerItem.label, style: GoogleFonts.notoSansSc(fontSize: 14)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
                      onTap: () => _navigateToPage(drawerItem.pageKey),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.swap_horiz, size: 22),
              title: const Text('切换模式'),
              onTap: () {
                Navigator.pop(context);
                _showModeSwitchDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, size: 22, color: AppColors.error),
              title: const Text('退出登录', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                await ref.read(authServiceProvider).logout();
                if (!context.mounted) return;
                context.go('/login');
              },
            ),
            const SizedBox(height: 8),
          ],
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
      AppMode.system: '系统管理',
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

  void _showNotificationPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('消息通知', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildNotificationItem('工单处理', '有新的待处理工单', Icons.build_rounded, AppColors.warning, 'work_orders'),
            _buildNotificationItem('客房送物', '有新的送物请求', Icons.delivery_dining_rounded, AppColors.info, 'delivery'),
            if (_hasEnvAlert)
              _buildNotificationItem('环境异常', '有环境异常告警', Icons.thermostat_rounded, AppColors.error, 'environment'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).then((_) => _loadNotificationCount());
  }

  Widget _buildNotificationItem(String title, String desc, IconData icon, Color color, String pageKey) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        _navigateToPage(pageKey);
      },
    );
  }
}

class _ReceptionHomeContent extends ConsumerStatefulWidget {
  const _ReceptionHomeContent();

  @override
  ConsumerState<_ReceptionHomeContent> createState() => _ReceptionHomeContentState();
}

class _ReceptionHomeContentState extends ConsumerState<_ReceptionHomeContent> {
  Map<String, dynamic>? _dashboardStats;
  List<dynamic> _workOrders = [];
  List<Booking> _arrivals = [];
  List<Booking> _todayCheckIns = [];
  List<Booking> _todayCheckOuts = [];
  List<Booking> _currentGuests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // 获取当前用户的酒店ID
      final hotelId = await ref.read(authServiceProvider).getCurrentHotelId();
      
      final statsResult = await ref.read(hotelServiceProvider).getDashboardStats();
      final workOrdersResult = await ref.read(maintenanceServiceProvider).getWorkOrders(status: 'pending', pageSize: 5);
      final arrivalsResult = await ref.read(hotelServiceProvider).getTodayArrivals();
      final bookingsResult = await ref.read(bookingServiceProvider).getBookings(
        pageSize: 100,
        hotelId: hotelId,
      );

      if (mounted) {
        final allBookingsRaw = bookingsResult.success ? (bookingsResult.data ?? []) : [];
        final allBookings = allBookingsRaw is List<Booking>
            ? allBookingsRaw
            : allBookingsRaw.map((b) => b is Booking ? b : Booking.fromJson(b as Map<String, dynamic>)).toList();
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        setState(() {
          _dashboardStats = statsResult.success ? statsResult.data : null;
          _workOrders = workOrdersResult.success ? (workOrdersResult.data ?? []) : [];
          _arrivals = arrivalsResult.success
              ? (arrivalsResult.data ?? []).map((a) => a is Booking ? a : Booking.fromJson(a as Map<String, dynamic>)).toList()
              : [];
          _todayCheckIns = allBookings.where((b) =>
            b.status == 'confirmed' && b.checkInDate.toString().startsWith(todayStr)
          ).toList();
          _todayCheckOuts = allBookings.where((b) =>
            b.status == 'checked_in'
          ).toList();
          _currentGuests = allBookings.where((b) => b.status == 'checked_in').toList();
        });
      }
    } catch (e) {
      debugPrint('✗ dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToPage(String pageKey) {
    final state = context.findAncestorStateOfType<ReceptionDashboardPageState>();
    final bottomIndex = state?._bottomNavItems.indexWhere((item) => item.pageKey == pageKey) ?? -1;
    if (bottomIndex >= 0 && state != null) {
      state.setState(() => state._currentIndex = bottomIndex);
    } else if (state != null) {
      state._navigateToPage(pageKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    // 优先使用本地计算的数据，_dashboardStats 作为次要数据源
    // 当 _dashboardStats 返回0值时不应覆盖本地计算的正确数据
    final statsCheckIn = _dashboardStats?['today_checkin'];
    final statsCheckOut = _dashboardStats?['today_checkout'];
    final statsGuests = _dashboardStats?['current_guests'];
    final statsTasks = _dashboardStats?['pending_tasks'];

    final todayCheckIn = (statsCheckIn != null && statsCheckIn != 0)
        ? statsCheckIn.toString()
        : _todayCheckIns.length.toString();
    final todayCheckOut = (statsCheckOut != null && statsCheckOut != 0)
        ? statsCheckOut.toString()
        : _todayCheckOuts.length.toString();
    final currentGuests = (statsGuests != null && statsGuests != 0)
        ? statsGuests.toString()
        : _currentGuests.length.toString();
    final pendingTasks = (statsTasks != null && statsTasks != 0)
        ? statsTasks.toString()
        : _workOrders.length.toString();

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
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
              childAspectRatio: 1.4,
              children: [
                _QuickStatCard(title: '今日入住', value: todayCheckIn, icon: Icons.login_rounded, color: AppColors.success, onTap: () => _navigateToPage('checkin_out')),
                _QuickStatCard(title: '今日退房', value: todayCheckOut, icon: Icons.logout_rounded, color: AppColors.warning, onTap: () => _navigateToPage('checkin_out')),
                _QuickStatCard(title: '在住客人', value: currentGuests, icon: Icons.people_rounded, color: AppColors.info, onTap: () => _navigateToPage('rooms')),
                _QuickStatCard(title: '待处理事项', value: pendingTasks, icon: Icons.pending_actions_rounded, color: AppColors.error, onTap: () => _navigateToPage('work_orders')),
              ],
            ),
            const SizedBox(height: 24),
            _buildTodayTimeline(),
            const SizedBox(height: 24),
            _buildCurrentGuestsTable(),
            const SizedBox(height: 24),
            _buildTaskCard(context),
            const SizedBox(height: 24),
            _buildArrivalCard(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('今日入住/退房', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(onTap: () => _navigateToPage('checkin_out'), child: Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 16),
          if (_todayCheckIns.isEmpty && _todayCheckOuts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('今日暂无入住/退房安排', style: TextStyle(color: AppColors.textSecondary))),
            )
          else ...[
            if (_todayCheckIns.isNotEmpty) ...[
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text('今日入住 ${_todayCheckIns.length}', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 8),
              ..._todayCheckIns.take(3).map((b) => _TimelineItem(
                icon: Icons.login_rounded,
                color: AppColors.success,
                title: b.guestName ?? '-',
                subtitle: '${b.roomNumber ?? '${b.roomId}号房'} · ${b.roomType ?? ''}',
                time: DateUtils.formatDotDate(b.checkInDate),
              )),
            ],
            if (_todayCheckOuts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text('今日退房 ${_todayCheckOuts.length}', style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 8),
              ..._todayCheckOuts.take(3).map((b) => _TimelineItem(
                icon: Icons.logout_rounded,
                color: AppColors.warning,
                title: b.guestName ?? '-',
                subtitle: '${b.roomNumber ?? '${b.roomId}号房'} · ${b.roomType ?? ''}',
                time: DateUtils.formatDotDate(b.checkOutDate),
              )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentGuestsTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('在住客人', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(onTap: () => _navigateToPage('rooms'), child: Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 12),
          if (_currentGuests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('暂无在住客人', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ..._currentGuests.take(5).map((b) => Column(
              children: [
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 16, backgroundColor: AppColors.info.withValues(alpha: 0.1), child: Text((b.guestName ?? '?')[0], style: TextStyle(color: AppColors.info, fontSize: 14, fontWeight: FontWeight.bold))),
                  title: Text('${b.guestName ?? '-'} · ${b.roomNumber ?? '${b.roomId}号房'}', style: GoogleFonts.notoSansSc(fontSize: 14)),
                  subtitle: Text('${DateUtils.formatDotDate(b.checkInDate)} ~ ${DateUtils.formatDotDate(b.checkOutDate)}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SmallActionButton(label: '退房', color: AppColors.warning, onTap: () => _handleCheckout(b)),
                      const SizedBox(width: 6),
                      _SmallActionButton(label: '续住', color: AppColors.primary, onTap: () => _handleExtendStay(b)),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            )),
        ],
      ),
    );
  }

  Future<void> _handleCheckout(Booking booking) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认退房'),
      content: Text('客人：${booking.guestName ?? '-'}，房间：${booking.roomNumber ?? '${booking.roomId}号房'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('确认退房')),
      ],
    ));
    if (confirm != true) return;

    try {
      final result = await ref.read(bookingServiceProvider).checkout(booking.id);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('退房办理成功'), backgroundColor: AppColors.success));
        _loadDashboardData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  void _handleExtendStay(Booking booking) {
    context.push('/extend-stay/${booking.id}', extra: {'bookingId': booking.id});
  }

  Widget _buildTaskCard(BuildContext context) {
    final urgentCount = _workOrders.where((w) => w['is_urgent'] == true || w['priority'] == 'high').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('待处理工单', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(children: [
                if (urgentCount > 0)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text('$urgentCount个加急', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                GestureDetector(onTap: () => _navigateToPage('work_orders'), child: Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12))),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          if (_workOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('暂无待处理工单', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ..._workOrders.take(3).expand((order) => [
              _WorkOrderItem(
                room: '${order['room_number'] ?? ''}房',
                type: order['type'] ?? '其他',
                desc: order['description'] ?? '待处理',
                time: _formatTime(order['created_at']),
                urgent: order['is_urgent'] == true || order['priority'] == 'high',
              ),
              const Divider(height: 1),
            ]),
        ],
      ),
    );
  }

  String _formatTime(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      final date = DateTime.parse(dateTime.toString());
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      return '${diff.inDays}天前';
    } catch (e) {
      return dateTime.toString();
    }
  }

  Widget _buildArrivalCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('今日预订到店', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(onTap: () => _navigateToPage('bookings'), child: Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 12),
          if (_arrivals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('暂无今日到店预订', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ..._arrivals.take(3).map(
              (b) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(radius: 14, backgroundColor: AppColors.background, child: Icon(Icons.person_outline, size: 16)),
                title: Text('${b.guestName ?? '-'} · ${b.roomType ?? '-'} · ${b.checkInDate.month}/${b.checkInDate.day}', style: GoogleFonts.notoSansSc(fontSize: 14)),
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
  final VoidCallback? onTap;
  const _QuickStatCard({required this.title, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.1))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
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
            if (onTap != null) const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  const _TimelineItem({required this.icon, required this.color, required this.title, required this.subtitle, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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

class _BottomNavItem {
  final IconData icon;
  final String label;
  final String pageKey;
  const _BottomNavItem({required this.icon, required this.label, required this.pageKey});
}

class _DrawerItem implements _DrawerItemBase {
  final IconData icon;
  final String label;
  final String pageKey;
  const _DrawerItem({required this.icon, required this.label, required this.pageKey});
}

class _DividerItem implements _DrawerItemBase {
  const _DividerItem();
}

abstract class _DrawerItemBase {}

class _BottomNavItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _BottomNavItemWidget({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isSelected ? AppColors.primary : AppColors.textHint),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.notoSansSc(fontSize: 11, color: isSelected ? AppColors.primary : AppColors.textHint, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _SubPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _SubPageScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: child,
    );
  }
}
