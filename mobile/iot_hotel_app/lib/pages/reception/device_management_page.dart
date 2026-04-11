import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/device_service.dart';
import '../../services/room_service.dart';

class DeviceManagementPage extends ConsumerStatefulWidget {
  const DeviceManagementPage({super.key});

  @override
  ConsumerState<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends ConsumerState<DeviceManagementPage> {
  bool _isLoading = true;
  List<dynamic> _devices = [];
  List<dynamic> _rooms = [];
  int? _selectedRoomId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDevices(),
      _loadRooms(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadDevices() async {
    final result = await ref.read(deviceServiceProvider).getAllDevices(
          roomId: _selectedRoomId,
        );
    if (result.success && mounted) {
      setState(() => _devices = result.data ?? []);
    }
  }

  Future<void> _loadRooms() async {
    final result = await ref.read(roomServiceProvider).getRooms(pageSize: 100);
    if (result.success && mounted) {
      setState(() => _rooms = result.data ?? []);
    }
  }

  List<dynamic> get _filteredDevices {
    if (_searchQuery.isEmpty) return _devices;
    return _devices.where((d) {
      final name = (d['device_name'] ?? d['name'] ?? '').toString().toLowerCase();
      final type = (d['device_type'] ?? d['type'] ?? '').toString().toLowerCase();
      final room = (d['room_number'] ?? d['room_id']?.toString() ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || type.contains(query) || room.contains(query);
    }).toList();
  }

  Map<String, int> get _statusCounts {
    final counts = <String, int>{};
    for (final device in _devices) {
      final status = device['status']?.toString() ?? 'offline';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _toggleDevice(dynamic device) async {
    final currentStatus = device['status']?.toString() ?? 'off';
    final newStatus = currentStatus == 'on' ? 'off' : 'on';

    final result = await ref.read(deviceServiceProvider).controlDevice(
          device['id'],
          'toggle',
          newStatus,
        );

    if (result.success) {
      _loadDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设备已${newStatus == 'on' ? '开启' : '关闭'}')),
        );
      }
    }
  }

  Future<void> _sendCommand(dynamic device, String command, dynamic value) async {
    final result = await ref.read(deviceServiceProvider).controlDevice(
          device['id'],
          command,
          value,
        );

    if (result.success) {
      _loadDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('指令已发送')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusCounts = _statusCounts;

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
      ),
      body: Column(
        children: [
          _buildStatCards(statusCounts),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDevices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.devices_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? '暂无设备数据' : '未找到匹配的设备',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _filteredDevices[index];
                            return _DeviceCard(
                              device: device,
                              onToggle: () => _toggleDevice(device),
                              onCommand: (cmd, val) => _sendCommand(device, cmd, val),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(Map<String, int> counts) {
    final online = counts['online'] ?? 0;
    final offline = counts['offline'] ?? 0;
    final error = counts['error'] ?? 0;
    final total = _devices.length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: '在线',
              value: online.toString(),
              color: Colors.green,
              icon: Icons.check_circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '离线',
              value: offline.toString(),
              color: Colors.grey,
              icon: Icons.offline_bolt,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '异常',
              value: error.toString(),
              color: Colors.red,
              icon: Icons.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '总计',
              value: total.toString(),
              color: AppColors.primary,
              icon: Icons.devices,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: '搜索设备名称/类型/房间',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: '全部房间',
                  isSelected: _selectedRoomId == null,
                  onTap: () {
                    setState(() => _selectedRoomId = null);
                    _loadDevices();
                  },
                ),
                const SizedBox(width: 8),
                ..._rooms.map((room) {
                  final roomId = room['id'] as int;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: '${room['room_number']}号房',
                      isSelected: _selectedRoomId == roomId,
                      onTap: () {
                        setState(() => _selectedRoomId = roomId);
                        _loadDevices();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
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
            title,
            style: GoogleFonts.notoSansSc(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansSc(
            fontSize: 12,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final dynamic device;
  final VoidCallback onToggle;
  final Function(String, dynamic) onCommand;

  const _DeviceCard({
    required this.device,
    required this.onToggle,
    required this.onCommand,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = device['device_type'] ?? device['type'] ?? 'unknown';
    final deviceName = device['device_name'] ?? device['name'] ?? '未命名设备';
    final roomNumber = device['room_number'] ?? device['room_id'] ?? '-';
    final status = device['status']?.toString() ?? 'offline';
    final isOn = status == 'on' || status == 'online';

    IconData deviceIcon;
    Color deviceColor;

    switch (deviceType) {
      case 'light':
        deviceIcon = Icons.lightbulb;
        deviceColor = Colors.yellow;
        break;
      case 'ac':
      case 'air_conditioner':
        deviceIcon = Icons.ac_unit;
        deviceColor = Colors.blue;
        break;
      case 'curtain':
        deviceIcon = Icons.curtains;
        deviceColor = Colors.purple;
        break;
      case 'tv':
        deviceIcon = Icons.tv;
        deviceColor = Colors.cyan;
        break;
      case 'lock':
        deviceIcon = Icons.lock;
        deviceColor = Colors.green;
        break;
      case 'thermostat':
        deviceIcon = Icons.thermostat;
        deviceColor = Colors.orange;
        break;
      default:
        deviceIcon = Icons.devices_other;
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: deviceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(deviceIcon, color: deviceColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.room, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '$roomNumber号房',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOn ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOn ? '开启' : '关闭',
                            style: TextStyle(
                              color: isOn ? Colors.green : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOn,
                onChanged: (_) => onToggle(),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (_hasControls(deviceType)) ...[
            const Divider(height: 24),
            _buildDeviceControls(deviceType, device),
          ],
        ],
      ),
    );
  }

  bool _hasControls(String deviceType) {
    return ['ac', 'air_conditioner', 'thermostat', 'curtain', 'light'].contains(deviceType);
  }

  Widget _buildDeviceControls(String deviceType, dynamic device) {
    switch (deviceType) {
      case 'ac':
      case 'air_conditioner':
      case 'thermostat':
        return _buildTemperatureControls(device);
      case 'curtain':
        return _buildCurtainControls(device);
      case 'light':
        return _buildLightControls(device);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTemperatureControls(dynamic device) {
    final currentTemp = device['current_temperature'] ?? device['temperature'] ?? 24;
    final targetTemp = device['target_temperature'] ?? device['set_temperature'] ?? 24;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => onCommand('temperature', targetTemp - 1),
        ),
        Column(
          children: [
            Text(
              '${targetTemp.toInt()}°C',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '当前 ${currentTemp.toInt()}°C',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onCommand('temperature', targetTemp + 1),
        ),
      ],
    );
  }

  Widget _buildCurtainControls(dynamic device) {
    final position = device['position'] ?? device['curtain_position'] ?? 0;

    return Column(
      children: [
        Slider(
          value: position.toDouble(),
          min: 0,
          max: 100,
          divisions: 10,
          label: '${position.toInt()}%',
          onChanged: (value) {},
          onChangeEnd: (value) => onCommand('position', value.toInt()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => onCommand('position', 0),
              icon: const Icon(Icons.vertical_align_bottom, size: 18),
              label: const Text('关闭'),
            ),
            TextButton.icon(
              onPressed: () => onCommand('position', 50),
              icon: const Icon(Icons.drag_handle, size: 18),
              label: const Text('半开'),
            ),
            TextButton.icon(
              onPressed: () => onCommand('position', 100),
              icon: const Icon(Icons.vertical_align_top, size: 18),
              label: const Text('全开'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLightControls(dynamic device) {
    final brightness = device['brightness'] ?? 100;

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.brightness_low, size: 18, color: Colors.grey[500]),
            Expanded(
              child: Slider(
                value: brightness.toDouble(),
                min: 0,
                max: 100,
                divisions: 10,
                label: '${brightness.toInt()}%',
                onChanged: (value) {},
                onChangeEnd: (value) => onCommand('brightness', value.toInt()),
              ),
            ),
            Icon(Icons.brightness_high, size: 18, color: Colors.grey[500]),
          ],
        ),
      ],
    );
  }
}
