import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/hotel_service.dart';
import '../../services/user_service.dart';
import '../../services/device_service.dart';
import '../../services/mqtt_service.dart' as mqtt_api;
import '../../services/system_config_service.dart';
import '../../core/logic/member_logic.dart';
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
    _NavItem(icon: Icons.dashboard_rounded, label: '总览'),
    _NavItem(icon: Icons.hotel_rounded, label: '酒店'),
    _NavItem(icon: Icons.devices_rounded, label: '设备'),
    _NavItem(icon: Icons.settings_rounded, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _OverviewTab(),
      const _HotelsTab(),
      const _DevicesTab(),
      const SystemSettingsPage(),
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

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();
  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _revenueStats = {};
  List<Hotel> _topHotels = [];
  Map<int, Map<String, dynamic>> _hotelDetails = {};
  List<Map<String, dynamic>> _pendingApps = [];
  List<Map<String, dynamic>> _recentLogs = [];
  List<dynamic> _users = [];
  Map<String, dynamic> _systemStatus = {};
  List<Map<String, dynamic>> _membershipTiers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final statsRes = await ref.read(hotelServiceProvider).getGlobalStatistics();

      if (statsRes.success && statsRes.data != null) {
        final data = statsRes.data!;
        if (mounted) {
          setState(() {
            _stats = {
              'hotels': data['hotel_count'] ?? 0,
              'users': data['member_count'] ?? 0,
              'devices': data['device_count'] ?? 0,
              'online_devices': data['online_devices'] ?? data['device_count'] ?? 0,
              'pending_bookings': _extractBookingCount(data['booking_stats'], 'pending'),
              'confirmed_bookings': _extractBookingCount(data['booking_stats'], 'confirmed'),
              'checked_in_bookings': _extractBookingCount(data['booking_stats'], 'checked_in'),
            };

            double parseRevenue(dynamic value) {
              if (value == null) return 0;
              if (value is double) return value;
              if (value is int) return value.toDouble();
              if (value is String) return double.tryParse(value) ?? 0;
              return 0;
            }

            _revenueStats = {
              'today_revenue': parseRevenue(data['today_revenue'] ?? data['daily_revenue']),
              'month_revenue': parseRevenue(data['month_revenue'] ?? data['monthly_revenue_total']),
            };

            final topHotelsData = data['top_hotels'] as List?;
            _topHotels = topHotelsData?.map((h) => Hotel(
              id: h['id'] ?? 0,
              hotelName: h['hotel_name'] ?? '未知酒店',
              hotelAddress: '',
              hotelPhone: '',
              description: '',
              rating: 5.0,
            )).toList() ?? [];
          });
        }
      }

      // 加载每个酒店的详细数据
      await _loadHotelDetails();

      try {
        final dio = DioClient();
        final res = await dio.get(ApiConstants.authRoleApplications);
        if (res.statusCode == 200 && res.data['code'] == 200) {
          final apps = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
          if (mounted) setState(() => _pendingApps = apps.where((a) => a['status'] == 'pending').toList());
        }
      } catch (_) {}

      try {
        final userResult = await ref.read(userServiceProvider).getUsers(pageSize: 100);
        if (userResult.success && mounted) {
          setState(() => _users = userResult.data ?? []);
        }
      } catch (_) {}

      _loadRecentLogs();

      try {
        final mqttRes = await ref.read(mqtt_api.mqttServiceProvider).getStatus();
        if (mqttRes.success && mqttRes.data != null) {
          if (mounted) setState(() => _systemStatus['mqtt'] = mqttRes.data);
        }
      } catch (_) {}

      try {
        final healthRes = await DioClient().get(ApiConstants.health);
        if (healthRes.statusCode == 200) {
          if (mounted) setState(() => _systemStatus['health'] = healthRes.data);
        }
      } catch (_) {}

      try {
        final allConfigsRes = await ref.read(systemConfigServiceProvider).getAllConfigs();
        if (allConfigsRes.success && allConfigsRes.data != null) {
          final configs = allConfigsRes.data!;
          final tiers = configs['member_scheme']?['tiers'];
          if (tiers is List) {
            if (mounted) setState(() => _membershipTiers = List<Map<String, dynamic>>.from(tiers));
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('systemStats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHotelDetails() async {
    for (final hotel in _topHotels) {
      try {
        final dio = DioClient();
        // 获取酒店报表数据
        final reportsRes = await dio.get('${ApiConstants.hotel}/reports', queryParameters: {'hotel_id': hotel.id});
        if (reportsRes.statusCode == 200 && reportsRes.data['code'] == 200) {
          final reportsData = reportsRes.data['data'] ?? {};
          // 获取设备数据
          final devicesRes = await dio.get(ApiConstants.devices, queryParameters: {'hotel_id': hotel.id});
          int onlineDevices = 0;
          int totalDevices = 0;
          if (devicesRes.statusCode == 200 && devicesRes.data['code'] == 200) {
            final deviceData = devicesRes.data['data'];
            final devices = deviceData is List ? List<Map<String, dynamic>>.from(deviceData) : List<Map<String, dynamic>>.from(deviceData['list'] ?? []);
            totalDevices = devices.length;
            onlineDevices = devices.where((d) {
              final status = (d['device_status'] ?? d['status'] ?? '').toString().toLowerCase();
              return status == 'online' || status == 'active' || status == 'normal' || status == '运行中';
            }).length;
          }
          if (mounted) {
            setState(() {
              _hotelDetails[hotel.id] = {
                'today_revenue': reportsData['today_revenue'] ?? reportsData['daily_revenue'] ?? 0,
                'occupied_rooms': reportsData['occupied_rooms'] ?? 0,
                'online_devices': onlineDevices,
                'total_devices': totalDevices,
              };
            });
          }
        }
      } catch (e) {
        debugPrint('loadHotelDetails ${hotel.id}: $e');
      }
    }
  }

  Future<void> _loadRecentLogs() async {
    try {
      final dio = DioClient();
      final res = await dio.get('${ApiConstants.baseUrl}system/logs', queryParameters: {'limit': 5});
      if (res.statusCode == 200 && res.data['code'] == 200) {
        if (mounted) setState(() => _recentLogs = List<Map<String, dynamic>>.from(res.data['data'] ?? []));
      }
    } catch (_) {
      if (mounted) setState(() => _recentLogs = []);
    }
  }

  int _extractBookingCount(dynamic bookingStats, String status) {
    if (bookingStats == null) return 0;
    if (bookingStats is List) {
      final found = bookingStats.firstWhere(
        (b) => b is Map && b['status'] == status,
        orElse: () => {'count': 0},
      );
      return (found is Map) ? (found['count'] as num?)?.toInt() ?? 0 : 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final todayRevenue = double.tryParse(_revenueStats['today_revenue']?.toString() ?? '0') ?? 0;
    final totalDevices = _stats['devices'] ?? 0;
    final onlineDevices = _stats['online_devices'] ?? 0;
    final onlineRate = totalDevices > 0 ? (onlineDevices / totalDevices * 100) : 0.0;

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(todayRevenue, onlineRate),
            _buildSystemStatus(),
            _buildManagementGrid(),
            _buildHotelOverview(),
            _buildPendingSection(),
            _buildAccountOverview(),
            _buildSystemLogs(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double todayRevenue, double onlineRate) {
    final authState = ref.read(authStateProvider);
    final username = authState.username ?? '系统管理员';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.royalGradientStart, AppColors.royalGradientEnd],
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
                  Text('慧宿智联 · 集团管理', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(username, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showNotifications(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
                      child: Stack(
                        children: [
                          const Center(child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 18)),
                          if (_pendingApps.isNotEmpty)
                            Positioned(top: 4, right: 4, child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                              child: Text('${_pendingApps.length}', style: const TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center),
                            )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildHeaderStat('${_stats['hotels'] ?? 0}', '酒店总数', shine: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildHeaderStat('¥${_formatRevenue(todayRevenue)}', '今日总营收')),
              const SizedBox(width: 8),
              Expanded(child: _buildHeaderStat('${onlineRate.toStringAsFixed(1)}%', '设备在线率', valueColor: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label, {bool shine = false, Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9)),
        ],
      ),
    );
  }

  String _formatRevenue(double value) {
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  Widget _buildSystemStatus() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('系统状态', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: _systemStatus['health'] != null ? AppColors.success : AppColors.warning, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(_systemStatus['health'] != null ? '运行正常' : '检测中...', style: TextStyle(fontSize: 10, color: _systemStatus['health'] != null ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatusItem(Icons.compare_arrows_rounded, 'MQTT', _systemStatus['mqtt']?['connected'] == true ? '在线' : (_systemStatus['mqtt'] != null ? '离线' : '检测中'), _systemStatus['mqtt']?['connected'] == true ? AppColors.success : AppColors.warning)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatusItem(Icons.storage_rounded, '数据库', _systemStatus['health']?['database'] == 'ok' ? '正常' : (_systemStatus['health'] != null ? '异常' : '检测中'), _systemStatus['health']?['database'] == 'ok' ? AppColors.success : AppColors.warning)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatusItem(Icons.security_rounded, '安全', _systemStatus['health'] != null ? '正常' : '检测中', _systemStatus['health'] != null ? AppColors.success : AppColors.textHint)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String title, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          Text(status, style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildManagementGrid() {
    final items = [
      _GridItem(icon: Icons.hotel_rounded, label: '酒店维护', color: AppColors.info, bgColor: AppColors.info.withValues(alpha: 0.05), borderColor: AppColors.info.withValues(alpha: 0.1), onTap: () {
        final state = context.findAncestorStateOfType<_SystemDashboardPageState>();
        state?.setState(() => state._selectedIndex = 1);
      }),
      _GridItem(icon: Icons.people_rounded, label: '账户管理', color: Colors.purple, bgColor: Colors.purple.withValues(alpha: 0.05), borderColor: Colors.purple.withValues(alpha: 0.1), onTap: () => _showUsersDialog()),
      _GridItem(icon: Icons.devices_rounded, label: '全局设备', color: Colors.cyan, bgColor: Colors.cyan.withValues(alpha: 0.05), borderColor: Colors.cyan.withValues(alpha: 0.1), onTap: () {
        final state = context.findAncestorStateOfType<_SystemDashboardPageState>();
        state?.setState(() => state._selectedIndex = 2);
      }),
      _GridItem(icon: Icons.wifi_tethering_rounded, label: 'MQTT服务', color: Colors.amber, bgColor: Colors.amber.withValues(alpha: 0.05), borderColor: Colors.amber.withValues(alpha: 0.1), onTap: () => context.push('/system/mqtt')),
      _GridItem(icon: Icons.local_offer_rounded, label: '优惠券', color: Colors.pink, bgColor: Colors.pink.withValues(alpha: 0.05), borderColor: Colors.pink.withValues(alpha: 0.1), onTap: () => context.push('/admin/coupons')),
      _GridItem(icon: Icons.star_rounded, label: '会员方案', color: Colors.indigo, bgColor: Colors.indigo.withValues(alpha: 0.05), borderColor: Colors.indigo.withValues(alpha: 0.1), onTap: () => _showMembershipDialog()),
      _GridItem(icon: Icons.description_rounded, label: '系统日志', color: Colors.grey, bgColor: Colors.grey.withValues(alpha: 0.05), borderColor: Colors.grey.withValues(alpha: 0.1), onTap: () => _showSystemLogsDialog()),
      _GridItem(icon: Icons.settings_rounded, label: '系统设置', color: Colors.teal, bgColor: Colors.teal.withValues(alpha: 0.05), borderColor: Colors.teal.withValues(alpha: 0.1), onTap: () {
        final state = context.findAncestorStateOfType<_SystemDashboardPageState>();
        state?.setState(() => state._selectedIndex = 3);
      }),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('管理功能', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: items.map((item) => GestureDetector(
              onTap: item.onTap,
              child: Column(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: item.bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: item.borderColor)),
                    child: Icon(item.icon, size: 24, color: item.color),
                  ),
                  const SizedBox(height: 6),
                  Text(item.label, style: const TextStyle(fontSize: 10, color: AppColors.textPrimary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelOverview() {
    if (_topHotels.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('门店概览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              GestureDetector(
                onTap: () {
                  final state = context.findAncestorStateOfType<_SystemDashboardPageState>();
                  state?.setState(() => state._selectedIndex = 1);
                },
                child: const Text('查看全部', style: TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._topHotels.take(3).map((hotel) => _buildHotelCard(hotel)),
        ],
      ),
    );
  }

  Widget _buildHotelCard(Hotel hotel) {
    final gradients = [
      [AppColors.primary, AppColors.primaryLight],
      [AppColors.midnightGradientStart, AppColors.midnightGradientEnd],
      [AppColors.royalGradientStart, AppColors.royalGradientEnd],
    ];
    final idx = _topHotels.indexOf(hotel) % gradients.length;
    
    // 获取酒店详细数据
    final details = _hotelDetails[hotel.id];
    final todayRevenue = details?['today_revenue'] ?? 0;
    final onlineDevices = details?['online_devices'] ?? 0;
    final totalDevices = details?['total_devices'] ?? 0;
    final occupiedRooms = details?['occupied_rooms'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradients[idx], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.goldDark, AppColors.gold, AppColors.goldLight]),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Center(child: Text(hotel.hotelName[0], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hotel.hotelName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('${hotel.effectiveStar}星级', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('运营中', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _buildHotelStat('${hotel.effectiveStar}', '星级', AppColors.gold)),
                Expanded(child: _buildHotelStat(_formatRevenueShort(todayRevenue), '今日营收', AppColors.primary)),
                Expanded(child: _buildHotelStat('$onlineDevices/$totalDevices', '设备在线', AppColors.success)),
                Expanded(child: _buildHotelStat('$occupiedRooms', '在住', AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatRevenueShort(dynamic value) {
    if (value == null) return '¥0';
    final number = value is num ? value : (double.tryParse(value.toString()) ?? 0);
    if (number >= 10000) return '¥${(number / 10000).toStringAsFixed(1)}w';
    if (number >= 1000) return '¥${(number / 1000).toStringAsFixed(1)}k';
    return '¥${number.toStringAsFixed(0)}';
  }

  Widget _buildHotelStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildPendingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('待审核', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              if (_pendingApps.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(8)),
                  child: Text('${_pendingApps.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_pendingApps.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
              child: const Center(child: Text('暂无待审核', style: TextStyle(color: AppColors.textHint, fontSize: 12))),
            )
          else
            ..._pendingApps.take(3).map((app) => _buildPendingCard(app)),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> app) {
    final isCreateHotel = app['application_type'] == 'create_hotel';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: (isCreateHotel ? AppColors.info : Colors.purple).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
            child: Icon(isCreateHotel ? Icons.add_business_rounded : Icons.badge_rounded, size: 16, color: isCreateHotel ? AppColors.info : Colors.purple),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${app['username'] ?? '-'} · ${isCreateHotel ? '申请创建新酒店' : '申请酒店管理员'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                Text('${app['target_hotel_name'] ?? app['hotel_name'] ?? ''} · ${_formatTimeAgo(app['created_at'])}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _reviewApplication(app['id'], 'approved'),
                child: Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.check, size: 14, color: AppColors.success)),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _reviewApplication(app['id'], 'rejected'),
                child: Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close, size: 14, color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(dynamic time) {
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

  Future<void> _reviewApplication(int id, String status) async {
    try {
      final dio = DioClient();
      final res = await dio.put('${ApiConstants.authRoleApplications}/$id/review', data: {'status': status});
      if (res.statusCode == 200 && res.data['code'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'approved' ? '已通过' : '已拒绝'), backgroundColor: AppColors.success));
          _loadStats();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败')));
    }
  }

  Widget _buildAccountOverview() {
    final sysAdmins = _users.where((u) => u['role'] == 'system_admin').length;
    final hotelAdmins = _users.where((u) => u['role'] == 'hotel_admin').length;
    final staffs = _users.where((u) => u['role'] == 'staff').length;
    final customers = _users.where((u) => u['role'] == 'customer').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('账户概览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('${_users.length} 总用户', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildAccountCard('$sysAdmins', '系统管理', AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _buildAccountCard('$hotelAdmins', '酒店管理', AppColors.gold)),
              const SizedBox(width: 8),
              Expanded(child: _buildAccountCard('$staffs', '前台员工', AppColors.info)),
              const SizedBox(width: 8),
              Expanded(child: _buildAccountCard('$customers', '顾客', AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildSystemLogs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('系统日志', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const Text('查看全部', style: TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          if (_recentLogs.isEmpty)
            ..._buildDefaultLogs()
          else
            ..._recentLogs.take(3).map((log) => _buildLogItem(
              log['type'] ?? 'info',
              log['message'] ?? log['content'] ?? '',
              log['source'] ?? '',
              _formatTimeAgo(log['created_at']),
            )),
        ],
      ),
    );
  }

  List<Widget> _buildDefaultLogs() {
    return [
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.description_outlined, size: 32, color: Colors.grey[300]),
              const SizedBox(height: 8),
              const Text('暂无系统日志', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildLogItem(String type, String message, String source, String time) {
    Color color;
    IconData icon;
    Color borderColor;
    switch (type) {
      case 'success':
        color = AppColors.success;
        icon = Icons.check_circle_outline;
        borderColor = Colors.green.withValues(alpha: 0.1);
        break;
      case 'error':
      case 'warning':
        color = AppColors.error;
        icon = Icons.warning_amber_rounded;
        borderColor = Colors.red.withValues(alpha: 0.1);
        break;
      default:
        color = AppColors.info;
        icon = Icons.info_outline;
        borderColor = AppColors.divider;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                Text('$source · $time', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
          if (type == 'error')
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Text('处理', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }

  void _showNotifications() {
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
            if (_pendingApps.isEmpty)
              const Center(child: Text('暂无新通知', style: TextStyle(color: AppColors.textHint)))
            else
              ..._pendingApps.take(5).map((app) => ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.warning.withValues(alpha: 0.1), child: const Icon(Icons.pending_actions_rounded, color: AppColors.warning, size: 20)),
                title: Text('${app['username'] ?? '-'} 提交了审核申请', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(_formatTimeAgo(app['created_at'])),
              )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showUsersDialog() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _UsersManagePage()));
  }

  void _showMembershipDialog() {
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
            const Text('会员方案', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_membershipTiers.isEmpty)
              ...MemberLevel.allLevels.map((level) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMembershipCard(level.label, level.discount < 1.0 ? '${(level.discount * 10).toStringAsFixed(1)}折' : '免费', '${level.pointsText}${level.discount < 1.0 ? '+' : ''}', level.key == 'diamond' ? Icons.diamond : level.key == 'platinum' ? Icons.workspace_premium : level.key == 'gold' ? Icons.emoji_events : level.key == 'silver' ? Icons.military_tech : Icons.card_membership, level.color),
              ))
            else
              ..._membershipTiers.map((tier) {
                final level = MemberLevel.fromKey(tier['tier_key'] ?? 'standard');
                final price = tier['price']?.toString() ?? (tier['tier_key'] == 'standard' ? '免费' : '¥${tier['price'] ?? 0}/年');
                final benefits = tier['benefits']?.toString() ?? level.discountText;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildMembershipCard(tier['tier_name'] ?? level.label, price, benefits, level.key == 'diamond' ? Icons.diamond : level.key == 'platinum' ? Icons.workspace_premium : level.key == 'gold' ? Icons.emoji_events : level.key == 'silver' ? Icons.military_tech : Icons.card_membership, level.color),
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipCard(String title, String price, String benefits, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                Text(benefits, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(price, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showSystemLogsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('系统日志', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ..._recentLogs.isEmpty ? _buildDefaultLogs() : _recentLogs.map((log) => _buildLogItem(
                      log['type'] ?? 'info',
                      log['message'] ?? log['content'] ?? '',
                      log['source'] ?? '',
                      _formatTimeAgo(log['created_at']),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridItem {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;
  const _GridItem({required this.icon, required this.label, required this.color, required this.bgColor, required this.borderColor, required this.onTap});
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

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(hotelServiceProvider).getHotels(keyword: _searchQuery.isNotEmpty ? _searchQuery : null, pageSize: 100);
      if (result.success && mounted) setState(() => _hotels = result.data ?? []);
    } catch (e) {
      debugPrint('hotels: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('酒店管理'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.add_business_rounded), onPressed: () => _showCreateHotelDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHotels,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: InputDecoration(hintText: '搜索酒店名称', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                      onChanged: (v) { _searchQuery = v; _loadHotels(); },
                    ),
                  ),
                  Expanded(
                    child: _hotels.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hotel_outlined, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), const Text('暂无酒店', style: TextStyle(color: AppColors.textHint))]))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _hotels.length,
                            itemBuilder: (ctx, i) => _HotelCard(hotel: _hotels[i], onEdit: () => _showEditHotelDialog(_hotels[i]), onDelete: () => _deleteHotel(_hotels[i])),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateHotelDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('新增酒店'),
      ),
    );
  }

  void _showCreateHotelDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String selectedStar = '5';

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
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('新增酒店', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
                  const SizedBox(height: 20),
                  Flexible(child: SingleChildScrollView(child: Column(children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '酒店名称 *', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: '酒店地址', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '联系电话', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
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
                  ]))),
                  const SizedBox(height: 20),
                  ElevatedButton(
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
                          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('酒店创建成功'), backgroundColor: AppColors.success)); _loadHotels(); }
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? '创建失败')));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建失败，请重试')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('创建'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditHotelDialog(Hotel hotel) {
    final nameCtrl = TextEditingController(text: hotel.hotelName);
    final addressCtrl = TextEditingController(text: hotel.hotelAddress);
    final phoneCtrl = TextEditingController(text: hotel.hotelPhone);
    final cityCtrl = TextEditingController(text: hotel.city ?? '');
    String selectedStar = hotel.hotelStar.toString();

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
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('编辑酒店', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
                  const SizedBox(height: 20),
                  Flexible(child: SingleChildScrollView(child: Column(children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '酒店名称 *', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: '酒店地址', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '联系电话', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
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
                  ]))),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final dio = DioClient();
                        final res = await dio.put('${ApiConstants.hotels}/${hotel.id}', data: {
                          'hotel_name': nameCtrl.text.trim(),
                          'hotel_address': addressCtrl.text.trim(),
                          'hotel_phone': phoneCtrl.text.trim(),
                          'city': cityCtrl.text.trim(),
                          'hotel_star': int.tryParse(selectedStar) ?? 5,
                        });
                        if (res.statusCode == 200 && res.data['code'] == 200) {
                          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('酒店已更新'), backgroundColor: AppColors.success)); _loadHotels(); }
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? '更新失败')));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
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
      ),
    );
  }

  Future<void> _deleteHotel(Hotel hotel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除酒店"${hotel.hotelName}"吗？'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除'))],
      ),
    );
    if (confirm == true) {
      try {
        final dio = DioClient();
        final res = await dio.delete('${ApiConstants.hotels}/${hotel.id}');
        if (res.statusCode == 200 && res.data['code'] == 200) {
          _loadHotels();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('酒店已删除'), backgroundColor: AppColors.success));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    }
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: hotel.displayImage.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(hotel.displayImage, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.hotel, color: AppColors.primary, size: 24)))
                : const Icon(Icons.hotel, color: AppColors.primary, size: 24),
          ),
          title: Row(children: [
            Expanded(child: Text(hotel.hotelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [const Icon(Icons.star, size: 12, color: AppColors.gold), Text('${hotel.effectiveStar}', style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600))]),
            ),
          ]),
          subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(hotel.displayAddress, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
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

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(deviceServiceProvider).getAllDevices(status: _statusFilter);
      if (result.success && mounted) setState(() => _devices = List<Map<String, dynamic>>.from(result.data ?? []));
    } catch (e) {
      debugPrint('devices: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _onlineCount => _devices.where((d) => d['status'] == 'online' || d['device_status'] == 'online').length;
  int get _offlineCount => _devices.length - _onlineCount;

  List<Map<String, dynamic>> get _filteredDevices {
    if (_searchQuery.isEmpty) return _devices;
    return _devices.where((d) {
      final matchSearch = _searchQuery.isEmpty || (d['device_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) || (d['device_id'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('全局设备'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _miniStat('总设备', _devices.length, Icons.devices, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _miniStat('在线', _onlineCount, Icons.wifi, AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _miniStat('离线', _offlineCount, Icons.wifi_off, AppColors.textHint)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(hintText: '搜索设备名称/ID', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _FilterChip(label: '全部', isSelected: _statusFilter == null, onTap: () { setState(() => _statusFilter = null); _loadDevices(); }),
            const SizedBox(width: 6),
            _FilterChip(label: '在线', isSelected: _statusFilter == 'online', onTap: () { setState(() => _statusFilter = 'online'); _loadDevices(); }),
            const SizedBox(width: 6),
            _FilterChip(label: '离线', isSelected: _statusFilter == 'offline', onTap: () { setState(() => _statusFilter = 'offline'); _loadDevices(); }),
          ])),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadDevices,
                  child: _filteredDevices.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.devices_outlined, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), const Text('暂无设备', style: TextStyle(color: AppColors.textHint))]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredDevices.length,
                          itemBuilder: (ctx, i) {
                            final d = _filteredDevices[i];
                            final status = d['status'] ?? d['device_status'] ?? '未知';
                            Color statusColor = status == 'online' ? AppColors.success : status == 'offline' ? AppColors.textHint : AppColors.warning;
                            return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                              leading: Icon(Icons.devices, color: statusColor),
                              title: Text(d['device_name'] ?? d['name'] ?? '设备${d['id']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('编号: ${d['id']} | ${d['device_type'] ?? '未知'}'),
                              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))),
                            ));
                          },
                        ),
              ),
        ),
      ]),
    );
  }

  Widget _miniStat(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]),
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

class _UsersManagePage extends ConsumerStatefulWidget {
  const _UsersManagePage();

  @override
  ConsumerState<_UsersManagePage> createState() => _UsersManagePageState();
}

class _UsersManagePageState extends ConsumerState<_UsersManagePage> {
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
    if (result.success && mounted) setState(() => _users = result.data ?? []);
    setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((u) {
      final username = (u['username'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return username.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Color _roleColor(String? role) {
    switch (AppRoles.normalize(role)) {
      case AppRoles.systemAdmin: return AppColors.error;
      case AppRoles.hotelAdmin: return AppColors.primary;
      case AppRoles.staff: return AppColors.info;
      default: return AppColors.success;
    }
  }

  String _roleLabel(String? role) => AppRoles.displayName(AppRoles.normalize(role));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('账户管理'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(decoration: InputDecoration(hintText: '搜索用户名/手机号', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white), onChanged: (v) => setState(() => _searchQuery = v))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _FilterChip(label: '全部', isSelected: _roleFilter == null, onTap: () { setState(() => _roleFilter = null); _loadUsers(); }),
          const SizedBox(width: 8),
          _FilterChip(label: '顾客', isSelected: _roleFilter == 'customer', onTap: () { setState(() => _roleFilter = 'customer'); _loadUsers(); }),
          const SizedBox(width: 8),
          _FilterChip(label: '前台', isSelected: _roleFilter == 'staff', onTap: () { setState(() => _roleFilter = 'staff'); _loadUsers(); }),
          const SizedBox(width: 8),
          _FilterChip(label: '酒店管理员', isSelected: _roleFilter == 'hotel_admin', onTap: () { setState(() => _roleFilter = 'hotel_admin'); _loadUsers(); }),
          const SizedBox(width: 8),
          _FilterChip(label: '系统管理员', isSelected: _roleFilter == 'system_admin', onTap: () { setState(() => _roleFilter = 'system_admin'); _loadUsers(); }),
        ]))),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _loadUsers, child: _filteredUsers.isEmpty ? Center(child: const Text('暂无用户', style: TextStyle(color: AppColors.textHint))) : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (ctx, i) {
                    final u = _filteredUsers[i];
                    final role = u['role'] ?? 'customer';
                    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                      leading: CircleAvatar(backgroundColor: _roleColor(role).withValues(alpha: 0.1), child: Icon(Icons.person, color: _roleColor(role))),
                      title: Row(children: [Flexible(child: Text(u['username'] ?? '未知', style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _roleColor(role).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(_roleLabel(role), style: TextStyle(color: _roleColor(role), fontSize: 11, fontWeight: FontWeight.bold)))]),
                      subtitle: Text('${u['phone'] ?? '-'}'),
                    ));
                  },
                )),
        ),
      ]),
    );
  }
}
