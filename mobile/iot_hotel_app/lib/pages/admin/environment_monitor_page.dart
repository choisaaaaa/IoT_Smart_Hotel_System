import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../services/environment_service.dart';
import '../../services/device_service.dart';

class EnvironmentMonitorPage extends ConsumerStatefulWidget {
  const EnvironmentMonitorPage({super.key});

  @override
  ConsumerState<EnvironmentMonitorPage> createState() => _EnvironmentMonitorPageState();
}

class _EnvironmentMonitorPageState extends ConsumerState<EnvironmentMonitorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardStats;
  List<dynamic> _fireAlarms = [];
  List<dynamic> _eventLogs = [];
  List<dynamic> _devices = [];
  List<dynamic> _environmentList = [];
  Map<String, dynamic> _environmentSummary = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDashboardStats(),
      _loadFireAlarms(),
      _loadEventLogs(),
      _loadDevices(),
      _loadEnvironmentData(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadEnvironmentData() async {
    final result = await ref.read(environmentServiceProvider).getEnvironmentData();
    if (result.success && mounted) {
      final data = result.data ?? {};
      setState(() {
        _environmentList = List<dynamic>.from(data['list'] ?? []);
        _environmentSummary = data['summary'] ?? {};
      });
    }
  }

  Future<void> _loadDashboardStats() async {
    final result = await ref.read(environmentServiceProvider).getDashboardStats();
    if (result.success && mounted) {
      setState(() {
        _dashboardStats = result.data;
        debugPrint('Environment dashboard stats: $_dashboardStats');
      });
    }
  }

  Future<void> _loadFireAlarms() async {
    final result = await ref.read(environmentServiceProvider).getFireAlarms();
    if (result.success && mounted) {
      final data = result.data;
      if (data != null && data.containsKey('alarms')) {
        setState(() => _fireAlarms = List<dynamic>.from(data['alarms'] ?? []));
      } else {
        setState(() => _fireAlarms = []);
      }
    }
  }

  Future<void> _loadEventLogs() async {
    final result = await ref.read(environmentServiceProvider).getEventLogs(limit: 30);
    if (result.success && mounted) {
      final data = result.data;
      if (data != null && data.containsKey('logs')) {
        setState(() => _eventLogs = List<dynamic>.from(data['logs'] ?? []));
      } else {
        setState(() => _eventLogs = []);
      }
    }
  }

  Future<void> _loadDevices() async {
    final result = await ref.read(deviceServiceProvider).getAllDevices();
    if (result.success && mounted) {
      setState(() => _devices = result.data ?? []);
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
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '总览'),
            Tab(icon: Icon(Icons.thermostat), text: '环境'),
            Tab(icon: Icon(Icons.fire_extinguisher), text: '消防'),
            Tab(icon: Icon(Icons.device_hub), text: '设备'),
            Tab(icon: Icon(Icons.history), text: '日志'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildEnvironmentTab(),
                _buildFireAlarmTab(),
                _buildDeviceTab(),
                _buildEventLogTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final env = _dashboardStats?['environment'] ?? {};
    final fire = _dashboardStats?['fire_safety'] ?? {};
    final devices = _dashboardStats?['devices'] ?? {};
    final alerts = _dashboardStats?['alerts'] ?? {};

    // 优先使用 environment 接口的 summary 数据
    final summary = _environmentSummary;

    // 安全地获取数值
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // 优先使用 environment 接口的 summary 数据，如果没有则使用 dashboard stats
    final avgTemp = parseDouble(summary['avg_temperature']) ?? parseDouble(env['avg_temperature']);
    final avgHumidity = parseDouble(summary['avg_humidity']) ?? parseDouble(env['avg_humidity']);
    final onlineCount = parseInt(devices['online']) ?? 0;
    final totalCount = parseInt(devices['total']) ?? 0;
    final runningCount = parseInt(devices['running']) ?? 0;
    final errorCount = parseInt(devices['error']) ?? 0;
    final activeAlarms = parseInt(fire['active_alarms']) ?? 0;
    final detectorsOnline = parseInt(fire['detectors_online']) ?? 0;
    final detectorsTotal = parseInt(fire['detectors_total']) ?? 0;
    final unresolvedAlerts = parseInt(alerts['unresolved']) ?? 0;
    final criticalAlerts = parseInt(alerts['critical']) ?? 0;
    final warningAlerts = parseInt(alerts['warning']) ?? 0;
    final envScore = parseInt(summary['avg_environment_score']) ?? parseInt(_dashboardStats?['environment_score']);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _EnvironmentCard(
                    title: '平均温度',
                    value: avgTemp != null ? avgTemp.toStringAsFixed(1) : '--',
                    unit: '°C',
                    icon: Icons.thermostat,
                    color: Colors.orange,
                    subtitle: '空气质量: ${env['air_quality'] ?? '--'}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _EnvironmentCard(
                    title: '平均湿度',
                    value: avgHumidity != null ? avgHumidity.toStringAsFixed(0) : '--',
                    unit: '%',
                    icon: Icons.water_drop,
                    color: Colors.blue,
                    subtitle: '舒适度: ${env['comfort_level'] ?? '--'}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _EnvironmentCard(
                    title: '设备在线率',
                    value: totalCount > 0
                        ? ((onlineCount / totalCount) * 100).toStringAsFixed(0)
                        : '--',
                    unit: '%',
                    icon: Icons.devices,
                    color: Colors.amber,
                    subtitle: '$onlineCount/$totalCount 在线',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _EnvironmentCard(
                    title: '环境评分',
                    value: envScore?.toString() ?? '--',
                    unit: '分',
                    icon: Icons.eco,
                    color: Colors.green,
                    subtitle: '综合评估',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FireSafetyCard(
              activeAlarms: activeAlarms,
              detectorsOnline: detectorsOnline,
              detectorsTotal: detectorsTotal,
              onTap: () => _tabController.animateTo(2),
            ),
            const SizedBox(height: 16),
            _DeviceStatusCard(
              online: onlineCount,
              total: totalCount,
              running: runningCount,
              error: errorCount,
              onTap: () => _tabController.animateTo(3),
            ),
            const SizedBox(height: 16),
            if (unresolvedAlerts > 0)
              _AlertsCard(
                unresolved: unresolvedAlerts,
                critical: criticalAlerts,
                warning: warningAlerts,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentTab() {
    // 优先使用 environment 接口的数据（和Web端一致）
    if (_environmentList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thermostat_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无环境传感器数据', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _environmentList.length,
        itemBuilder: (context, index) {
          final env = _environmentList[index];
          final roomNumber = env['room_number']?.toString() ?? '-';
          final temperature = env['temperature'];
          final humidity = env['humidity'];
          final smokeLevel = env['smoke_level'];
          final status = env['status']?.toString() ?? 'normal';
          final updateTime = env['update_time']?.toString() ?? '';

          Color statusColor;
          String statusText;
          switch (status) {
            case 'warning':
              statusColor = Colors.orange;
              statusText = '警告';
              break;
            case 'danger':
              statusColor = Colors.red;
              statusText = '危险';
              break;
            default:
              statusColor = Colors.green;
              statusText = '正常';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.room, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '房间 $roomNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _EnvironmentMetric(
                        icon: Icons.thermostat,
                        label: '温度',
                        value: temperature != null ? '$temperature°C' : '--',
                        color: Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _EnvironmentMetric(
                        icon: Icons.water_drop,
                        label: '湿度',
                        value: humidity != null ? '$humidity%' : '--',
                        color: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _EnvironmentMetric(
                        icon: Icons.smoke_free,
                        label: '烟雾',
                        value: smokeLevel != null ? '$smokeLevel%' : '--',
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                if (updateTime.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '更新时间: ${DateUtils.formatDynamic(updateTime)}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFireAlarmTab() {
    final activeAlarms = _fireAlarms.where((a) => a['status'] == 'active').toList();
    final acknowledgedAlarms = _fireAlarms.where((a) => a['status'] == 'acknowledged').toList();
    final resolvedAlarms = _fireAlarms.where((a) => a['status'] == 'resolved' || a['status'] == 'false_alarm').toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '活跃警报'),
              Tab(text: '已确认'),
              Tab(text: '已解决'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAlarmList(activeAlarms, showActions: true),
                _buildAlarmList(acknowledgedAlarms, showActions: true),
                _buildAlarmList(resolvedAlarms, showActions: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmList(List<dynamic> alarms, {required bool showActions}) {
    if (alarms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无警报', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alarms.length,
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        return _FireAlarmCard(
          alarm: alarm,
          onAcknowledge: showActions
              ? () => _acknowledgeAlarm(alarm['id'])
              : null,
          onResolve: showActions
              ? () => _resolveAlarm(alarm['id'])
              : null,
        );
      },
    );
  }

  Widget _buildDeviceTab() {
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.device_hub_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无设备数据', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return _DeviceCard(device: device);
        },
      ),
    );
  }

  Widget _buildEventLogTab() {
    if (_eventLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无事件日志', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _eventLogs.length,
        itemBuilder: (context, index) {
          final log = _eventLogs[index];
          return _EventLogCard(log: log);
        },
      ),
    );
  }

  Future<void> _acknowledgeAlarm(int alarmId) async {
    final result = await ref.read(environmentServiceProvider).acknowledgeAlarm(alarmId);
    if (result.success) {
      _loadFireAlarms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('警报已确认')),
        );
      }
    }
  }

  Future<void> _resolveAlarm(int alarmId) async {
    final result = await ref.read(environmentServiceProvider).resolveAlarm(alarmId);
    if (result.success) {
      _loadFireAlarms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('警报已解决')),
        );
      }
    }
  }
}

class _EnvironmentCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _EnvironmentCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.notoSansSc(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _EnvironmentMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _FireSafetyCard extends StatelessWidget {
  final int activeAlarms;
  final int detectorsOnline;
  final int detectorsTotal;
  final VoidCallback onTap;

  const _FireSafetyCard({
    required this.activeAlarms,
    required this.detectorsOnline,
    required this.detectorsTotal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onlineRate = detectorsTotal > 0
        ? (detectorsOnline / detectorsTotal * 100).toStringAsFixed(0)
        : '0';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: activeAlarms > 0 ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activeAlarms > 0 ? Colors.red.shade200 : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fire_extinguisher,
                      color: activeAlarms > 0 ? Colors.red : Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '消防安全',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (activeAlarms > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$activeAlarms个警报',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              activeAlarms > 0 ? '注意：有活跃警报' : '系统正常',
              style: GoogleFonts.notoSansSc(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: activeAlarms > 0 ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '探测器在线率: $onlineRate% ($detectorsOnline/$detectorsTotal)',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  final int online;
  final int total;
  final int running;
  final int error;
  final VoidCallback onTap;

  const _DeviceStatusCard({
    required this.online,
    required this.total,
    required this.running,
    required this.error,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.device_hub, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  '设备状态',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DeviceStatItem(
                  label: '在线',
                  value: '$online',
                  color: Colors.green,
                ),
                _DeviceStatItem(
                  label: '总计',
                  value: '$total',
                  color: Colors.blue,
                ),
                _DeviceStatItem(
                  label: '运行中',
                  value: '$running',
                  color: Colors.orange,
                ),
                _DeviceStatItem(
                  label: '异常',
                  value: '$error',
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DeviceStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.notoSansSc(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final int unresolved;
  final int critical;
  final int warning;

  const _AlertsCard({
    required this.unresolved,
    required this.critical,
    required this.warning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                '待处理告警',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AlertStatItem(
                  label: '总计',
                  value: '$unresolved',
                  color: Colors.orange,
                ),
              ),
              Expanded(
                child: _AlertStatItem(
                  label: '严重',
                  value: '$critical',
                  color: Colors.red,
                ),
              ),
              Expanded(
                child: _AlertStatItem(
                  label: '警告',
                  value: '$warning',
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AlertStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.notoSansSc(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FireAlarmCard extends StatelessWidget {
  final dynamic alarm;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onResolve;

  const _FireAlarmCard({
    required this.alarm,
    this.onAcknowledge,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final alarmType = alarm['alarm_type'] ?? '未知';
    final roomNumber = alarm['room_number'] ?? alarm['room_id'] ?? '-';
    final status = alarm['status'] ?? 'active';
    final createdAt = alarm['triggered_at'] ?? alarm['created_at'] ?? '';
    final description = alarm['description'] ?? '';

    String typeText;
    IconData typeIcon;
    Color typeColor;

    switch (alarmType) {
      case 'smoke':
        typeText = '烟雾警报';
        typeIcon = Icons.smoke_free;
        typeColor = Colors.red;
        break;
      case 'temperature':
        typeText = '温度异常';
        typeIcon = Icons.thermostat;
        typeColor = Colors.orange;
        break;
      case 'co':
        typeText = '一氧化碳';
        typeIcon = Icons.cloud;
        typeColor = Colors.purple;
        break;
      default:
        typeText = '设备告警';
        typeIcon = Icons.warning;
        typeColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '房间 $roomNumber · ${DateUtils.formatDateDynamic(createdAt)}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (onAcknowledge != null || onResolve != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onAcknowledge != null && status == 'active')
                  TextButton(
                    onPressed: onAcknowledge,
                    child: const Text('确认'),
                  ),
                if (onResolve != null && status != 'resolved')
                  ElevatedButton(
                    onPressed: onResolve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('解决'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.red;
      case 'acknowledged':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'false_alarm':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '活跃';
      case 'acknowledged':
        return '已确认';
      case 'resolved':
        return '已解决';
      case 'false_alarm':
        return '误报';
      default:
        return '未知';
    }
  }
}

class _DeviceCard extends StatelessWidget {
  final dynamic device;

  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final deviceType = device['device_type'] ?? device['type'] ?? '未知';
    final roomNumber = device['room_number'] ?? device['room_id'] ?? '-';
    final status = device['device_status'] ?? device['status'] ?? 'offline';
    final name = device['device_name'] ?? device['name'] ?? '未命名设备';
    final isOnline = status == 'online' || status == 'on';

    IconData deviceIcon;
    Color deviceColor;

    switch (deviceType) {
      case 'thermostat':
      case 'temperature_sensor':
        deviceIcon = Icons.thermostat;
        deviceColor = Colors.orange;
        break;
      case 'humidity_sensor':
        deviceIcon = Icons.water_drop;
        deviceColor = Colors.blue;
        break;
      case 'smoke_detector':
      case 'sensor':
        deviceIcon = Icons.smoke_free;
        deviceColor = Colors.red;
        break;
      case 'light':
        deviceIcon = Icons.lightbulb;
        deviceColor = Colors.yellow;
        break;
      case 'curtain':
        deviceIcon = Icons.curtains;
        deviceColor = Colors.purple;
        break;
      case 'ac':
      case 'air_conditioner':
        deviceIcon = Icons.ac_unit;
        deviceColor = Colors.cyan;
        break;
      case 'tv':
        deviceIcon = Icons.tv;
        deviceColor = Colors.indigo;
        break;
      case 'lock':
        deviceIcon = Icons.lock;
        deviceColor = Colors.green;
        break;
      default:
        deviceIcon = Icons.device_unknown;
        deviceColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: deviceColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(deviceIcon, color: deviceColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '房间 $roomNumber',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLogCard extends StatelessWidget {
  final dynamic log;

  const _EventLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final eventType = log['event_type'] ?? '未知';
    final description = log['description'] ?? log['title'] ?? '';
    final roomNumber = log['room_number'] ?? log['room_id'] ?? '-';
    final createdAt = log['created_at'] ?? '';

    IconData eventIcon;
    Color eventColor;

    switch (eventType) {
      case 'fire_alarm':
        eventIcon = Icons.warning;
        eventColor = Colors.red;
        break;
      case 'device_error':
        eventIcon = Icons.device_hub;
        eventColor = Colors.blue;
        break;
      case 'environment_warning':
        eventIcon = Icons.eco;
        eventColor = Colors.orange;
        break;
      case 'device_control':
        eventIcon = Icons.settings_remote;
        eventColor = Colors.green;
        break;
      case 'maintenance':
        eventIcon = Icons.build;
        eventColor = Colors.purple;
        break;
      case 'energy_alert':
        eventIcon = Icons.bolt;
        eventColor = Colors.amber;
        break;
      default:
        eventIcon = Icons.info;
        eventColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: eventColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(eventIcon, color: eventColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '房间 $roomNumber · ${DateUtils.formatDateDynamic(createdAt)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
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
