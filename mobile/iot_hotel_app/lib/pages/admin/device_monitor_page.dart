import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/device.dart';
import '../../../services/device_service.dart';

class DeviceMonitorPage extends ConsumerStatefulWidget {
  const DeviceMonitorPage({super.key});

  @override
  ConsumerState<DeviceMonitorPage> createState() => _DeviceMonitorPageState();
}

class _DeviceMonitorPageState extends ConsumerState<DeviceMonitorPage> {
  bool _isLoading = true;
  List<dynamic> _devices = [];
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(deviceServiceProvider).getMyRoomDevices();
      if (result.success && mounted) {
        final List<dynamic> deviceList = result.data ?? [];
        setState(() {
          _devices = deviceList.map((d) => Device(
            id: d['id'] ?? 0,
            deviceId: d['device_id']?.toString() ?? d['id']?.toString() ?? '',
            deviceName: d['device_name'] ?? '未知设备',
            deviceType: d['type'] ?? d['device_type'] ?? 'unknown',
            deviceKey: d['device_key'] ?? d['device_code'] ?? '',
            deviceStatus: d['device_status'] ?? d['status'] ?? 'offline',
          )).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载设备失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Device> get filteredDevices {
    if (_filterStatus == null || _filterStatus == 'all') return _devices.cast<Device>();
    if (_filterStatus == 'online') return _devices.where((d) => (d as Device).isOnline).cast<Device>().toList();
    if (_filterStatus == 'offline') return _devices.where((d) => !(d as Device).isOnline).cast<Device>().toList();
    return _devices.where((d) => (d as Device).deviceStatus == _filterStatus).cast<Device>().toList();
  }

  Color getDeviceColor(Device d) {
    if (!d.isOnline) return AppColors.deviceOffline;
    switch (d.deviceStatus) {
      case 'error': return AppColors.deviceError;
      case 'warning': return AppColors.deviceWarning;
      default: return AppColors.deviceOnline;
    }
  }

  String getDeviceStatusText(Device d) {
    if (!d.isOnline) return '离线';
    switch (d.deviceStatus) {
      case 'on': return '运行中';
      case 'off': return '已关闭';
      case 'locked': return '已锁定';
      case 'unlocked': return '已解锁';
      case 'normal': return '正常';
      case 'error': return '异常';
      default: return d.deviceStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备监控'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(label: const Text('全部'), selected: _filterStatus == null || _filterStatus == 'all', onSelected: (_) => setState(() => _filterStatus = 'all')),
                FilterChip(label: const Text('在线'), selected: _filterStatus == 'online', onSelected: (_) => setState(() => _filterStatus = 'online')),
                FilterChip(label: const Text('离线'), selected: _filterStatus == 'offline', onSelected: (_) => setState(() => _filterStatus = 'offline')),
                FilterChip(label: const Text('异常'), selected: _filterStatus == 'error', onSelected: (_) => setState(() => _filterStatus = 'error')),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredDevices.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.devices_other, size: 64, color: AppColors.textHint.withValues(alpha: 0.3)), const SizedBox(height: 16), Text('暂无设备数据', style: TextStyle(color: AppColors.textSecondary))]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDevices.length,
                    itemBuilder: (context, index) => _buildDeviceCard(filteredDevices[index]),
                  ),
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: getDeviceColor(device).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(device.typeIcon, style: const TextStyle(fontSize: 24))),
        ),
        title: Text(device.deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${device.typeName} · ${device.deviceId}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: getDeviceColor(device).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(getDeviceStatusText(device), style: TextStyle(fontSize: 11, color: getDeviceColor(device))),
            ),
          ],
        ),
        trailing: device.isOnline ? IconButton(
          icon: Icon(Icons.settings_remote, color: AppColors.primary),
          onPressed: () => _showControlDialog(device),
        ) : null,
      ),
    );
  }

  void _showControlDialog(Device device) {
    showModalBottomSheet(context: context, builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Text(device.typeIcon, style: const TextStyle(fontSize: 32)), const SizedBox(width: 12), Text(device.deviceName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
              const Divider(height: 32),
              if (device.deviceType == 'light' || device.deviceType == 'ac' || device.deviceType == 'curtain' || device.deviceType == 'tv')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () async {
                      Navigator.pop(context);
                      final newStatus = device.deviceStatus == 'on' ? 'off' : 'on';
                      try {
                        final result = await ref.read(deviceServiceProvider).controlDevice(device.id, 'toggle', newStatus);
                        if (result.success) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('指令发送成功')));
                          _loadDevices();
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
                      }
                    },
                    child: Text(device.deviceStatus == 'on' || device.deviceStatus == 'unlocked' ? '关闭${device.typeName}' : '打开${device.typeName}'),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('取消'))),
            ],
          ),
        ),
      );
    });
  }
}
