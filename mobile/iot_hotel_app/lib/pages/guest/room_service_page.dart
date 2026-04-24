import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/mqtt/mqtt_service.dart';
import '../../core/constants/mqtt_constants.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../core/utils/date_utils.dart';
import '../../services/auth_service.dart';
import '../../core/services/app_realtime_provider.dart';
import '../../core/services/realtime_service.dart';
import '../../components/alarm_alert_overlay.dart';
import '../../components/incoming_call_overlay.dart';
import '../../components/device_control_panel.dart';
import '../../services/device_service.dart';
import '../../services/delivery_service.dart';
import '../../services/voice_call_service.dart';
import '../../services/booking_service.dart';
import '../../services/maintenance_service.dart';
import '../../models/booking.dart';

class RoomServicePage extends ConsumerStatefulWidget {
  final int? bookingId;
  final int? initialTab;
  const RoomServicePage({super.key, this.bookingId, this.initialTab});

  @override
  ConsumerState<RoomServicePage> createState() => _RoomServicePageState();
}

class _RoomServicePageState extends ConsumerState<RoomServicePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isCheckedIn = false;
  Booking? _currentStay;
  List<dynamic> _devices = [];
  final MqttService _mqttService = MqttService();
  String? _lastUserId;
  StreamSubscription? _realtimeEventSub;
  StreamSubscription? _securityEventSub;
  StreamSubscription? _incomingCallSub;
  StreamSubscription? _deviceStatusSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialTab ?? 0);
    WidgetsBinding.instance.addObserver(this);
    _lastUserId = ref.read(authStateProvider).userId;
    _checkCheckinStatus();
    _initRealtimeListeners();
  }

  void _initRealtimeListeners() {
    final authState = ref.read(authStateProvider);
    final userId = authState.userId?.toString() ?? 'guest_app';

    ref.read(authServiceProvider).getCurrentHotelId().then((hotelId) {
      final isStaff = ['hotel_admin', 'system_admin', 'staff'].contains(authState.role);
      final clientType = isStaff ? 'front_desk' : 'app';

      ref.read(appRealtimeProvider.notifier).init(
        userId: userId,
        clientType: clientType,
        hotelId: hotelId,
      );

      if (isStaff && hotelId != null) {
        ref.read(appRealtimeProvider.notifier).joinHotelRoom(hotelId);
      }
    });

    _securityEventSub = RealtimeService().securityEvents.listen((data) {
      if (!mounted) return;
      final eventType = data['event_type'] as String? ?? '';
      if (['fire_alarm', 'sos_alarm', 'fire_alarm_linked', 'global_alarm'].contains(eventType)) {
        final alarm = AlarmInfo.fromSecurityEvent(data);
        GlobalAlarmOverlay.show(context, ref, alarm);
      }
    });

    _incomingCallSub = RealtimeService().incomingCallEvents.listen((data) {
      if (!mounted) return;
      IncomingCallOverlay.show(context, ref, data);
    });

    _deviceStatusSub = RealtimeService().deviceStatusUpdates.listen((data) {
      if (!mounted) return;
      _fetchDevices();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检测用户切换，强制刷新状态
    final currentUserId = ref.read(authStateProvider).userId;
    if (_lastUserId != currentUserId) {
      _lastUserId = currentUserId;
      _resetState();
      _checkCheckinStatus();
    }
  }

  void _resetState() {
    setState(() {
      _isCheckedIn = false;
      _currentStay = null;
      _devices = [];
    });
    _mqttService.disconnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _mqttService.disconnect();
    _realtimeEventSub?.cancel();
    _securityEventSub?.cancel();
    _incomingCallSub?.cancel();
    _deviceStatusSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用从后台返回前台时，重新检测入住状态
    if (state == AppLifecycleState.resumed) {
      _checkCheckinStatus();
    }
  }

  Future<void> _checkCheckinStatus() async {
    setState(() => _isLoading = true);
    try {
      // 首先检查是否已入住
      final result = await ref.read(bookingServiceProvider).getMyCurrentStay();
      if (result.success && mounted) {
        final stay = result.data;
        if (stay != null) {
          setState(() {
            _isCheckedIn = true;
            _currentStay = stay;
          });
          _fetchDevices();
          _connectMqtt();
          return;
        }
      }

      // 检查是否有预入住状态的预订
      final preCheckinResult = await ref.read(bookingServiceProvider).getBookings(
        status: 'pre_checked_in',
        pageSize: 10,
      );
      if (preCheckinResult.success && mounted) {
        final preCheckinBookings = preCheckinResult.data ?? [];
        if (preCheckinBookings.isNotEmpty) {
          final booking = preCheckinBookings.first;
          setState(() {
            _isCheckedIn = false;
            _currentStay = null;
            _isLoading = false;
          });
          // 显示预入住状态提示
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('入住审核中'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending_actions, size: 64, color: AppColors.warning),
                  const SizedBox(height: 16),
                  Text('您的预订 ${booking.displayBookingNumber} 已提交预入住申请'),
                  const SizedBox(height: 8),
                  const Text('请等待前台核实信息后完成入住', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/');
                  },
                  child: const Text('返回首页'),
                ),
              ],
            ),
          );
          return;
        }
      }

      // 没有任何预订状态
      if (mounted) {
        setState(() {
          _isCheckedIn = false;
          _currentStay = null;
          _devices = [];
        });
        _mqttService.disconnect();
      }
    } catch (e) {
      debugPrint('检查入住状态错误: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectMqtt() async {
    await _mqttService.connect();
    if (_mqttService.isConnected) {
      _mqttService.subscribe(MqttConstants.deviceStatusWildcard);
      _mqttService.subscribe(MqttConstants.securityEventTopic);
      _mqttService.onMessage('hotel/device/status/', (message) {
        _fetchDevices();
      });
      _mqttService.onMessage('hotel/device/security/event', (message) {
        try {
          final data = jsonDecode(message) as Map<String, dynamic>;
          final eventType = data['event_type'] as String? ?? '';
          if (['fire_alarm', 'sos_alarm', 'fire_alarm_linked', 'global_alarm'].contains(eventType)) {
            final alarm = AlarmInfo.fromSecurityEvent(data);
            if (mounted) GlobalAlarmOverlay.show(context, ref, alarm);
          }
        } catch (e) {
          debugPrint('解析安防事件失败: $e');
        }
      });
    }
  }

  Future<void> _fetchDevices() async {
    try {
      final result = await ref.read(deviceServiceProvider).getMyRoomDevices();
      if (result.success) {
        setState(() => _devices = result.data ?? []);
      }
    } catch (e) {
      debugPrint('获取设备错误: $e');
    }
  }

  Future<void> _refreshData() async {
    // 重新检查入住状态并刷新设备列表
    await _checkCheckinStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已刷新'),
          duration: Duration(seconds: 1),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  IconData _getDeviceIcon(String? type) {
    switch (type) {
      case 'light':
        return Icons.light_mode_rounded;
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'curtain':
        return Icons.curtains_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'lock':
        return Icons.lock_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isCheckedIn) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('客房服务', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _checkCheckinStatus,
              tooltip: '刷新',
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hotel_outlined, size: 80, color: AppColors.textHint.withValues(alpha: 0.3)),
                const SizedBox(height: 24),
                const Text('您尚未入住', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                const Text('请先完成预订支付并办理入住后，\n即可使用客房服务功能。', style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.push('/online-checkin/0'),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('在线办理入住'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.push('/orders'),
                  child: const Text('查看我的订单'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final roomNumber = _currentStay?.roomNumber ?? _currentStay?.roomId.toString() ?? '-';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$roomNumber号房 · 客房服务', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: '刷新',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'AI管家'),
            Tab(text: '控制中心'),
            Tab(text: '客房送物'),
            Tab(text: '联系前台'),
            Tab(text: '更多服务'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: TabBarView(
          controller: _tabController,
          children: [
            _AiButlerTab(roomId: _currentStay?.roomId, bookingId: _currentStay?.id),
            _buildDeviceControlTab(),
            _DeliveryTab(roomId: _currentStay?.roomId, roomNumber: _currentStay?.roomNumber, currentStay: _currentStay),
            _ContactFrontDeskTab(roomId: _currentStay?.roomId),
            _MoreServicesTab(isCheckedIn: _currentStay != null, roomId: _currentStay?.roomId, currentStay: _currentStay),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceControlTab() {
    return RefreshIndicator(
      onRefresh: _checkCheckinStatus,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 智能场景预设
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('智能场景', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildSceneCard('欢迎模式', Icons.wb_sunny_rounded, Colors.orange, 'welcome'),
                            const SizedBox(width: 12),
                            _buildSceneCard('睡眠模式', Icons.bedtime_rounded, Colors.indigo, 'sleep'),
                            const SizedBox(width: 12),
                            _buildSceneCard('外出模式', Icons.exit_to_app_rounded, Colors.blueGrey, 'leave'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // 设备列表
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: const Text('所有设备', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                _devices.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyDevices())
                    : SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final device = _devices[index];
                              final deviceType = device['device_type'] ?? device['type'] ?? '未知';
                              final isOn = (device['device_status'] ?? device['status'] ?? 'off') == 'on' ||
                                  (device['device_status'] ?? device['status'] ?? 'off') == 'unlocked';
                              return _DeviceControlTile(
                                icon: _getDeviceIcon(deviceType),
                                name: device['device_name'] ?? '未知设备',
                                status: isOn ? '开启' : '关闭',
                                isOn: isOn,
                                onTap: () => _showDeviceControlPanel(device),
                              );
                            },
                            childCount: _devices.length,
                          ),
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _buildSceneCard(String title, IconData icon, Color color, String scene) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          // 通过 MQTT 发送场景命令，避免权限问题
          final roomNumber = _currentStay?.roomNumber ?? _currentStay?.roomId.toString();
          if (roomNumber == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请先办理入住'), backgroundColor: AppColors.error),
            );
            return;
          }

          // 构建场景命令
          final sceneCommand = {
            'type': 'scene',
            'scene': scene,
            'room_id': roomNumber,
            'timestamp': DateTime.now().toIso8601String(),
          };

          // 通过 MQTT 发布场景命令
          final mqttTopic = MqttConstants.sceneTopic(roomNumber);
          final mqttPayload = jsonEncode(sceneCommand);
          await _mqttService.publish(mqttTopic, mqttPayload);

          // 记录 MQTT 发送日志
          debugPrint('[智能场景] MQTT 命令已发送');
          debugPrint('[智能场景] 主题: $mqttTopic');
          debugPrint('[智能场景] 内容: $mqttPayload');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已激活 $title'), backgroundColor: color),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeviceControlPanel(Map<String, dynamic> device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeviceControlPanel(
        device: device,
        deviceService: ref.read(deviceServiceProvider),
        onCommandSent: _fetchDevices,
      ),
    );
  }

  Widget _buildEmptyDevices() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.devices_other_rounded,
                  size: 64,
                  color: AppColors.textHint.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('暂无房间设备',
                  style: GoogleFonts.notoSansSc(
                      fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(
                '您当前没有入住房间，或房间暂未配置智能设备',
                style: GoogleFonts.notoSansSc(
                    fontSize: 13, color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiButlerTab extends StatelessWidget {
  final int? roomId;
  final int? bookingId;
  const _AiButlerTab({this.roomId, this.bookingId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF30CFD0)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('AI智能管家', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('语音交互 · 智能建议 · 设备控制', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildFeatureChip(context, '💡', '灯光控制'),
                _buildFeatureChip(context, '🌡️', '空调调节'),
                _buildFeatureChip(context, '🧹', '保洁服务'),
                _buildFeatureChip(context, '🍽️', '客房送餐'),
                _buildFeatureChip(context, '📶', 'WiFi查询'),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.push('/ai-butler', extra: {'bookingId': bookingId, 'roomId': roomId}),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: const Text('开始对话', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _DeliveryTab extends ConsumerStatefulWidget {
  final dynamic roomId;
  final String? roomNumber;
  final Booking? currentStay;
  const _DeliveryTab({this.roomId, this.roomNumber, this.currentStay});
  @override
  ConsumerState<_DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends ConsumerState<_DeliveryTab> {
  String _selectedCategory = '饮品';
  final _noteController = TextEditingController();
  final Map<int, int> _quantities = {};

  // 分类映射表（英文 -> 中文）
  final Map<String, String> _categoryMap = {
    'beverage': '饮品',
    'food': '食品',
    'daily': '日用品',
    'other': '其他',
    '饮品': '饮品',
    '食品': '食品',
    '日用品': '日用品',
    '其他': '其他',
  };

  String _getCategoryDisplayName(String category) {
    return _categoryMap[category] ?? category;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = DeliveryService.deliveryItemCatalog
        .where((i) => i['category'] == _selectedCategory)
        .toList();
    final categories = DeliveryService.deliveryItemCatalog
        .map((i) => i['category'] as String)
        .toSet()
        .toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_getCategoryDisplayName(c)),
                          selected: _selectedCategory == c,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = c),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final itemId = item['id'] as int;
              final qty = _quantities[itemId] ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '¥${item['price']} · ${_getCategoryDisplayName(item['category'] as String)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (qty > 0) ...[
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20),
                              onPressed: () => setState(() {
                                _quantities[itemId] = qty - 1;
                                if (_quantities[itemId] == 0) {
                                  _quantities.remove(itemId);
                                }
                              }),
                            ),
                            Text('$qty',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                size: 20, color: AppColors.primary),
                            onPressed: () => setState(() {
                              _quantities[itemId] = qty + 1;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_quantities.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: '备注（可选）',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: _submitDelivery,
                    child: Text(
                        '提交送物请求 (${_quantities.values.fold(0, (a, b) => a + b)}件)'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _submitDelivery() async {
    final selectedItems = <Map<String, dynamic>>[];
    _quantities.forEach((id, qty) {
      final item = DeliveryService.deliveryItemCatalog
          .firstWhere((i) => i['id'] == id);
      selectedItems.add({
        'item_id': id,
        'name': item['name'],
        'category': item['category'],
        'price': item['price'],
        'quantity': qty,
      });
    });

    int successCount = 0;
    int failCount = 0;

    for (final item in selectedItems) {
      try {
        final orderData = <String, dynamic>{
          'room_id': widget.roomId,
          'booking_id': widget.currentStay?.id,
          'guest_id': widget.currentStay?.userId,
          'item_category': item['category'],
          'item_name': item['name'],
          'quantity': item['quantity'],
          'note': _noteController.text.trim(),
        };
        final result = await ref.read(deliveryServiceProvider).createDeliveryOrder(orderData);
        if (result.success) {
          successCount++;
          // 记录成功日志
          debugPrint('[客房服务] 送物订单创建成功 - 物品: ${item['name']}, 数量: ${item['quantity']}');
          debugPrint('[客房服务] 订单数据: $orderData');
        } else {
          failCount++;
          debugPrint('[客房服务] 送物订单创建失败 - 错误: ${result.message}');
        }
      } catch (e) {
        failCount++;
        debugPrint('[客房服务] 创建送物订单异常: $e');
      }
    }

    if (mounted) {
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已提交$successCount项送物请求，请稍候配送${failCount > 0 ? '，$failCount项失败' : ''}'),
            backgroundColor: failCount > 0 ? AppColors.warning : AppColors.success,
          ),
        );
        setState(() {
          _quantities.clear();
          _noteController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提交失败，请重试')),
        );
      }
    }
  }
}

class _ContactFrontDeskTab extends ConsumerStatefulWidget {
  final dynamic roomId;
  const _ContactFrontDeskTab({this.roomId});
  @override
  ConsumerState<_ContactFrontDeskTab> createState() =>
      _ContactFrontDeskTabState();
}

class _ContactFrontDeskTabState extends ConsumerState<_ContactFrontDeskTab> {
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final VoiceCallService _callService = VoiceCallService();
  bool _isOnline = false;
  String? _clientName;
  Map<String, dynamic>? _onlineStatus;
  StreamSubscription? _callEventSubscription;
  bool _inCall = false;
  bool _isCaller = false;
  bool _isReconnecting = false;
  String? _activeCallId;
  String _callDuration = '00:00';
  Timer? _callTimer;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _initCallService();
  }

  void _initCallService() {
    if (widget.roomId == null) {
      debugPrint('[联系前台] roomId为空，跳过初始化');
      return;
    }
    final clientId = '${widget.roomId}';
    debugPrint('[联系前台] 初始化呼叫服务, clientId: $clientId');
    _callService.init(clientId, clientType: 'room');
    _callEventSubscription = _callService.callEvents.listen((event) {
      if (!mounted) return;

      switch (event['type']) {
        case 'registered':
          setState(() {
            _isOnline = true;
            _isReconnecting = false;
            _clientName = event['data']?['clientName'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已上线${_clientName != null ? '：$_clientName' : ''}'),
              backgroundColor: AppColors.success,
            ),
          );
          _callService.requestOnlineStatus();
          break;
        case 'online_status':
          setState(() {
            _onlineStatus = event['data'];
          });
          break;
        case 'incoming_call':
          if (!_inCall) {
            _showIncomingCallDialog(event['data']);
          }
          break;
        case 'call_answered':
          Navigator.of(context).maybePop();
          setState(() {
            _inCall = true;
            _activeCallId = event['data']?['call_id'] ?? _callService.currentCallId;
            _callStartTime = DateTime.now();
          });
          _startCallTimer();
          if (_isCaller) {
            _callService.onCallAnswered(
              Map<String, dynamic>.from(event['data'] as Map),
            );
          }
          break;
        case 'call_rejected':
          Navigator.of(context).maybePop();
          _endCall();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('对方已拒接'), backgroundColor: AppColors.warning),
          );
          break;
        case 'call_hungup':
          Navigator.of(context).maybePop();
          _endCall();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('通话已结束')),
          );
          break;
        case 'call_reconnecting':
          setState(() => _isReconnecting = true);
          break;
        case 'call_error':
          final message = event['data']?['message'] ?? '呼叫失败';
          if (_isReconnecting) {
            setState(() => _isReconnecting = false);
          }
          Navigator.of(context).maybePop();
          if (_inCall) {
            _endCall();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.error),
          );
          break;
      }
    });
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callStartTime != null && mounted) {
        final diff = DateTime.now().difference(_callStartTime!);
        setState(() {
          _callDuration = '${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
        });
      }
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    setState(() {
      _inCall = false;
      _isCaller = false;
      _isReconnecting = false;
      _activeCallId = null;
      _callDuration = '00:00';
      _callStartTime = null;
    });
  }

  void _showIncomingCallDialog(Map<String, dynamic> callData) {
    final callerName = callData['caller_name'] ?? callData['caller_id'] ?? '未知';
    final callId = callData['call_id'];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              callerName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '正在呼叫您...',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _isCaller = false;
                      _callService.answerCall(
                        callId,
                        callData['caller_id'],
                        callData['caller_type'],
                      );
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('接听'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _callService.rejectCall(callId);
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.call_end_rounded),
                    label: const Text('拒绝'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleOnlineStatus() {
    if (_isOnline) {
      // 下线
      _callService.unregisterClient();
      setState(() {
        _isOnline = false;
        _clientName = null;
        _onlineStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已下线')),
      );
    } else {
      // 上线
      if (widget.roomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未检测到房间信息，无法上线'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      final clientId = '${widget.roomId}';
      debugPrint('[联系前台] 尝试上线, clientId: $clientId');
      _callService.init(clientId, clientType: 'room');
      _callService.registerClient(clientId);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _callEventSubscription?.cancel();
    _callTimer?.cancel();
    super.dispose();
  }

  Future<void> _makeCall() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先点击上线按钮'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // 呼叫所有前台：callee_type='front_desk', callee_id='all'
    _isCaller = true;
    _callService.startCall('all', 'front_desk');

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('正在呼叫前台...',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              const Text('请稍候，前台即将接听',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final callId = _callService.currentCallId;
                if (callId != null) {
                  _callService.hangup(callId);
                }
                Navigator.pop(ctx);
              },
              child: const Text('取消呼叫',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'text': text, 'isMe': true, 'time': DateTime.now()});
      _messageController.clear();
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': '收到您的消息，前台会尽快处理。如有紧急需求请直接拨打前台电话。',
            'isMe': false,
            'time': DateTime.now()
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_inCall) return _buildInCallView();

    final hotlines = [
      {'name': '前台', 'number': '0', 'icon': Icons.support_agent_rounded, 'color': AppColors.primary},
      {'name': '客房服务', 'number': '1', 'icon': Icons.room_service_rounded, 'color': AppColors.secondary},
      {'name': '紧急电话', 'number': '911', 'icon': Icons.emergency_rounded, 'color': AppColors.error},
    ];

    final onlineFrontDesk = _onlineStatus?['web']?.where((c) => c['type'] == 'front_desk')?.toList() ?? [];
    final onlineCount = onlineFrontDesk.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isOnline ? Icons.circle : Icons.circle_outlined,
                            size: 12,
                            color: _isOnline ? AppColors.success : AppColors.textHint,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isOnline ? '当前身份: ${_clientName ?? '已上线'}' : '当前状态: 未上线',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _isOnline ? AppColors.success : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (_isOnline && onlineCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '在线前台: $onlineCount人',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _toggleOnlineStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOnline ? Colors.white : AppColors.primary,
                      foregroundColor: _isOnline ? AppColors.error : Colors.white,
                      side: _isOnline ? const BorderSide(color: AppColors.error) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      minimumSize: const Size(100, 36),
                    ),
                    child: Text(_isOnline ? '注销' : '上线'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('服务热线', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: hotlines
                    .map((h) => Expanded(
                          child: GestureDetector(
                            onTap: () => _makeCall(),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: (h['color'] as Color).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: (h['color'] as Color).withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                children: [
                                  Icon(h['icon'] as IconData, color: h['color'] as Color, size: 24),
                                  const SizedBox(height: 6),
                                  Text(h['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final msg = _messages[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: msg['isMe'] ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: msg['isMe'] ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg['text'],
                            style: TextStyle(fontSize: 13, color: msg['isMe'] ? Colors.white : AppColors.textPrimary)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, size: 18),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInCallView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary.withValues(alpha: 0.05), AppColors.primary.withValues(alpha: 0.15)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_in_talk_rounded, size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            _isReconnecting ? '重新连接中...' : '通话中',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _isReconnecting ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(_callDuration, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: AppColors.primary, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 8),
          Text(
            _isReconnecting ? '网络不稳定，正在尝试恢复' : '前台',
            style: TextStyle(fontSize: 16, color: _isReconnecting ? AppColors.warning : AppColors.textSecondary),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCallActionButton(
                icon: _callService.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: _callService.isMuted ? '取消静音' : '静音',
                color: _callService.isMuted ? AppColors.error : AppColors.textSecondary,
                onTap: () {
                  _callService.toggleMute();
                  setState(() {});
                },
              ),
              const SizedBox(width: 40),
              _buildCallActionButton(
                icon: Icons.call_end_rounded,
                label: '挂断',
                color: AppColors.error,
                onTap: () {
                  final callId = _activeCallId ?? _callService.currentCallId;
                  if (callId != null) _callService.hangup(callId);
                  _endCall();
                },
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildCallActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _MoreServicesTab extends ConsumerStatefulWidget {
  final bool isCheckedIn;
  final dynamic roomId;
  final Booking? currentStay;
  const _MoreServicesTab({required this.isCheckedIn, this.roomId, this.currentStay});

  @override
  ConsumerState<_MoreServicesTab> createState() => _MoreServicesTabState();
}

class _MoreServicesTabState extends ConsumerState<_MoreServicesTab> {
  bool _maintenanceLoading = false;
  String _faultType = 'electric';
  String _faultDescription = '';
  String _priority = 'medium';

  bool _showDeliveryRecordsModal = false;
  bool _deliveryRecordsLoading = false;
  List<dynamic> _deliveryRecords = [];

  bool _showMaintenanceRecordsModal = false;
  bool _maintenanceRecordsLoading = false;
  List<dynamic> _maintenanceRecords = [];

  final Map<String, String> _faultTypeMap = {
    'electric': '电力/灯光',
    'water': '水路/卫浴',
    'ac': '空调/暖气',
    'network': '网络/电视',
    'other': '其他故障',
  };

  final Map<String, String> _priorityMap = {
    'low': '普通',
    'medium': '一般',
    'high': '紧急',
    'urgent': '特急',
  };

  final Map<String, Color> _priorityColorMap = {
    'low': AppColors.success,
    'medium': Colors.blue,
    'high': Colors.orange,
    'urgent': AppColors.error,
  };

  final Map<String, Color> _deliveryStatusColorMap = {
    'pending': Colors.orange,
    'delivering': Colors.blue,
    'completed': AppColors.success,
  };

  final Map<String, String> _deliveryStatusTextMap = {
    'pending': '待处理',
    'delivering': '配送中',
    'completed': '已完成',
  };

  final Map<String, Color> _maintenanceStatusColorMap = {
    'pending': Colors.orange,
    'assigned': Colors.blue,
    'processing': Colors.purple,
    'completed': AppColors.success,
  };

  final Map<String, String> _maintenanceStatusTextMap = {
    'pending': '待处理',
    'assigned': '已分配',
    'processing': '处理中',
    'completed': '已完成',
  };

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> services = [
      {'icon': '🚗', 'name': '叫车服务', 'desc': '预约出租车/专车'},
      {'icon': '🧺', 'name': '洗衣服务', 'desc': '衣物清洗熨烫'},
      {'icon': '⏰', 'name': '叫醒服务', 'desc': '定时叫醒'},
      {'icon': '🅿️', 'name': '停车服务', 'desc': '代客泊车'},
      {'icon': '🔧', 'name': '报修服务', 'desc': '设备故障报修'},
      {'icon': '📅', 'name': '续住申请', 'desc': '延长住宿时间'},
      {'icon': '📦', 'name': '我的配送', 'desc': '查看配送记录'},
      {'icon': '🔨', 'name': '我的报修', 'desc': '查看维修记录'},
    ];

    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final svc = services[index];
            return InkWell(
              onTap: widget.isCheckedIn ? () => _handleServiceTap(svc['name']!) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(svc['icon']!, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(svc['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(svc['desc']!, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          },
        ),
        if (!widget.isCheckedIn)
          Container(
            color: Colors.white.withValues(alpha: 0.6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  const Text('请先办理入住后再使用此服务', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.push('/online-checkin/0'),
                    child: const Text('立即办理'),
                  ),
                ],
              ),
            ),
          ),
        if (widget.isCheckedIn) ...[
           if (_showDeliveryRecordsModal) _buildDeliveryRecordsModal(),
           if (_showMaintenanceRecordsModal) _buildMaintenanceRecordsModal(),
         ],
      ],
    );
  }

  void _handleServiceTap(String serviceName) {
    switch (serviceName) {
      case '报修服务':
        _showMaintenanceModalDialog();
        break;
      case '我的配送':
        _showDeliveryRecords();
        break;
      case '我的报修':
        _showMaintenanceRecords();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已收到 $serviceName 请求，前台将尽快处理')));
    }
  }

  void _showMaintenanceModalDialog() {
    setState(() {
      _faultType = 'electric';
      _faultDescription = '';
      _priority = 'medium';
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              const Text('设施报修', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('故障类型', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _faultTypeMap.entries.map((e) => ChoiceChip(
                  label: Text(e.value),
                  selected: _faultType == e.key,
                  onSelected: (_) => setModalState(() => _faultType = e.key),
                )).toList(),
              ),
              const SizedBox(height: 16),
              const Text('故障描述', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '请详细描述故障情况...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => _faultDescription = v,
              ),
              const SizedBox(height: 16),
              const Text('紧急程度', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _priorityMap.entries.map((e) => ChoiceChip(
                  label: Text(e.value),
                  selected: _priority == e.key,
                  selectedColor: _priorityColorMap[e.key]?.withValues(alpha: 0.3),
                  onSelected: (_) => setModalState(() => _priority = e.key),
                )).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _maintenanceLoading ? null : () => _submitMaintenance(ctx),
                  child: _maintenanceLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('提交报修'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitMaintenance(BuildContext ctx) async {
    if (_faultDescription.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请描述故障情况')));
      return;
    }
    setState(() => _maintenanceLoading = true);
    try {
      final result = await ref.read(maintenanceServiceProvider).createMaintenanceTicket({
        'room_id': widget.roomId,
        'fault_type': _faultType,
        'fault_description': _faultDescription,
        'priority': _priority,
      });
      if (result.success) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('报修申请已提交，维修人员将尽快联系您'), backgroundColor: AppColors.success));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '提交失败'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交失败: $e'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _maintenanceLoading = false);
    }
  }

  Future<void> _showDeliveryRecords() async {
    setState(() {
      _showDeliveryRecordsModal = true;
      _deliveryRecordsLoading = true;
    });
    try {
      final result = await ref.read(deliveryServiceProvider).getDeliveryOrders(pageSize: 50);
      if (result.success) {
        setState(() => _deliveryRecords = result.data ?? []);
      }
    } catch (e) {
      debugPrint('获取配送记录失败: $e');
    } finally {
      setState(() => _deliveryRecordsLoading = false);
    }
  }

  Widget _buildDeliveryRecordsModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('我的配送记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showDeliveryRecordsModal = false)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _deliveryRecordsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _deliveryRecords.isEmpty
                        ? const Center(child: Text('暂无配送记录', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _deliveryRecords.length,
                            itemBuilder: (context, i) {
                              final record = _deliveryRecords[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(record['item_name'] ?? '未知物品'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('数量: ${record['quantity'] ?? 1}'),
                                      Text('时间: ${_formatDateTime(record['created_at'])}'),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (_deliveryStatusColorMap[record['status']] ?? Colors.grey).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _deliveryStatusTextMap[record['status']] ?? record['status'] ?? '未知',
                                      style: TextStyle(color: _deliveryStatusColorMap[record['status']], fontSize: 12),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMaintenanceRecords() async {
    setState(() {
      _showMaintenanceRecordsModal = true;
      _maintenanceRecordsLoading = true;
    });
    try {
      final result = await ref.read(maintenanceServiceProvider).getMaintenanceTickets(pageSize: 50);
      if (result.success) {
        setState(() => _maintenanceRecords = result.data ?? []);
      }
    } catch (e) {
      debugPrint('获取维修记录失败: $e');
    } finally {
      setState(() => _maintenanceRecordsLoading = false);
    }
  }

  Widget _buildMaintenanceRecordsModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('我的维修记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showMaintenanceRecordsModal = false)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _maintenanceRecordsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _maintenanceRecords.isEmpty
                        ? const Center(child: Text('暂无维修记录', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _maintenanceRecords.length,
                            itemBuilder: (context, i) {
                              final record = _maintenanceRecords[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(_faultTypeMap[record['fault_type']] ?? record['fault_type'] ?? '未知'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('描述: ${record['fault_description'] ?? '无'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                                      Text('时间: ${_formatDateTime(record['created_at'])}'),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (_maintenanceStatusColorMap[record['status']] ?? Colors.grey).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _maintenanceStatusTextMap[record['status']] ?? record['status'] ?? '未知',
                                          style: TextStyle(color: _maintenanceStatusColorMap[record['status']], fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (_priorityColorMap[record['priority']] ?? Colors.grey).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _priorityMap[record['priority']] ?? record['priority'] ?? '普通',
                                          style: TextStyle(color: _priorityColorMap[record['priority']], fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
    if (dateTime is String) {
      try {
        final dt = DateTime.parse(dateTime);
        final utc8 = DateUtils.toUtc8(dt);
        return '${utc8.month}/${utc8.day} ${utc8.hour.toString().padLeft(2, '0')}:${utc8.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return dateTime;
      }
    }
    return dateTime.toString();
  }
}

class _DeviceControlTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String status;
  final bool isOn;
  final VoidCallback? onTap;

  const _DeviceControlTile({
    required this.icon,
    required this.name,
    required this.status,
    required this.isOn,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.divider.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          if (isOn)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOn
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isOn ? AppColors.primary : AppColors.textHint,
                  size: 24),
            ),
            const SizedBox(height: 12),
            Text(name,
                style: GoogleFonts.notoSansSc(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(status,
                style: GoogleFonts.notoSansSc(
                    fontSize: 11,
                    color: isOn
                        ? AppColors.primary
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
