import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/hotel_service.dart';
import '../../services/device_service.dart';
import '../../services/auth_service.dart';
import '../../services/environment_service.dart';
import '../../services/booking_service.dart';
import '../../services/room_service.dart';
import '../../services/maintenance_service.dart';

class ReceptionDashboardPage extends ConsumerStatefulWidget {
  const ReceptionDashboardPage({super.key});

  @override
  ConsumerState<ReceptionDashboardPage> createState() => _ReceptionDashboardPageState();
}

class _ReceptionDashboardPageState extends ConsumerState<ReceptionDashboardPage> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.work_rounded, label: '工作台'),
    _NavItem(icon: Icons.assignment_rounded, label: '工单'),
    _NavItem(icon: Icons.phone_in_talk_rounded, label: '通话'),
    _NavItem(icon: Icons.person_rounded, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _WorkbenchTab(),
      const _WorkOrdersTab(),
      const _CallsTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.18))),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == _selectedIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 22, color: isSelected ? AppColors.gold : AppColors.textHint),
                        const SizedBox(height: 2),
                        Text(item.label, style: TextStyle(fontSize: 10, color: isSelected ? AppColors.gold : AppColors.textHint, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _WorkbenchTab extends ConsumerStatefulWidget {
  const _WorkbenchTab();
  @override
  ConsumerState<_WorkbenchTab> createState() => _WorkbenchTabState();
}

class _WorkbenchTabState extends ConsumerState<_WorkbenchTab> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingOrders = [];
  Map<String, dynamic> _envData = {};
  String _hotelName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final hotelId = await ref.read(authServiceProvider).getCurrentHotelId();
      if (hotelId == null) { if (mounted) setState(() => _isLoading = false); return; }

      try {
        final hotelInfoRes = await ref.read(hotelServiceProvider).getHotelInfo();
        if (hotelInfoRes.success && hotelInfoRes.data != null) {
          if (mounted) setState(() => _hotelName = hotelInfoRes.data!['hotel_name'] ?? '');
        }
      } catch (_) {}

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      try {
        final checkinRes = await ref.read(bookingServiceProvider).getBookings(
          hotelId: hotelId,
          status: 'confirmed',
          checkInDate: todayStr,
          pageSize: 100,
        );
        if (checkinRes.success && checkinRes.data != null) {
          if (mounted) setState(() => _stats['today_checkins'] = checkinRes.data!.length);
        }
      } catch (_) {}

      try {
        final checkoutRes = await ref.read(bookingServiceProvider).getBookings(
          hotelId: hotelId,
          status: 'checked_in',
          pageSize: 100,
        );
        if (checkoutRes.success && checkoutRes.data != null) {
          if (mounted) setState(() => _stats['current_staying'] = checkoutRes.data!.length);
        }
      } catch (_) {}

      try {
        final pendingRes = await ref.read(bookingServiceProvider).getBookings(
          hotelId: hotelId,
          status: 'pending',
          pageSize: 100,
        );
        if (pendingRes.success && pendingRes.data != null) {
          if (mounted) setState(() => _stats['pending_count'] = pendingRes.data!.length);
        }
      } catch (_) {}

      try {
        final roomRes = await ref.read(roomServiceProvider).getRooms(
          hotelId: hotelId,
          pageSize: 200,
        );
        if (roomRes.success && roomRes.data != null) {
          final rooms = roomRes.data!;
          final available = rooms.where((r) => (r.status) == 'available').length;
          final occupied = rooms.where((r) => (r.status) == 'occupied').length;
          final cleaning = rooms.where((r) => (r.status) == 'cleaning').length;
          final maintenance = rooms.where((r) => (r.status) == 'maintenance').length;
          if (mounted) {
            setState(() {
              _stats['available_rooms'] = available;
              _stats['current_staying'] = occupied;
              _stats['cleaning_rooms'] = cleaning;
              _stats['maintenance_rooms'] = maintenance;
            });
          }
        }
      } catch (_) {}

      try {
        final maintenanceRes = await ref.read(maintenanceServiceProvider).getMaintenanceTickets(
          status: 'pending',
          pageSize: 10,
        );
        if (maintenanceRes.success && maintenanceRes.data != null) {
          if (mounted) setState(() => _pendingOrders = List<Map<String, dynamic>>.from(maintenanceRes.data!.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})));
        }
      } catch (_) {}

      try {
        final result = await ref.read(deviceServiceProvider).getDevices(hotelId: hotelId);
        if (result.success) {
          final devices = List<Map<String, dynamic>>.from(result.data ?? []);
          final sensors = devices.where((d) {
            final type = (d['device_type'] ?? '').toString().toLowerCase();
            return type.contains('sensor') || type.contains('温湿度') || type.contains('传感器');
          }).toList();
          if (sensors.isNotEmpty && mounted) {
            setState(() => _envData = {
              'temperature': sensors.first['temperature'] ?? sensors.first['data']?['temperature'] ?? '--',
              'humidity': sensors.first['humidity'] ?? sensors.first['data']?['humidity'] ?? '--',
            });
          }
        }
      } catch (_) {}

      try {
        final envResult = await ref.read(environmentServiceProvider).getEnvironmentData();
        if (envResult.success && envResult.data != null) {
          final envData = envResult.data!;
          final list = envData['list'] ?? envData['data'] ?? [];
          if (list is List && list.isNotEmpty && mounted) {
            double totalTemp = 0;
            double totalHumidity = 0;
            int tempCount = 0;
            int humidityCount = 0;
            for (final item in list) {
              final temp = item['temperature'] ?? item['avg_temperature'] ?? item['temp'];
              final humidity = item['humidity'] ?? item['avg_humidity'];
              if (temp != null) {
                totalTemp += (temp is num ? temp : double.tryParse(temp.toString()) ?? 0).toDouble();
                tempCount++;
              }
              if (humidity != null) {
                totalHumidity += (humidity is num ? humidity : double.tryParse(humidity.toString()) ?? 0).toDouble();
                humidityCount++;
              }
            }
            setState(() {
              if (tempCount > 0) {
                _envData['temperature'] = (totalTemp / tempCount).toStringAsFixed(1);
              }
              if (humidityCount > 0) {
                _envData['humidity'] = (totalHumidity / humidityCount).toStringAsFixed(0);
              }
              _envData['air_quality'] = '优';
            });
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('receptionStats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildQuickActions(),
            _buildRoomStatusGrid(),
            _buildPendingOrders(),
            _buildEnvironment(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final authState = ref.read(authStateProvider);
    final hotelName = _hotelName.isNotEmpty ? _hotelName : '我的酒店';
    final username = authState.username ?? '前台';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.only(top: 48, left: 20, right: 20, bottom: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotelName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('前台: $username', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.goldDark, AppColors.gold, AppColors.goldLight]),
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                child: Center(child: Text(username[0], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildHeaderStat('${_stats['today_checkins'] ?? 0}', '今日入住', valueColor: AppColors.gold)),
              const SizedBox(width: 8),
              Expanded(child: _buildHeaderStat('${_stats['today_checkouts'] ?? 0}', '今日退房')),
              const SizedBox(width: 8),
              Expanded(child: _buildHeaderStat('${_stats['current_staying'] ?? 0}', '当前在住')),
              const SizedBox(width: 8),
              Expanded(child: _buildHeaderStat('${_stats['pending_count'] ?? 0}', '待处理', valueColor: AppColors.warning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(icon: Icons.login_rounded, label: '办理入住', color: AppColors.success, onTap: () => context.push('/reception/checkin-out')),
      _QuickAction(icon: Icons.logout_rounded, label: '办理退房', color: AppColors.info, onTap: () => context.push('/reception/checkin-out')),
      _QuickAction(icon: Icons.vpn_key_rounded, label: '发放房卡', color: AppColors.gold, onTap: () => context.push('/reception/checkin-out')),
      _QuickAction(icon: Icons.phone_in_talk_rounded, label: '呼叫客房', color: Colors.purple, onTap: () => context.push('/reception/voice-calls')),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('快捷操作', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              Row(
                children: actions.map((action) => Expanded(
                  child: GestureDetector(
                    onTap: action.onTap,
                    child: Column(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [action.color, action.color.withValues(alpha: 0.6)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(action.icon, size: 24, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(action.label, style: const TextStyle(fontSize: 10, color: AppColors.textPrimary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomStatusGrid() {
    final total = _stats['total_rooms'] ?? 0;
    final available = _stats['available_rooms'] ?? 0;
    final occupied = _stats['current_staying'] ?? 0;
    final cleaning = _stats['cleaning_rooms'] ?? 0;
    final maintenance = _stats['maintenance_rooms'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('房态速览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              GestureDetector(
                onTap: () => context.push('/reception/room-availability'),
                child: const Text('查看详情', style: TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildRoomStatusCard('$available', '空闲', AppColors.roomAvailable, total > 0 ? available / total : 0)),
              const SizedBox(width: 8),
              Expanded(child: _buildRoomStatusCard('$occupied', '在住', AppColors.roomOccupied, total > 0 ? occupied / total : 0)),
              const SizedBox(width: 8),
              Expanded(child: _buildRoomStatusCard('$cleaning', '清洁', AppColors.roomCleaning, total > 0 ? cleaning / total : 0)),
              const SizedBox(width: 8),
              Expanded(child: _buildRoomStatusCard('$maintenance', '维修', AppColors.roomMaintenance, total > 0 ? maintenance / total : 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomStatusCard(String value, String label, Color color, double rate) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0),
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOrders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('待办工单', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              if (_pendingOrders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(8)),
                  child: Text('${_pendingOrders.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_pendingOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success.withValues(alpha: 0.5), size: 20),
                  const SizedBox(width: 8),
                  const Text('暂无待办工单', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                ],
              ),
            )
          else
            ..._pendingOrders.take(3).map((order) => _buildOrderCard(order)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final type = order['type'] ?? order['order_type'] ?? 'service';
    final isUrgent = order['priority'] == 'high' || order['urgent'] == true;
    final color = isUrgent ? AppColors.error : AppColors.warning;

    IconData typeIcon;
    switch (type.toString().toLowerCase()) {
      case 'cleaning': typeIcon = Icons.cleaning_services; break;
      case 'maintenance': typeIcon = Icons.build; break;
      case 'delivery': typeIcon = Icons.room_service; break;
      default: typeIcon = Icons.assignment;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
            child: Icon(typeIcon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order['fault_type'] ?? order['title'] ?? order['description'] ?? '工单', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                Text('${order['room_number'] ?? order['room'] ?? ''} · ${order['created_at'] ?? ''}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _handleOrderAction(order),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('处理', style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOrderAction(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('处理工单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('工单类型: ${order['fault_type'] ?? order['title'] ?? '工单'}'),
            Text('房间: ${order['room_number'] ?? order['room'] ?? '-'}'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final orderId = order['id'];
                      if (orderId != null) {
                        final result = await ref.read(maintenanceServiceProvider).updateMaintenanceStatus(
                          int.parse(orderId.toString()),
                          'completed',
                        );
                        if (result.success && mounted) {
                          setState(() {
                            _pendingOrders.removeWhere((o) => o['id'].toString() == orderId.toString());
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('工单已处理'), backgroundColor: AppColors.success),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('处理失败: ${result.message}'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('确认完成'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironment() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('环境监测', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              GestureDetector(
                onTap: () => context.push('/reception/environment'),
                child: const Text('查看详情', style: TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.thermostat, size: 28, color: AppColors.error.withValues(alpha: 0.7)),
                      const SizedBox(height: 4),
                      Text('${_envData['temperature'] ?? '--'}°C', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const Text('温度', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.divider),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.water_drop, size: 28, color: AppColors.info.withValues(alpha: 0.7)),
                      const SizedBox(height: 4),
                      Text('${_envData['humidity'] ?? '--'}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const Text('湿度', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.divider),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.air, size: 28, color: AppColors.success.withValues(alpha: 0.7)),
                      const SizedBox(height: 4),
                      Text('${_envData['air_quality'] ?? '--'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const Text('空气质量', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
}

class _WorkOrdersTab extends ConsumerStatefulWidget {
  const _WorkOrdersTab();
  @override
  ConsumerState<_WorkOrdersTab> createState() => _WorkOrdersTabState();
}

class _WorkOrdersTabState extends ConsumerState<_WorkOrdersTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final hotelId = await ref.read(authServiceProvider).getCurrentHotelId();
      if (hotelId == null) { if (mounted) setState(() => _isLoading = false); return; }

      final result = await ref.read(maintenanceServiceProvider).getMaintenanceTickets(
        status: _statusFilter,
        pageSize: 100,
      );
      if (result.success && result.data != null) {
        if (mounted) setState(() => _orders = List<Map<String, dynamic>>.from(result.data!.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})));
      }
    } catch (e) {
      debugPrint('workOrders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('工单管理'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _FilterChip(label: '全部', isSelected: _statusFilter == null, onTap: () { setState(() => _statusFilter = null); _loadOrders(); }),
            const SizedBox(width: 6),
            _FilterChip(label: '待处理', isSelected: _statusFilter == 'pending', onTap: () { setState(() => _statusFilter = 'pending'); _loadOrders(); }),
            const SizedBox(width: 6),
            _FilterChip(label: '处理中', isSelected: _statusFilter == 'processing', onTap: () { setState(() => _statusFilter = 'processing'); _loadOrders(); }),
            const SizedBox(width: 6),
            _FilterChip(label: '已完成', isSelected: _statusFilter == 'completed', onTap: () { setState(() => _statusFilter = 'completed'); _loadOrders(); }),
          ])),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: _orders.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), const Text('暂无工单', style: TextStyle(color: AppColors.textHint))]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (ctx, i) {
                            final o = _orders[i];
                            final status = o['status'] ?? 'pending';
                            Color statusColor;
                            switch (status) {
                              case 'completed': statusColor = AppColors.success; break;
                              case 'processing': statusColor = AppColors.info; break;
                              case 'pending': statusColor = AppColors.warning; break;
                              default: statusColor = AppColors.textHint;
                            }
                            return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.assignment, color: statusColor, size: 20)),
                              title: Text(o['title'] ?? o['description'] ?? '工单${o['id']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('${o['room_number'] ?? ''} | ${o['type'] ?? ''}'),
                              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))),
                              onTap: () => context.push('/reception/work-orders'),
                            ));
                          },
                        ),
              ),
        ),
      ]),
    );
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
        decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider)),
        child: Text(label, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _CallsTab extends ConsumerStatefulWidget {
  const _CallsTab();
  @override
  ConsumerState<_CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends ConsumerState<_CallsTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('语音通话'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.phone_in_talk, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text('语音通话功能', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('点击下方按钮进入通话管理', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/reception/voice-calls'),
              icon: const Icon(Icons.phone),
              label: const Text('进入通话管理'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab();
  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.read(authStateProvider);
    final username = authState.username ?? '前台';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('我的'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.goldDark, AppColors.gold, AppColors.goldLight]),
                      borderRadius: BorderRadius.all(Radius.circular(28)),
                    ),
                    child: Center(child: Text(username[0], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('前台员工', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _menuCard(Icons.login, '入住/退房管理', () => context.push('/reception/checkin-out')),
            _menuCard(Icons.book_online, '预订管理', () => context.push('/reception/bookings')),
            _menuCard(Icons.meeting_room, '房态查看', () => context.push('/reception/room-availability')),
            _menuCard(Icons.devices, '设备管理', () => context.push('/reception/devices')),
            _menuCard(Icons.receipt_long, '账单管理', () => context.push('/reception/bills')),
            _menuCard(Icons.local_offer, '价格设置', () => context.push('/reception/price-settings')),
            _menuCard(Icons.calendar_month, '价格日历', () => context.push('/reception/price-calendar')),
            _menuCard(Icons.local_offer_outlined, '优惠券管理', () => context.push('/reception/coupons')),
            _menuCard(Icons.thermostat, '环境监测', () => context.push('/reception/environment')),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('退出登录', style: TextStyle(color: AppColors.error)),
                onTap: () => ref.read(authStateProvider.notifier).clearAuth(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(IconData icon, String label, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: onTap,
      ),
    );
  }
}
