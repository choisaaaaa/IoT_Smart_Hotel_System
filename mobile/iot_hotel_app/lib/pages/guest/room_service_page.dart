import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/mqtt/mqtt_service.dart';
import '../../../services/device_service.dart';
import '../../../services/delivery_service.dart';
import '../../../services/voice_call_service.dart';
import '../../../services/booking_service.dart';

class RoomServicePage extends ConsumerStatefulWidget {
  const RoomServicePage({super.key});

  @override
  ConsumerState<RoomServicePage> createState() => _RoomServicePageState();
}

class _RoomServicePageState extends ConsumerState<RoomServicePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isCheckedIn = false;
  Map<String, dynamic>? _currentStay;
  List<dynamic> _devices = [];
  final MqttService _mqttService = MqttService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkCheckinStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mqttService.disconnect();
    super.dispose();
  }

  Future<void> _checkCheckinStatus() async {
    setState(() => _isLoading = true);
    try {
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
        }
      }
    } catch (e) {
      debugPrint('Error checking check-in status: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectMqtt() async {
    await _mqttService.connect();
    if (_mqttService.isConnected) {
      _mqttService.subscribe('hotel/room/+/status');
      _mqttService.onMessage('hotel/room/', (message) {
        _fetchDevices();
      });
    }
  }

  Future<void> _fetchDevices() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(deviceServiceProvider).getMyRoomDevices();
      if (result.success) {
        setState(() => _devices = result.data ?? []);
      }
    } catch (e) {
      debugPrint('Error fetching devices: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDevice(dynamic device) async {
    final currentStatus = device['device_status'] ?? device['status'] ?? 'off';
    final newStatus = currentStatus == 'on' ? 'off' : 'on';
    try {
      final result = await ref
          .read(deviceServiceProvider)
          .controlDevice(device['id'], 'toggle', newStatus);
      if (result.success) _fetchDevices();
    } catch (e) {
      debugPrint('Error toggling device: $e');
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
                  onPressed: () => context.push('/online-checkin'),
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

    final roomNumber = _currentStay?['room_number'] ?? _currentStay?['room_id']?.toString() ?? '-';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$roomNumber号房 · 客房服务', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.notoSansSc(
              fontSize: 14, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'AI管家'),
            Tab(text: '客房送物'),
            Tab(text: '联系前台'),
            Tab(text: '设备控制'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AiButlerTab(),
          _DeliveryTab(roomId: _currentStay?['room_id'], roomNumber: _currentStay?['room_number']?.toString(), currentStay: _currentStay),
          _ContactFrontDeskTab(roomId: _currentStay?['room_id']),
          _buildDeviceControlTab(),
        ],
      ),
    );
  }

  Widget _buildDeviceControlTab() {
    return RefreshIndicator(
      onRefresh: _fetchDevices,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? _buildEmptyDevices()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return _DeviceControlTile(
                      icon: _getDeviceIcon(device['device_type'] ?? device['type']),
                      name: device['device_name'] ?? '未知设备',
                      status: (device['device_status'] ?? device['status'] ?? 'off') == 'on' ? '开启' : '关闭',
                      isOn: (device['device_status'] ?? device['status'] ?? 'off') == 'on',
                      onTap: () => _toggleDevice(device),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyDevices() {
    return ListView(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
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
      ],
    );
  }
}

class _AiButlerTab extends StatefulWidget {
  @override
  State<_AiButlerTab> createState() => _AiButlerTabState();
}

class _AiButlerTabState extends State<_AiButlerTab> {
  final List<_ChatMessage> _messages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      isUser: false,
      text: '您好！我是AI智能管家，有什么可以帮您的吗？',
      time: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages
          .add(_ChatMessage(isUser: true, text: text, time: DateTime.now()));
    });
    _inputController.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 500), () {
      final response = _generateAiResponse(text);
      setState(() {
        _messages
            .add(_ChatMessage(isUser: false, text: response, time: DateTime.now()));
      });
      _scrollToBottom();
    });
  }

  String _generateAiResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('空调') || lower.contains('温度') || lower.contains('冷') || lower.contains('热')) {
      return '好的，我来帮您调节空调温度。请问您希望设定多少度？推荐24-26度最为舒适。您也可以在"设备控制"标签页直接操作空调开关和温度。';
    }
    if (lower.contains('送水') || lower.contains('矿泉水') || lower.contains('水')) {
      return '好的，我来帮您安排送水服务。请切换到"客房送物"标签页，选择饮品分类下的矿泉水即可下单，前台会尽快为您配送。';
    }
    if (lower.contains('毛巾') || lower.contains('送物') || lower.contains('配送')) {
      return '好的，请切换到"客房送物"标签页选择需要的物品，前台会尽快为您配送。';
    }
    if (lower.contains('几点') || lower.contains('时间') || lower.contains('现在')) {
      final now = DateTime.now();
      return '现在是${now.year}年${now.month}月${now.day}日 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}。';
    }
    if (lower.contains('天气')) {
      return '今天天气晴朗，气温适宜，非常适合出行。如需帮助叫车服务，请告诉我。';
    }
    if (lower.contains('续住') || lower.contains('延住') || lower.contains('多住')) {
      return '好的，续住需求已记录。请联系前台确认续住日期和费用，您可以在"联系前台"标签页直接拨打前台电话。';
    }
    if (lower.contains('退房') || lower.contains('离开')) {
      return '退房时间为中午12:00前。如需延迟退房，请联系前台确认。您可以在"联系前台"标签页与我们沟通。';
    }
    if (lower.contains('wifi') || lower.contains('网络') || lower.contains('上网')) {
      return '酒店WiFi名称为 SmartHotel-Guest，密码在房间桌面上的服务卡上。如遇网络问题，请联系前台。';
    }
    if (lower.contains('早餐') || lower.contains('吃饭') || lower.contains('餐厅')) {
      return '早餐时间为7:00-10:00，地点在一楼自助餐厅。金卡及以上会员可享受免费早餐。';
    }
    return '收到您的消息，我正在处理中。如需更详细的帮助，您可以通过"联系前台"标签页直接与我们沟通，或切换到"客房送物"标签页下单配送服务。';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quickQuestions = [
      '帮我打开空调',
      '送两瓶矿泉水',
      '现在几点了',
      '明天天气怎么样',
      '我想续住一晚',
      'WiFi密码是多少',
    ];

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: quickQuestions
                .map((q) => ActionChip(
                      label: Text(q, style: const TextStyle(fontSize: 11)),
                      onPressed: () => _sendMessage(q),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    hintText: '输入您的问题...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _sendMessage(_inputController.text),
                icon: const Icon(Icons.send, size: 18),
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? AppColors.primary
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight:
                      Radius.circular(msg.isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: msg.isUser ? Colors.white : AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.divider,
              child: Icon(Icons.person, size: 18, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool isUser;
  final String text;
  final DateTime time;
  _ChatMessage({required this.isUser, required this.text, required this.time});
}

class _DeliveryTab extends ConsumerStatefulWidget {
  final dynamic roomId;
  final String? roomNumber;
  final Map<String, dynamic>? currentStay;
  const _DeliveryTab({this.roomId, this.roomNumber, this.currentStay});
  @override
  ConsumerState<_DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends ConsumerState<_DeliveryTab> {
  String _selectedCategory = '饮品';
  final _noteController = TextEditingController();
  final Map<int, int> _quantities = {};

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
                          label: Text(c),
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
                              '¥${item['price']} · ${item['category']}',
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
          'booking_id': widget.currentStay?['id'],
          'guest_id': widget.currentStay?['user_id'],
          'item_category': item['category'],
          'item_name': item['name'],
          'quantity': item['quantity'],
          'note': _noteController.text.trim(),
        };
        final result = await ref.read(deliveryServiceProvider).createDeliveryOrder(orderData);
        if (result.success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
        debugPrint('Error creating delivery order: $e');
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
  List<Map<String, dynamic>> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _makeCall() async {
    try {
      final callService = VoiceCallService();
      callService.init('guest_app');
      callService.startCall('front_desk', 'staff');

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
                  callService.hangup('current');
                  ctx.pop();
                },
                child: const Text('取消呼叫',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
      }

      callService.callEvents.listen((event) {
        if (event['type'] == 'call_answered' && mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('前台已接听'),
                backgroundColor: AppColors.success),
          );
        } else if ((event['type'] == 'call_rejected' ||
                event['type'] == 'call_hungup') &&
            mounted) {
          Navigator.of(context).maybePop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('通话已结束')),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('呼叫失败：$e')),
        );
      }
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
    final hotlines = [
      {'name': '前台', 'number': '0', 'icon': Icons.support_agent_rounded, 'color': AppColors.primary},
      {'name': '客房服务', 'number': '1', 'icon': Icons.room_service_rounded, 'color': AppColors.secondary},
      {'name': '紧急电话', 'number': '911', 'icon': Icons.emergency_rounded, 'color': AppColors.error},
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('服务热线',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: hotlines
                    .map((h) => Expanded(
                          child: GestureDetector(
                            onTap: () => _makeCall(),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color:
                                    (h['color'] as Color)
                                        .withValues(alpha: 0.05),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: (h['color'] as Color)
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                children: [
                                  Icon(h['icon'] as IconData,
                                      color: h['color'] as Color,
                                      size: 24),
                                  const SizedBox(height: 6),
                                  Text(h['name'] as String,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w500)),
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
                  mainAxisAlignment: msg['isMe']
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: msg['isMe']
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg['text'],
                          style: TextStyle(
                            fontSize: 13,
                            color: msg['isMe']
                                ? Colors.white
                                : AppColors.textPrimary,
                          )),
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, size: 18),
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
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
