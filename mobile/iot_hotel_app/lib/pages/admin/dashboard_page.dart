import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/hotel_service.dart';
import '../../services/device_service.dart';
import '../../services/auth_service.dart';
import '../../services/review_service.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: '总览'),
    _NavItem(icon: Icons.devices_rounded, label: '设备'),
    _NavItem(icon: Icons.assessment_rounded, label: '报表'),
    _NavItem(icon: Icons.person_rounded, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _OverviewTab(),
      const _DevicesTab(),
      const _ReportsTab(),
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

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();
  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _revenueStats = {};
  List<Map<String, dynamic>> _deviceAlerts = [];
  List<Map<String, dynamic>> _reviews = [];
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

      final statsRes = await ref.read(hotelServiceProvider).getStatistics();
      if (statsRes.success && statsRes.data != null) {
        final statsData = statsRes.data!;
        if (mounted) {
          setState(() {
            final rooms = statsData['rooms'] as List<dynamic>? ?? [];
            int totalRooms = 0;
            int availableRooms = 0;
            int occupiedRooms = 0;
            for (final r in rooms) {
              final count = (r['count'] as num?)?.toInt() ?? 0;
              totalRooms += count;
              final status = r['room_status']?.toString() ?? '';
              if (status == 'available') availableRooms = count;
              if (status == 'occupied') occupiedRooms = count;
            }

            _stats = {
              'occupancy_rate': statsData['occupancy_rate'] ?? 0,
              'total_rooms': totalRooms,
              'occupied_rooms': occupiedRooms,
              'available_rooms': availableRooms,
              'device_count': 0,
              'online_devices': 0,
            };
          });
        }
      }

      final reportsRes = await ref.read(hotelServiceProvider).getReports(hotelId: hotelId);
      if (reportsRes.success && reportsRes.data != null) {
        final data = reportsRes.data!;
        if (mounted) {
          setState(() {
            double parseRevenue(dynamic value) {
              if (value == null) return 0;
              if (value is double) return value;
              if (value is int) return value.toDouble();
              if (value is String) return double.tryParse(value) ?? 0;
              return 0;
            }

            _revenueStats = {
              'today_revenue': parseRevenue(data['today_revenue']),
              'month_revenue': parseRevenue(data['month_revenue']),
              'week_revenues': data['revenue_trend'] ?? [],
            };
          });
        }
      }

      try {
        final deviceResult = await ref.read(deviceServiceProvider).getDevices(hotelId: hotelId);
        if (deviceResult.success) {
          final devices = List<Map<String, dynamic>>.from(deviceResult.data ?? []);
          final onlineCount = devices.where((d) {
            final status = (d['device_status'] ?? d['status'] ?? '').toString().toLowerCase();
            return status == 'online' || status == 'active' || status == 'normal' || status == '运行中';
          }).length;
          if (mounted) {
            setState(() {
              _stats['device_count'] = devices.length;
              _stats['online_devices'] = onlineCount;
              _deviceAlerts = devices.where((d) {
                final status = (d['device_status'] ?? d['status'] ?? '').toString().toLowerCase();
                return status == 'warning' || status == 'error' || status == 'offline' || status == '告警' || status == '故障';
              }).toList();
            });
          }
        }
      } catch (_) {}

      try {
        final reviewResult = await ref.read(reviewServiceProvider).getAllReviews(hotelId: hotelId, pageSize: 10);
        if (reviewResult.success && reviewResult.data != null) {
          final reviewData = reviewResult.data!;
          final reviewList = reviewData['list'] ?? reviewData['reviews'] ?? [];
          if (mounted) setState(() => _reviews = List<Map<String, dynamic>>.from(reviewList));
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('adminStats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final occupancyRate = _parseDouble(_stats['occupancy_rate']);
    final todayRevenue = _parseDouble(_revenueStats['today_revenue']);
    final onlineDevices = _stats['online_devices'] ?? 0;
    final totalDevices = _stats['device_count'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(occupancyRate, todayRevenue, onlineDevices, totalDevices),
            _buildRevenueChart(),
            _buildManagementGrid(),
            _buildDeviceAlerts(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Widget _buildHeader(double occupancyRate, double todayRevenue, int onlineDevices, int totalDevices) {
    final authState = ref.read(authStateProvider);
    final username = authState.username ?? '管理员';

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
                  Text('酒店管理', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('管理员: $username', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
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
              Expanded(child: _buildHeaderStat('${occupancyRate.toStringAsFixed(1)}%', '出租率', valueColor: AppColors.gold)),
              const SizedBox(width: 8),
              Expanded(child: _buildHeaderStat('¥${_formatRevenue(todayRevenue)}', '今日营收')),
              const SizedBox(width: 8),
              Expanded(child: _buildHeaderStat('$onlineDevices/$totalDevices', '设备在线', valueColor: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label, {Color? valueColor}) {
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
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}万';
    return value.toStringAsFixed(0);
  }

  Widget _buildRevenueChart() {
    final weekRevenues = _revenueStats['week_revenues'] as List?;
    final hasData = weekRevenues != null && weekRevenues.isNotEmpty;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('近7天营收', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text('月累计: ¥${_formatRevenue(_parseDouble(_revenueStats['month_revenue']))}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                ],
              ),
              const SizedBox(height: 16),
              if (hasData)
                _buildBarChart(weekRevenues)
              else
                _buildDefaultBarChart(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBarChart() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 32, color: Colors.grey[300]),
            const SizedBox(height: 8),
            const Text('暂无营收数据', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List revenues) {
    final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final values = revenues.take(7).map((v) => _parseDouble(v)).toList();
    while (values.length < 7) { values.add(0); }
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final height = maxVal > 0 ? (values[i] / maxVal * 100) : 0.0;
        final isToday = i == DateTime.now().weekday - 1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Text('¥${(values[i] / 1000).toStringAsFixed(1)}k', style: TextStyle(fontSize: 7, color: isToday ? AppColors.gold : AppColors.textHint)),
                const SizedBox(height: 4),
                Container(
                  height: height.clamp(4.0, double.infinity),
                  decoration: BoxDecoration(
                    gradient: isToday
                        ? const LinearGradient(colors: [AppColors.goldDark, AppColors.gold, AppColors.goldLight], begin: Alignment.bottomCenter, end: Alignment.topCenter)
                        : LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.6)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(days[i], style: TextStyle(fontSize: 9, color: isToday ? AppColors.gold : AppColors.textHint, fontWeight: isToday ? FontWeight.w600 : FontWeight.normal)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildManagementGrid() {
    final items = [
      _GridItem(icon: Icons.monitor_heart_rounded, label: '设备监控', color: AppColors.info, bgColor: AppColors.info.withValues(alpha: 0.05), borderColor: AppColors.info.withValues(alpha: 0.1), onTap: () {
        final state = context.findAncestorStateOfType<_AdminDashboardPageState>();
        state?.setState(() => state._selectedIndex = 1);
      }),
      _GridItem(icon: Icons.meeting_room_rounded, label: '房间管理', color: AppColors.primary, bgColor: AppColors.primary.withValues(alpha: 0.05), borderColor: AppColors.primary.withValues(alpha: 0.1), onTap: () => context.push('/admin/floors')),
      _GridItem(icon: Icons.calendar_month_rounded, label: '价格日历', color: Colors.purple, bgColor: Colors.purple.withValues(alpha: 0.05), borderColor: Colors.purple.withValues(alpha: 0.1), onTap: () => context.push('/admin/price-calendar')),
      _GridItem(icon: Icons.people_rounded, label: '用户管理', color: Colors.orange, bgColor: Colors.orange.withValues(alpha: 0.05), borderColor: Colors.orange.withValues(alpha: 0.1), onTap: () => context.push('/admin/users')),
      _GridItem(icon: Icons.thermostat_rounded, label: '环境监测', color: Colors.teal, bgColor: Colors.teal.withValues(alpha: 0.05), borderColor: Colors.teal.withValues(alpha: 0.1), onTap: () => context.push('/admin/environment')),
      _GridItem(icon: Icons.local_offer_rounded, label: '优惠券', color: Colors.pink, bgColor: Colors.pink.withValues(alpha: 0.05), borderColor: Colors.pink.withValues(alpha: 0.1), onTap: () => context.push('/admin/coupons')),
      _GridItem(icon: Icons.receipt_long_rounded, label: '账单报表', color: AppColors.gold, bgColor: AppColors.gold.withValues(alpha: 0.05), borderColor: AppColors.gold.withValues(alpha: 0.1), onTap: () {
        final state = context.findAncestorStateOfType<_AdminDashboardPageState>();
        state?.setState(() => state._selectedIndex = 2);
      }),
      _GridItem(icon: Icons.rate_review_rounded, label: '评价管理', color: Colors.indigo, bgColor: Colors.indigo.withValues(alpha: 0.05), borderColor: Colors.indigo.withValues(alpha: 0.1), onTap: () => _showReviewsDialog()),
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

  Widget _buildDeviceAlerts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('设备告警', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              if (_deviceAlerts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                  child: Text('${_deviceAlerts.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_deviceAlerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success.withValues(alpha: 0.5), size: 20),
                  const SizedBox(width: 8),
                  const Text('所有设备运行正常', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                ],
              ),
            )
          else
            ..._deviceAlerts.take(3).map((alert) => _buildAlertCard(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final status = (alert['device_status'] ?? alert['status'] ?? 'warning').toString();
    final isWarning = status == 'warning' || status == 'offline';
    final color = isWarning ? AppColors.warning : AppColors.error;

    String deviceName = alert['device_name'] ?? alert['name'] ?? '未知设备';
    String deviceType = alert['device_type'] ?? '';
    if (deviceType.isNotEmpty) deviceName = '$deviceName ($deviceType)';

    String message = alert['message'] ?? alert['alert_message'] ?? '';
    if (message.isEmpty) {
      if (status == 'offline') {
        message = '设备离线';
      } else if (status == 'error') {
        message = '设备故障';
      } else if (status == 'warning') {
        message = '设备告警';
      } else {
        message = '状态异常: $status';
      }
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
            child: Icon(isWarning ? Icons.warning_amber_rounded : Icons.error_outline, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deviceName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                Text(message, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _handleAlertAction(alert),
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

  void _handleAlertAction(Map<String, dynamic> alert) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('处理设备告警', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('设备: ${alert['device_name'] ?? alert['name'] ?? '未知设备'}'),
            const SizedBox(height: 8),
            Text('状态: ${alert['device_status'] ?? alert['status'] ?? '异常'}'),
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
                      final deviceId = alert['id'] ?? alert['device_id'];
                      if (deviceId != null) {
                        final result = await ref.read(deviceServiceProvider).sendCommand(
                          int.parse(deviceId.toString()),
                          'status',
                          'normal',
                        );
                        if (result.success && mounted) {
                          setState(() {
                            _deviceAlerts.removeWhere((a) => (a['id'] ?? a['device_id']).toString() == deviceId.toString());
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('告警已处理并从列表移除'), backgroundColor: AppColors.success),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('处理失败: ${result.message}'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('确认处理'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewsDialog() {
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
              const Text('评价管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (_reviews.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[300]), const SizedBox(height: 12), const Text('暂无评价', style: TextStyle(color: AppColors.textHint))])))
                    else
                      ..._reviews.map((review) => _buildReviewCard(
                        review['username'] ?? review['guest_name'] ?? '用户',
                        review['room_type_name'] ?? review['room_type'] ?? '房型',
                        (review['score'] ?? review['rating'] ?? 0) is num ? ((review['score'] ?? review['rating']) as num).toInt() : int.tryParse(review['score']?.toString() ?? '0') ?? 0,
                        review['content'] ?? review['comment'] ?? '',
                        (review['created_at'] ?? '').toString().substring(0, review['created_at'].toString().length > 10 ? 10 : review['created_at'].toString().length),
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

  Widget _buildReviewCard(String username, String roomType, int rating, String content, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Text(username[0], style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('$roomType · $date', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(Icons.star, size: 16, color: i < rating ? AppColors.gold : AppColors.divider)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
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
      final hotelId = await ref.read(authServiceProvider).getCurrentHotelId();
      if (hotelId == null) { if (mounted) setState(() => _isLoading = false); return; }

      final result = await ref.read(deviceServiceProvider).getDevices(hotelId: hotelId, status: _statusFilter);
      if (result.success && mounted) setState(() => _devices = List<Map<String, dynamic>>.from(result.data ?? []));
    } catch (e) {
      debugPrint('devices: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _onlineCount => _devices.where((d) => d['status'] == 'online' || d['device_status'] == 'online').length;
  int get _warningCount => _devices.where((d) => d['status'] == 'warning' || d['device_status'] == 'warning').length;

  List<Map<String, dynamic>> get _filteredDevices {
    if (_searchQuery.isEmpty) return _devices;
    return _devices.where((d) {
      final name = (d['device_name'] ?? d['name'] ?? '').toString().toLowerCase();
      final id = (d['device_id'] ?? d['id'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || id.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('设备监控'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _miniStat('总设备', _devices.length, Icons.devices, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _miniStat('在线', _onlineCount, Icons.wifi, AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _miniStat('告警', _warningCount, Icons.warning, AppColors.warning)),
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
            const SizedBox(width: 6),
            _FilterChip(label: '告警', isSelected: _statusFilter == 'warning', onTap: () { setState(() => _statusFilter = 'warning'); _loadDevices(); }),
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
                            Color statusColor;
                            switch (status) {
                              case 'online': statusColor = AppColors.success; break;
                              case 'offline': statusColor = AppColors.textHint; break;
                              case 'warning': statusColor = AppColors.warning; break;
                              case 'error': statusColor = AppColors.error; break;
                              default: statusColor = AppColors.textHint;
                            }
                            return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(_deviceIcon(d['device_type']), color: statusColor, size: 20)),
                              title: Text(d['device_name'] ?? d['name'] ?? '设备${d['id']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('${d['room_name'] ?? ''} | ${d['device_type'] ?? '未知'}'),
                              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))),
                            ));
                          },
                        ),
              ),
        ),
      ]),
    );
  }

  IconData _deviceIcon(dynamic type) {
    final t = type?.toString().toLowerCase() ?? '';
    if (t.contains('light') || t.contains('灯')) return Icons.lightbulb;
    if (t.contains('ac') || t.contains('空调') || t.contains('温控')) return Icons.thermostat;
    if (t.contains('curtain') || t.contains('窗帘')) return Icons.blinds;
    if (t.contains('lock') || t.contains('门锁')) return Icons.lock;
    if (t.contains('sensor') || t.contains('传感器')) return Icons.sensors;
    return Icons.devices;
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

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();
  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  Map<String, dynamic> _reports = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final hotelId = await ref.read(authServiceProvider).getCurrentHotelId();
      if (hotelId == null) { if (mounted) setState(() => _isLoading = false); return; }

      final result = await ref.read(hotelServiceProvider).getReports(hotelId: hotelId);
      if (result.success && mounted) setState(() => _reports = result.data ?? {});
    } catch (e) {
      debugPrint('reports: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('账单报表'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: _reportCard('今日营收', '¥${_parseDouble(_reports['today_revenue'] ?? _reports['daily_revenue']).toStringAsFixed(0)}', AppColors.primary, Icons.payments)),
                      const SizedBox(width: 12),
                      Expanded(child: _reportCard('本月营收', '¥${_parseDouble(_reports['month_revenue'] ?? _reports['monthly_revenue_total']).toStringAsFixed(0)}', AppColors.gold, Icons.trending_up)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _reportCard('入住率', '${_parseDouble(_reports['occupancy_rate'] ?? _reports['today_occupancy_rate']).toStringAsFixed(1)}%', AppColors.success, Icons.pie_chart)),
                      const SizedBox(width: 12),
                      Expanded(child: _reportCard('总房间', '${_reports['total_rooms'] ?? 0}', AppColors.info, Icons.meeting_room)),
                    ]),
                    const SizedBox(height: 20),
                    const Text('快捷入口', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 12),
                    _quickLink(Icons.calendar_month, '价格日历', '/admin/price-calendar'),
                    _quickLink(Icons.local_offer, '优惠券管理', '/admin/coupons'),
                    _quickLink(Icons.people, '用户管理', '/admin/users'),
                    _quickLink(Icons.category, '房型管理', '/admin/room-types'),
                    _quickLink(Icons.layers, '楼层管理', '/admin/floors'),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _reportCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(title, style: TextStyle(fontSize: 11, color: color))]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _quickLink(IconData icon, String label, String route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: () => context.push(route),
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
    final username = authState.username ?? '管理员';

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
                gradient: const LinearGradient(colors: [AppColors.royalGradientStart, AppColors.royalGradientEnd]),
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
                        Text('酒店管理员', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _menuCard(Icons.hotel, '酒店信息编辑', () => context.push('/admin/floors')),
            _menuCard(Icons.category, '房型管理', () => context.push('/admin/room-types')),
            _menuCard(Icons.layers, '楼层管理', () => context.push('/admin/floors')),
            _menuCard(Icons.book, '知识库管理', () => context.push('/admin/knowledge-base')),
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
