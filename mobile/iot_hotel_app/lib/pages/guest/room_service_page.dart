import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_router.dart';
import '../../../core/mqtt/mqtt_service.dart';

class RoomServicePage extends ConsumerStatefulWidget {
  const RoomServicePage({super.key});

  @override
  ConsumerState<RoomServicePage> createState() => _RoomServicePageState();
}

class _RoomServicePageState extends ConsumerState<RoomServicePage> {
  bool _isLoading = false;
  List<dynamic> _devices = [];
  final MqttService _mqttService = MqttService();

  @override
  void initState() {
    super.initState();
    _fetchDevices();
    _connectMqtt();
  }

  Future<void> _connectMqtt() async {
    await _mqttService.connect();
    if (_mqttService.isConnected) {
      // 订阅房间相关的主题，例如 'hotel/room/101/#'
      _mqttService.subscribe('hotel/room/+/status');
      _mqttService.onMessage('hotel/room/', (message) {
        // 处理实时状态更新
        _fetchDevices(); // 简单起见，收到消息就刷新列表
      });
    }
  }

  Future<void> _fetchDevices() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(deviceServiceProvider).getMyRoomDevices();
      if (result.success) {
        setState(() {
          _devices = result.data ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching devices: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDevice(dynamic device) async {
    final newStatus = device['status'] == 'on' ? 'off' : 'on';
    try {
      final result = await ref.read(deviceServiceProvider).controlDevice(
        device['id'],
        'toggle',
        newStatus,
      );
      if (result.success) {
        _fetchDevices();
      }
    } catch (e) {
      debugPrint('Error toggling device: $e');
    }
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('客房服务', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _mqttService.isConnected ? AppColors.success : AppColors.textHint),
            onPressed: _fetchDevices,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDevices,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildServiceCard(
              context,
              'AI 智能管家',
              '智能对话，快速响应您的需求',
              Icons.smart_toy_rounded,
              AppColors.primary,
              () {},
            ),
            _buildServiceCard(
              context,
              '客房送物',
              '毛巾、水、洗漱用品等物品配送',
              Icons.delivery_dining_rounded,
              AppColors.secondary,
              () {},
            ),
            _buildServiceCard(
              context,
              '联系前台',
              '一键拨打前台电话',
              Icons.support_agent_rounded,
              AppColors.info,
              () {},
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('房间设备控制', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _devices.isEmpty
                ? _buildStaticDeviceGrid()
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return _DeviceControlTile(
                        icon: _getDeviceIcon(device['type']),
                        name: device['device_name'] ?? '未知设备',
                        status: device['status'] == 'on' ? '开启' : '关闭',
                        isOn: device['status'] == 'on',
                        onTap: () => _toggleDevice(device),
                      );
                    },
                  ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String? type) {
    switch (type) {
      case 'light': return Icons.light_mode_rounded;
      case 'ac': return Icons.ac_unit_rounded;
      case 'curtain': return Icons.curtains_rounded;
      case 'tv': return Icons.tv_rounded;
      case 'lock': return Icons.lock_rounded;
      default: return Icons.devices_other_rounded;
    }
  }

  Widget _buildStaticDeviceGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: const [
        _DeviceControlTile(icon: Icons.light_mode_rounded, name: '灯光', status: '开启', isOn: true),
        _DeviceControlTile(icon: Icons.ac_unit_rounded, name: '空调', status: '24°C 制冷', isOn: true),
        _DeviceControlTile(icon: Icons.curtains_rounded, name: '窗帘', status: '关闭', isOn: false),
      ],
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.notoSansSc(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 18),
            ],
          ),
        ),
      ),
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
          color: isOn ? AppColors.primary.withValues(alpha: 0.1) : AppColors.divider.withValues(alpha: 0.5),
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
                color: isOn ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isOn ? AppColors.primary : AppColors.textHint,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: GoogleFonts.notoSansSc(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: GoogleFonts.notoSansSc(
                fontSize: 11,
                color: isOn ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
