import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/hotel_service.dart';
import '../../services/maintenance_service.dart';
import '../../services/booking_service.dart';
import '../../services/room_service.dart';
import '../../services/delivery_service.dart';
import '../../services/payment_service.dart';
import '../../services/voice_call_service.dart';
import '../../services/room_type_service.dart';

class ReceptionDashboardPage extends ConsumerStatefulWidget {
  const ReceptionDashboardPage({super.key});

  @override
  ConsumerState<ReceptionDashboardPage> createState() => _ReceptionDashboardPageState();
}

class _ReceptionDashboardPageState extends ConsumerState<ReceptionDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _notificationCount = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: '总览'),
    _NavItem(icon: Icons.how_to_reg_rounded, label: '入住退房'),
    _NavItem(icon: Icons.calendar_month_rounded, label: '预订'),
    _NavItem(icon: Icons.door_back_door_rounded, label: '客房'),
    _NavItem(icon: Icons.build_rounded, label: '工单处理'),
    _NavItem(icon: Icons.delivery_dining_rounded, label: '客房送物'),
    _NavItem(icon: Icons.phone_in_talk_rounded, label: '语音通话'),
    _NavItem(icon: Icons.price_change_rounded, label: '房价设置'),
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
      if (mounted) setState(() => _notificationCount = count);
    } catch (e) {
      debugPrint('Error loading notifications: $e');
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
              }
            },
            itemBuilder: (context) => [
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
          const WorkOrdersPage(),
          const DeliveryOrdersPage(),
          const VoiceCallsPage(),
          const PriceSettingsPage(),
          const BillsPage(),
        ],
      ),
    );
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
            _buildNotificationItem('工单处理', '有新的待处理工单', Icons.build_rounded, AppColors.warning, 4),
            _buildNotificationItem('客房送物', '有新的送物请求', Icons.delivery_dining_rounded, AppColors.info, 5),
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
      debugPrint('Error loading dashboard: $e');
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
      final result = await ref.read(bookingServiceProvider).getBookings(pageSize: 50);
      if (result.success && mounted) {
        final list = (result.data?['list'] as List<dynamic>?) ?? [];
        setState(() => _todayBookings = list);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkIns = _todayBookings.where((b) => b['status'] == 'confirmed').toList();
    final checkOuts = _todayBookings.where((b) => b['status'] == 'checked_in').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('入住退房')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(tabs: [Tab(text: '待入住'), Tab(text: '待退房')]),
                    Expanded(child: TabBarView(children: [
                      _buildBookingList(checkIns, 'checkin'),
                      _buildBookingList(checkOuts, 'checkout'),
                    ])),
                  ],
                ),
              ),
            ),
    );
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
      actions: [TextButton(onPressed: () => ctx.pop(false), child: const Text('取消')), FilledButton(onPressed: () => ctx.pop(true), child: const Text('确认'))],
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
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
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _statusText(String? s) => switch (s) { 'pending' => '待支付', 'confirmed' => '待入住', 'checked_in' => '已入住', 'checked_out' => '已完成', 'cancelled' => '已取消', 'paid' => '已支付', _ => s ?? '未知' };
  Color _statusColor(String? s) => switch (s) { 'pending' => Colors.orange, 'confirmed' => AppColors.primary, 'checked_in' => AppColors.success, 'checked_out' => AppColors.textSecondary, 'cancelled' => AppColors.error, 'paid' => AppColors.success, _ => AppColors.textHint };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('预订管理')),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: ['all', 'pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled'].map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(s == 'all' ? '全部' : _statusText(s)), selected: _filterStatus == s, onSelected: (_) => setState(() { _filterStatus = s; _loadBookings(); })))).toList())),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _bookings.isEmpty ? Center(child: Text('暂无预订', style: TextStyle(color: AppColors.textSecondary))) : RefreshIndicator(onRefresh: _loadBookings, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _bookings.length, itemBuilder: (context, i) {
          final b = _bookings[i];
          return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
            title: Text('${b['guest_name'] ?? '-'} · ${b['room_type'] ?? ''}'),
            subtitle: Text('${b['check_in_date'] ?? ''} ~ ${b['check_out_date'] ?? ''}'),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _statusColor(b['status']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(_statusText(b['status']), style: TextStyle(color: _statusColor(b['status']), fontSize: 12))),
          ));
        }))),
      ]),
    );
  }
}

class RoomAvailabilityPage extends ConsumerStatefulWidget {
  const RoomAvailabilityPage({super.key});
  @override
  ConsumerState<RoomAvailabilityPage> createState() => _RoomAvailabilityPageState();
}

class _RoomAvailabilityPageState extends ConsumerState<RoomAvailabilityPage> {
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(roomServiceProvider).getRooms(status: _filterStatus == 'all' ? null : _filterStatus);
      if (result.success && mounted) setState(() => _rooms = result.data ?? []);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String s) => switch (s) { 'available' => AppColors.roomAvailable, 'occupied' => AppColors.roomOccupied, 'cleaning' => AppColors.roomCleaning, 'maintenance' => AppColors.roomMaintenance, 'reserved' => Colors.orange, _ => AppColors.textHint };
  String _statusText(String s) => switch (s) { 'available' => '空闲', 'occupied' => '已住', 'cleaning' => '清洁中', 'maintenance' => '维修中', 'reserved' => '已预订', _ => s };

  List<dynamic> get _filteredRooms {
    if (_searchQuery.isEmpty) return _rooms;
    return _rooms.where((r) {
      final roomNum = (r['room_number'] ?? r['id']?.toString() ?? '').toString().toLowerCase();
      return roomNum.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRooms;
    return Scaffold(
      appBar: AppBar(title: const Text('客房管理')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索房间号...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: ['all', 'available', 'occupied', 'reserved', 'cleaning', 'maintenance'].map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(s == 'all' ? '全部' : _statusText(s)), selected: _filterStatus == s, onSelected: (_) => setState(() { _filterStatus = s; _loadRooms(); })))).toList())),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : filtered.isEmpty ? Center(child: Text('暂无房间', style: TextStyle(color: AppColors.textSecondary))) : RefreshIndicator(onRefresh: _loadRooms, child: GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.0), itemCount: filtered.length, itemBuilder: (context, i) {
          final r = filtered[i];
          final status = r['room_status']?.toString() ?? r['status']?.toString() ?? 'available';
          return GestureDetector(
            onTap: () => _showRoomDetail(r),
            child: Card(
              color: _statusColor(status).withValues(alpha: 0.05),
              child: Padding(padding: const EdgeInsets.all(8), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${r['room_number'] ?? r['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text(r['room_type'] ?? r['room_type_name'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: Text(_statusText(status), style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.bold))),
                if (status == 'reserved' || status == 'occupied') ...[
                  const SizedBox(height: 4),
                  Text('不可分配', style: TextStyle(fontSize: 9, color: AppColors.error)),
                ],
              ])),
            ),
          );
        }))),
      ]),
    );
  }

  void _showRoomDetail(Map<String, dynamic> room) {
    final status = room['room_status']?.toString() ?? room['status']?.toString() ?? 'available';
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
            Text('${room['room_number'] ?? room['id']}号房', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('房型：${room['room_type'] ?? room['room_type_name'] ?? '-'}', style: const TextStyle(color: AppColors.textSecondary)),
            Text('楼层：${room['floor'] ?? '-'}楼', style: const TextStyle(color: AppColors.textSecondary)),
            Text('当前状态：${_statusText(status)}', style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('修改房间状态', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['available', 'occupied', 'reserved', 'cleaning', 'maintenance'].map((s) => ChoiceChip(
                label: Text(_statusText(s)),
                selected: status == s,
                onSelected: status == s ? null : (_) => _updateRoomStatus(room, s),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _updateRoomStatus(Map<String, dynamic> room, String newStatus) async {
    final roomId = room['id'] as int?;
    if (roomId == null) return;

    final currentStatus = room['room_status']?.toString() ?? room['status']?.toString() ?? 'available';
    if ((currentStatus == 'reserved' || currentStatus == 'occupied') && newStatus == 'available') {
      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('确认释放房间'),
        content: Text('${room['room_number'] ?? roomId}号房当前状态为${_statusText(currentStatus)}，确定要释放为空闲吗？'),
        actions: [TextButton(onPressed: () => ctx.pop(false), child: const Text('取消')), FilledButton(onPressed: () => ctx.pop(true), child: const Text('确认释放'))],
      ));
      if (confirm != true) return;
    }

    try {
      final result = await ref.read(roomServiceProvider).updateRoom(roomId, {'room_status': newStatus});
      if (result.success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('房间状态已更新')));
        _loadRooms();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '更新失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }
}

class WorkOrdersPage extends ConsumerStatefulWidget {
  const WorkOrdersPage({super.key});
  @override
  ConsumerState<WorkOrdersPage> createState() => _WorkOrdersPageState();
}

class _WorkOrdersPageState extends ConsumerState<WorkOrdersPage> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(maintenanceServiceProvider).getWorkOrders(pageSize: 50);
      if (result.success && mounted) setState(() => _orders = result.data ?? []);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工单处理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(child: Text('暂无工单', style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(onRefresh: _loadOrders, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _orders.length, itemBuilder: (context, i) {
                  final o = _orders[i];
                  final isUrgent = o['is_urgent'] == true || o['priority'] == 'high';
                  return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [Text('${o['room_number'] ?? o['room_id'] ?? '-'}号房', style: const TextStyle(fontWeight: FontWeight.bold)), if (isUrgent) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(4)), child: const Text('加急', style: TextStyle(color: Colors.white, fontSize: 9)))]],),
                      Text(o['type'] ?? '其他', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),
                    Text(o['description'] ?? '', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 12),
                    if (o['status'] == 'pending') Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => _updateStatus(o['id'], 'in_progress'), child: const Text('接单'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton(onPressed: () => _updateStatus(o['id'], 'completed'), child: const Text('完成'))),
                    ]),
                    if (o['status'] == 'in_progress') SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _updateStatus(o['id'], 'completed'), child: const Text('标记完成'))),
                  ])));
                })),
    );
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      final result = await ref.read(maintenanceServiceProvider).updateWorkOrderStatus(id, status);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('状态更新成功')));
        _loadOrders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }
}

class DeliveryOrdersPage extends ConsumerStatefulWidget {
  const DeliveryOrdersPage({super.key});
  @override
  ConsumerState<DeliveryOrdersPage> createState() => _DeliveryOrdersPageState();
}

class _DeliveryOrdersPageState extends ConsumerState<DeliveryOrdersPage> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(deliveryServiceProvider).getDeliveryOrders(pageSize: 50);
      if (result.success && mounted) setState(() => _orders = result.data ?? []);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? s) => switch (s) { 'pending' => Colors.orange, 'delivering' => AppColors.primary, 'delivered' => AppColors.success, _ => AppColors.textHint };
  String _statusText(String? s) => switch (s) { 'pending' => '待配送', 'delivering' => '配送中', 'delivered' => '已送达', _ => s ?? '未知' };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('客房送物')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(child: Text('暂无送物订单', style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(onRefresh: _loadOrders, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _orders.length, itemBuilder: (context, i) {
                  final o = _orders[i];
                  return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
                    title: Text('${o['room_number'] ?? o['room_id'] ?? '-'}号房 · ${o['item_name'] ?? o['items'] ?? '送物品'}'),
                    subtitle: Text('${o['guest_name'] ?? ''} · ${o['note'] ?? ''}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _statusColor(o['status']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(_statusText(o['status']), style: TextStyle(color: _statusColor(o['status']), fontSize: 11))),
                      if (o['status'] == 'pending') TextButton(onPressed: () => _updateStatus(o['id'], 'delivering'), child: const Text('接单', style: TextStyle(fontSize: 12))),
                      if (o['status'] == 'delivering') TextButton(onPressed: () => _updateStatus(o['id'], 'delivered'), child: const Text('送达', style: TextStyle(fontSize: 12))),
                    ]),
                  ));
                })),
    );
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      final result = await ref.read(deliveryServiceProvider).updateDeliveryStatus(id, status);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('状态更新成功')));
        _loadOrders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }
}

class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key});
  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> {
  List<dynamic> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(paymentServiceProvider).getPaymentHistory(pageSize: 50);
      if (result.success && mounted) setState(() => _payments = result.data ?? []);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? s) => switch (s) { 'paid' => AppColors.success, 'pending' => Colors.orange, 'refunded' => AppColors.textSecondary, _ => AppColors.textHint };
  String _statusText(String? s) => switch (s) { 'paid' => '已支付', 'pending' => '待支付', 'refunded' => '已退款', _ => s ?? '未知' };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账单报表')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? Center(child: Text('暂无账单记录', style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(onRefresh: _loadPayments, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _payments.length, itemBuilder: (context, i) {
                  final p = _payments[i];
                  return GestureDetector(
                    onTap: () => _showPaymentDetail(p),
                    child: Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
                    leading: CircleAvatar(backgroundColor: _statusColor(p['status']).withValues(alpha: 0.1), child: Icon(Icons.receipt_long, color: _statusColor(p['status']), size: 20)),
                    title: Text('${p['guest_name'] ?? '客人'} · ${p['room_number'] ?? ''}号房'),
                    subtitle: Text('${p['created_at'] ?? ''} · ${p['payment_method'] ?? ''}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('¥${p['amount'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_statusText(p['status']), style: TextStyle(color: _statusColor(p['status']), fontSize: 11)),
                    ]),
                  )),
                  );
                })),
    );
  }

  void _showPaymentDetail(Map<String, dynamic> payment) {
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
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('账单详情', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _statusColor(payment['status']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(_statusText(payment['status']), style: TextStyle(color: _statusColor(payment['status']), fontSize: 12))),
            ]),
            const Divider(height: 24),
            _buildDetailRow('客人姓名', '${payment['guest_name'] ?? '-'}'),
            _buildDetailRow('房间号', '${payment['room_number'] ?? '-'}'),
            _buildDetailRow('金额', '¥${payment['amount'] ?? '0'}'),
            _buildDetailRow('支付方式', '${payment['payment_method'] ?? '-'}'),
            _buildDetailRow('订单类型', '${payment['order_type'] ?? '-'}'),
            _buildDetailRow('交易号', '${payment['transaction_no'] ?? '-'}'),
            _buildDetailRow('创建时间', '${payment['created_at'] ?? '-'}'),
            if (payment['paid_at'] != null) _buildDetailRow('支付时间', '${payment['paid_at']}'),
            if (payment['note'] != null || payment['remark'] != null) _buildDetailRow('备注', '${payment['note'] ?? payment['remark'] ?? '-'}'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class VoiceCallsPage extends ConsumerStatefulWidget {
  const VoiceCallsPage({super.key});
  @override
  ConsumerState<VoiceCallsPage> createState() => _VoiceCallsPageState();
}

class _VoiceCallsPageState extends ConsumerState<VoiceCallsPage> {
  List<dynamic> _callHistory = [];
  bool _isLoading = true;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
  }

  Future<void> _loadCallHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await DioClient().get('${ApiConstants.calls}history');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (mounted) {
          setState(() {
            _callHistory = data is List ? data : [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading call history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makeCall(String targetType, String targetId) async {
    try {
      final callService = VoiceCallService();
      callService.init('reception_${DateTime.now().millisecondsSinceEpoch}');
      callService.startCall(targetId, targetType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在呼叫 $targetId...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('呼叫失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('通话状态', style: TextStyle(fontWeight: FontWeight.bold)),
                Switch(
                  value: _isOnline,
                  onChanged: (v) => setState(() => _isOnline = v),
                  activeColor: AppColors.success,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildQuickCallCard('前台', 'front_desk', Icons.support_agent_rounded, AppColors.primary),
                const SizedBox(width: 8),
                _buildQuickCallCard('101房', '101', Icons.door_back_door_rounded, AppColors.secondary),
                const SizedBox(width: 8),
                _buildQuickCallCard('201房', '201', Icons.door_back_door_rounded, AppColors.info),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('通话记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${_callHistory.length}条记录', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _callHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_disabled_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            const Text('暂无通话记录', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _callHistory.length,
                        itemBuilder: (context, i) {
                          final call = _callHistory[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Icon(
                                call['direction'] == 'outbound' ? Icons.call_made_rounded : Icons.call_received_rounded,
                                color: call['direction'] == 'outbound' ? AppColors.success : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text('${call['target_name'] ?? call['target_id'] ?? '-'}'),
                            subtitle: Text('${call['started_at'] ?? ''} · ${call['duration'] ?? '0'}秒'),
                            trailing: Text(
                              call['status'] == 'completed' ? '已完成' : call['status'] == 'missed' ? '未接听' : '已取消',
                              style: TextStyle(
                                color: call['status'] == 'missed' ? AppColors.error : AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCallCard(String name, String targetId, IconData icon, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _makeCall('room', targetId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
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
      debugPrint('Error loading room types: $e');
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
          SnackBar(content: Text('更新失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          TextButton(onPressed: () => ctx.pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text) ?? currentPrice;
              ctx.pop();
              _updatePrice(roomType['id'] as int, newPrice);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
