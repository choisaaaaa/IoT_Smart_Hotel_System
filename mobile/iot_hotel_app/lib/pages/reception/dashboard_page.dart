﻿import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/hotel_service.dart';
import '../../services/maintenance_service.dart';
import '../../services/booking_service.dart';
import '../../services/delivery_service.dart';
import '../../services/room_type_service.dart';
import 'device_management_page.dart';
import 'work_orders_page.dart';
import 'delivery_orders_page.dart';
import 'room_availability_page.dart';
import 'voice_calls_page.dart';
import 'bills_page.dart';
import '../../services/environment_service.dart';
import '../admin/environment_monitor_page.dart';
import '../admin/price_calendar_page.dart';
import '../admin/coupon_manage_page.dart';

class ReceptionDashboardPage extends ConsumerStatefulWidget {
  const ReceptionDashboardPage({super.key});

  @override
  ConsumerState<ReceptionDashboardPage> createState() => _ReceptionDashboardPageState();
}

class _ReceptionDashboardPageState extends ConsumerState<ReceptionDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _notificationCount = 0;
  bool _hasEnvAlert = false;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: '总览'),
    _NavItem(icon: Icons.how_to_reg_rounded, label: '入住退房'),
    _NavItem(icon: Icons.calendar_month_rounded, label: '预订'),
    _NavItem(icon: Icons.door_back_door_rounded, label: '客房'),
    _NavItem(icon: Icons.devices_rounded, label: '设备'),
    _NavItem(icon: Icons.build_rounded, label: '工单处理'),
    _NavItem(icon: Icons.delivery_dining_rounded, label: '客房送物'),
    _NavItem(icon: Icons.phone_in_talk_rounded, label: '语音通话'),
    _NavItem(icon: Icons.thermostat_rounded, label: '环境监测'),
    _NavItem(icon: Icons.price_change_rounded, label: '房价设置'),
    _NavItem(icon: Icons.calendar_today_rounded, label: '价格日历'),
    _NavItem(icon: Icons.local_offer_rounded, label: '优惠券'),
    _NavItem(icon: Icons.receipt_long_rounded, label: '账单报表'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _navItems.length, vsync: this);
    _loadNotificationCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('智联酒店 - 前台端', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.notoSansSc(fontSize: 13, fontWeight: FontWeight.bold),
          tabAlignment: TabAlignment.start,
          tabs: _navItems.map((item) => Tab(
            icon: Icon(item.icon, size: 18),
            text: item.label,
          )).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _ReceptionHomeContent(),
          const CheckInOutPage(),
          const BookingsPage(),
          const RoomAvailabilityPage(),
          const DeviceManagementPage(),
          const WorkOrdersPage(),
          const DeliveryOrdersPage(),
          const VoiceCallsPage(),
          const EnvironmentMonitorPage(),
          const PriceSettingsPage(),
          const PriceCalendarPage(),
          const CouponManagePage(),
          const BillsPage(),
        ],
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
            _buildNotificationItem('工单处理', '有新的待处理工单', Icons.build_rounded, AppColors.warning, 5),
            _buildNotificationItem('客房送物', '有新的送物请求', Icons.delivery_dining_rounded, AppColors.info, 6),
            if (_hasEnvAlert)
              _buildNotificationItem('环境异常', '有环境异常告警', Icons.thermostat_rounded, AppColors.error, 8),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).then((_) => _loadNotificationCount());
  }

  Widget _buildNotificationItem(String title, String desc, IconData icon, Color color, int tabIndex) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        _tabController.animateTo(tabIndex);
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
  List<dynamic> _arrivals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final statsResult = await ref.read(hotelServiceProvider).getDashboardStats();
      final workOrdersResult = await ref.read(maintenanceServiceProvider).getWorkOrders(status: 'pending', pageSize: 5);
      final arrivalsResult = await ref.read(hotelServiceProvider).getTodayArrivals();

      if (mounted) {
        setState(() {
          _dashboardStats = statsResult.success ? statsResult.data : null;
          _workOrders = workOrdersResult.success ? (workOrdersResult.data ?? []) : [];
          _arrivals = arrivalsResult.success ? (arrivalsResult.data ?? []) : [];
        });
      }
    } catch (e) {
      debugPrint('鉁?dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToTab(int tabIndex) {
    final state = context.findAncestorStateOfType<_ReceptionDashboardPageState>();
    state?._tabController.animateTo(tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    final todayCheckIn = _dashboardStats?['today_checkin']?.toString() ?? '0';
    final todayCheckOut = _dashboardStats?['today_checkout']?.toString() ?? '0';
    final currentGuests = _dashboardStats?['current_guests']?.toString() ?? '0';
    final pendingTasks = _dashboardStats?['pending_tasks']?.toString() ?? '0';

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
              childAspectRatio: 1.6,
              children: [
                _QuickStatCard(title: '今日入住', value: todayCheckIn, icon: Icons.login_rounded, color: AppColors.success, onTap: () => _navigateToTab(1)),
                _QuickStatCard(title: '今日退房', value: todayCheckOut, icon: Icons.logout_rounded, color: AppColors.error, onTap: () => _navigateToTab(1)),
                _QuickStatCard(title: '在住客人', value: currentGuests, icon: Icons.people_rounded, color: AppColors.info, onTap: () => _navigateToTab(3)),
                _QuickStatCard(title: '待处理事项', value: pendingTasks, icon: Icons.pending_actions_rounded, color: AppColors.warning, onTap: () => _navigateToTab(4)),
              ],
            ),
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
                GestureDetector(onTap: () => _navigateToTab(4), child: Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12))),
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
              GestureDetector(onTap: () => _navigateToTab(2), child: Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 12))),
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
                title: Text('${b['guest_name'] ?? '-'} · ${b['room_type'] ?? '-'} · ${b['check_in_date'] ?? ''}', style: GoogleFonts.notoSansSc(fontSize: 14)),
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

class CheckInOutPage extends ConsumerStatefulWidget {
  const CheckInOutPage({super.key});
  @override
  ConsumerState<CheckInOutPage> createState() => _CheckInOutPageState();
}

class _CheckInOutPageState extends ConsumerState<CheckInOutPage> {
  List<dynamic> _todayBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(bookingServiceProvider).getBookings(pageSize: 50, checkInDate: 'today');
      if (result.success && mounted) {
        final list = (result.data?['list'] as List<dynamic>?) ?? [];
        final filtered = list.where((b) =>
          ['pending', 'confirmed', 'pre_checked_in', 'checked_in'].contains(b['status'])
        ).toList();
        setState(() => _todayBookings = filtered);
      }
    } catch (e) {
      debugPrint('✗ todayBookings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preCheckIns = _todayBookings.where((b) => b['status'] == 'pre_checked_in').toList();
    final checkIns = _todayBookings.where((b) => b['status'] == 'confirmed').toList();
    final checkOuts = _todayBookings.where((b) => b['status'] == 'checked_in').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(tabs: [
                      Tab(text: '预入住审核${preCheckIns.isNotEmpty ? '(${preCheckIns.length})' : ''}'),
                      const Tab(text: '待入住'),
                      const Tab(text: '待退房'),
                    ]),
                    Expanded(child: TabBarView(children: [
                      _buildPreCheckinList(preCheckIns),
                      _buildBookingList(checkIns, 'checkin'),
                      _buildBookingList(checkOuts, 'checkout'),
                    ])),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPreCheckinList(List<dynamic> bookings) {
    if (bookings.isEmpty) return const Center(child: Text('暂无预入住申请', style: TextStyle(color: AppColors.textSecondary)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${b['room_number'] ?? b['room_id'] ?? '-'}号房 · ${b['room_type'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Text('待审核', style: TextStyle(fontSize: 12, color: AppColors.warning))),
              ]),
              const SizedBox(height: 8),
              Text('客人：${b['guest_name'] ?? '-'}  ${b['guest_phone'] ?? ''}', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              if (b['guest_id_number'] != null) ...[
                const SizedBox(height: 4),
                Text('身份证号：${b['guest_id_number']}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handlePreCheckinReview(b, false),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('拒绝'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _handlePreCheckinReview(b, true),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      child: const Text('审核通过'),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _handlePreCheckinReview(Map<String, dynamic> booking, bool approved) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approved ? '确认通过审核' : '确认拒绝'),
        content: Text('客人：${booking['guest_name'] ?? '-'}，房间：${booking['room_number'] ?? booking['room_id'] ?? '-'}号房'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: approved ? AppColors.success : AppColors.error),
            child: Text(approved ? '确认通过' : '确认拒绝'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (approved) {
        // 审核通过，办理正式入住
        final result = await ref.read(bookingServiceProvider).checkin(booking['id']);
        if (result.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('审核通过，入住办理成功')));
          _loadData();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
        }
      } else {
        // 拒绝审核，退回为 confirmed 状态
        final result = await ref.read(bookingServiceProvider).rejectPreCheckin(booking['id']);
        if (result.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已拒绝预入住申请')));
          _loadData();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  Widget _buildBookingList(List<dynamic> bookings, String action) {
    if (bookings.isEmpty) return Center(child: Text('暂无${action == 'checkin' ? '待入住' : '待退房'}订单', style: TextStyle(color: AppColors.textSecondary)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${b['room_number'] ?? b['room_id'] ?? '-'}号房 · ${b['room_type'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: (action == 'checkin' ? AppColors.success : AppColors.warning).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(action == 'checkin' ? '待入住' : '在住', style: TextStyle(fontSize: 12, color: action == 'checkin' ? AppColors.success : AppColors.warning))),
              ]),
              const SizedBox(height: 8),
              Text('客人：${b['guest_name'] ?? '-'}  ${b['guest_phone'] ?? ''}', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 40, child: FilledButton(
                onPressed: () => _handleAction(b, action),
                style: FilledButton.styleFrom(backgroundColor: action == 'checkin' ? AppColors.success : AppColors.error),
                child: Text(action == 'checkin' ? '办理入住' : '办理退房'),
              )),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _handleAction(Map<String, dynamic> booking, String action) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(action == 'checkin' ? '确认入住' : '确认退房'),
      content: Text('客人：${booking['guest_name'] ?? '-'}，房间：${booking['room_number'] ?? booking['room_id'] ?? '-'}号房'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认'))],
    ));
    if (confirm != true) return;

    try {
      final result = action == 'checkin'
          ? await ref.read(bookingServiceProvider).checkin(booking['id'])
          : await ref.read(bookingServiceProvider).checkout(booking['id']);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'checkin' ? '入住办理成功' : '退房办理成功')));
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }
}

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});
  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(bookingServiceProvider).getBookings(status: _filterStatus == 'all' ? null : _filterStatus, pageSize: 50);
      if (result.success && mounted) setState(() => _bookings = (result.data?['list'] as List<dynamic>?) ?? []);
    } catch (e) {
      debugPrint('✗ bookings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _statusText(String? s) => switch (s) { 'pending' => '待支付', 'confirmed' => '待入住', 'pre_checked_in' => '预入住', 'checked_in' => '已入住', 'checked_out' => '已完成', 'cancelled' => '已取消', 'paid' => '已支付', _ => s ?? '未知' };
  Color _statusColor(String? s) => switch (s) { 'pending' => Colors.orange, 'confirmed' => AppColors.primary, 'pre_checked_in' => Colors.cyan, 'checked_in' => AppColors.success, 'checked_out' => AppColors.textSecondary, 'cancelled' => AppColors.error, 'paid' => AppColors.success, _ => AppColors.textHint };

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: ['all', 'pending', 'confirmed', 'pre_checked_in', 'checked_in', 'checked_out', 'cancelled'].map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(s == 'all' ? '全部' : _statusText(s)), selected: _filterStatus == s, onSelected: (_) => setState(() { _filterStatus = s; _loadBookings(); })))).toList())),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _bookings.isEmpty ? Center(child: Text('暂无预订', style: TextStyle(color: AppColors.textSecondary))) : RefreshIndicator(onRefresh: _loadBookings, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _bookings.length, itemBuilder: (context, i) {
          final b = _bookings[i];
          return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
            title: Text('${b['guest_name'] ?? '-'} · ${b['room_type'] ?? ''}'),
            subtitle: Text('${_formatDate(b['check_in_date'])} ~ ${_formatDate(b['check_out_date'])}'),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _statusColor(b['status']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(_statusText(b['status']), style: TextStyle(color: _statusColor(b['status']), fontSize: 12))),
          ));
        }))),
      ]),
    );
  }
}

class PriceSettingsPage extends ConsumerStatefulWidget {
  const PriceSettingsPage({super.key});
  @override
  ConsumerState<PriceSettingsPage> createState() => _PriceSettingsPageState();
}

class _PriceSettingsPageState extends ConsumerState<PriceSettingsPage> {
  List<dynamic> _roomTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoomTypes();
  }

  Future<void> _loadRoomTypes() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(roomTypeServiceProvider).getRoomTypes();
      if (result.success && mounted) {
        setState(() => _roomTypes = result.data ?? []);
      }
    } catch (e) {
      debugPrint('鉁?roomTypes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrice(int typeId, double newPrice) async {
    try {
      final result = await ref.read(roomTypeServiceProvider).updateRoomType(typeId, {'base_price': newPrice});
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('价格已更新'), backgroundColor: AppColors.success),
        );
        _loadRoomTypes();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '更新失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoomTypes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _roomTypes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.price_change_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('暂无房型数据', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _roomTypes.length,
                  itemBuilder: (context, i) {
                    final rt = _roomTypes[i];
                    final price = double.tryParse(rt['base_price']?.toString() ?? '0') ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rt['type_name'] ?? rt['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('${rt['bed_type'] ?? '-'} · 最多${rt['max_guests'] ?? 1}人 · ${rt['area'] ?? '-'}㎡', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('¥${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)),
                                const Text('/晚', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () => _showPriceEditor(rt, price),
                                  child: const Text('修改价格'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showPriceEditor(Map<String, dynamic> roomType, double currentPrice) {
    final controller = TextEditingController(text: currentPrice.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改${roomType['type_name'] ?? roomType['name'] ?? ''}价格'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '基础价格（元/晚）',
            prefixText: '¥',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text) ?? currentPrice;
              Navigator.pop(ctx);
              _updatePrice(roomType['id'] as int, newPrice);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
