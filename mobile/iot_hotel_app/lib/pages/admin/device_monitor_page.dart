import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/device.dart';

class DeviceMonitorPage extends StatefulWidget {
  const DeviceMonitorPage({super.key});

  @override
  State<DeviceMonitorPage> createState() => _DeviceMonitorPageState();
}

class _DeviceMonitorPageState extends State<DeviceMonitorPage> {
  bool _isLoading = true;
  List<Device> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _devices = [
        Device(id: 1, deviceName: '主灯', deviceType: 'light', deviceCode: 'LIGHT_001', roomId: 101, isOnline: true, status: 'on'),
        Device(id: 2, deviceName: '空调', deviceType: 'ac', deviceCode: 'AC_001', roomId: 101, isOnline: true, status: 'on'),
        Device(id: 3, deviceName: '窗帘', deviceType: 'curtain', deviceCode: 'CURTAIN_001', roomId: 101, isOnline: true, status: 'off'),
        Device(id: 4, deviceName: '门锁', deviceType: 'lock', deviceCode: 'LOCK_001', roomId: 101, isOnline: true, status: 'locked'),
        Device(id: 5, deviceName: '温湿度传感器', deviceType: 'sensor', deviceCode: 'SENSOR_TEMP_001', roomId: 101, isOnline: true, status: 'normal'),
        Device(id: 6, deviceName: '主灯', deviceType: 'light', deviceCode: 'LIGHT_002', roomId: 102, isOnline: false, status: 'offline'),
        Device(id: 7, deviceName: '空调', deviceType: 'ac', deviceCode: 'AC_002', roomId: 102, isOnline: false, status: 'offline'),
        Device(id: 8, deviceName: '电视', deviceType: 'tv', deviceCode: 'TV_001', roomId: 201, isOnline: true, status: 'off'),
      ];
      _isLoading = false;
    });
  }

  Color getDeviceColor(Device d) {
    if (!d.isOnline) return AppColors.deviceOffline;
    switch (d.status) {
      case 'error': return AppColors.deviceError;
      case 'warning': return AppColors.deviceWarning;
      default: return AppColors.deviceOnline;
    }
  }

  String getDeviceStatusText(Device d) {
    if (!d.isOnline) return '离线';
    switch (d.status) {
      case 'on': return '运行中';
      case 'off': return '已关闭';
      case 'locked': return '已锁定';
      case 'unlocked': return '已解锁';
      case 'normal': return '正常';
      case 'error': return '异常';
      default: return d.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备监控')),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _devices.length,
                itemBuilder: (context, index) => _buildDeviceCard(_devices[index]),
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
            Text('${device.typeName} · ${device.roomId}号房', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                    onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('指令已发送'))); },
                    child: Text(device.status == 'on' || device.status == 'unlocked' ? '关闭${device.typeName}' : '打开${device.typeName}'),
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
