import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/room_service.dart';
import '../../services/floor_service.dart';
import '../../services/maintenance_service.dart';

class RoomAvailabilityPage extends ConsumerStatefulWidget {
  const RoomAvailabilityPage({super.key});

  @override
  ConsumerState<RoomAvailabilityPage> createState() => _RoomAvailabilityPageState();
}

class _RoomAvailabilityPageState extends ConsumerState<RoomAvailabilityPage> {
  bool _isLoading = false;
  List<dynamic> _rooms = [];
  List<dynamic> _floors = [];
  String _filterFloor = '';
  String _filterStatus = '';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadRooms(),
      _loadFloors(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadRooms() async {
    final result = await ref.read(roomServiceProvider).getRooms(
          status: _filterStatus.isEmpty ? null : _filterStatus,
          floor: _filterFloor.isEmpty ? null : _filterFloor,
          pageSize: 200,
        );
    if (result.success && mounted) {
      setState(() => _rooms = result.data ?? []);
    }
  }

  Future<void> _loadFloors() async {
    final result = await ref.read(floorServiceProvider).getFloors();
    if (result.success && mounted) {
      setState(() => _floors = result.data ?? []);
    }
  }

  Map<String, int> get _statusCounts {
    final counts = <String, int>{};
    for (final room in _rooms) {
      final status = room['room_status']?.toString() ?? room['status']?.toString() ?? 'available';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.roomAvailable;
      case 'occupied':
        return AppColors.roomOccupied;
      case 'cleaning':
        return AppColors.roomCleaning;
      case 'maintenance':
        return AppColors.roomMaintenance;
      case 'reserved':
        return Colors.orange;
      default:
        return AppColors.textHint;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'available':
        return '空闲';
      case 'occupied':
        return '已住';
      case 'cleaning':
        return '清洁中';
      case 'maintenance':
        return '维修中';
      case 'reserved':
        return '已预订';
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle;
      case 'occupied':
        return Icons.person;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'maintenance':
        return Icons.build;
      case 'reserved':
        return Icons.bookmark;
      default:
        return Icons.help;
    }
  }

  List<Map<String, dynamic>> get _groupedRooms {
    final groups = <String, List<dynamic>>{};
    for (final room in _rooms) {
      final floor = room['floor']?.toString() ?? '未知楼层';
      groups.putIfAbsent(floor, () => []).add(room);
    }

    // Sort floors numerically
    final sortedFloors = groups.keys.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a) ?? 0;
        final bNum = int.tryParse(b) ?? 0;
        return bNum.compareTo(aNum); // Descending order
      });

    return sortedFloors.map((floor) => {
      'floor': floor,
      'rooms': groups[floor]!,
    }).toList();
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
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          _buildStatusLegend(statusCounts),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rooms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hotel_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('暂无房间数据', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: _isGridView
                            ? _buildGridView()
                            : _buildListView(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Floor filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: '全部楼层',
                  isSelected: _filterFloor.isEmpty,
                  onTap: () {
                    setState(() => _filterFloor = '');
                    _loadRooms();
                  },
                ),
                const SizedBox(width: 8),
                ..._floors.map((floor) {
                  final floorNum = floor['floor']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: '$floorNum层',
                      isSelected: _filterFloor == floorNum,
                      onTap: () {
                        setState(() => _filterFloor = floorNum);
                        _loadRooms();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Status filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: '全部状态',
                  isSelected: _filterStatus.isEmpty,
                  onTap: () {
                    setState(() => _filterStatus = '');
                    _loadRooms();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '空闲',
                  isSelected: _filterStatus == 'available',
                  color: AppColors.roomAvailable,
                  onTap: () {
                    setState(() => _filterStatus = _filterStatus == 'available' ? '' : 'available');
                    _loadRooms();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '已住',
                  isSelected: _filterStatus == 'occupied',
                  color: AppColors.roomOccupied,
                  onTap: () {
                    setState(() => _filterStatus = _filterStatus == 'occupied' ? '' : 'occupied');
                    _loadRooms();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '清洁中',
                  isSelected: _filterStatus == 'cleaning',
                  color: AppColors.roomCleaning,
                  onTap: () {
                    setState(() => _filterStatus = _filterStatus == 'cleaning' ? '' : 'cleaning');
                    _loadRooms();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '维修中',
                  isSelected: _filterStatus == 'maintenance',
                  color: AppColors.roomMaintenance,
                  onTap: () {
                    setState(() => _filterStatus = _filterStatus == 'maintenance' ? '' : 'maintenance');
                    _loadRooms();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend(Map<String, int> counts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _LegendItem(
              color: AppColors.roomAvailable,
              label: '空闲',
              count: counts['available'] ?? 0,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: AppColors.roomOccupied,
              label: '已住',
              count: counts['occupied'] ?? 0,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: AppColors.roomCleaning,
              label: '清洁中',
              count: counts['cleaning'] ?? 0,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: AppColors.roomMaintenance,
              label: '维修中',
              count: counts['maintenance'] ?? 0,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: Colors.orange,
              label: '已预订',
              count: counts['reserved'] ?? 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView() {
    final groupedRooms = _groupedRooms;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedRooms.length,
      itemBuilder: (context, index) {
        final group = groupedRooms[index];
        final floor = group['floor'] as String;
        final rooms = group['rooms'] as List<dynamic>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$floor层',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${rooms.length}间',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: rooms.length,
              itemBuilder: (context, roomIndex) {
                final room = rooms[roomIndex];
                return _RoomGridCard(
                  room: room,
                  statusColor: _statusColor(room['room_status']?.toString() ??
                      room['status']?.toString() ??
                      'available'),
                  onTap: () => _showRoomDetail(room),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        final status = room['room_status']?.toString() ??
            room['status']?.toString() ??
            'available';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(status).withValues(alpha: 0.1),
              child: Icon(
                _statusIcon(status),
                color: _statusColor(status),
                size: 20,
              ),
            ),
            title: Text(
              '${room['room_number']}号房',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${room['room_name'] ?? room['room_type'] ?? '标准间'} · ${room['floor'] ?? '-'}层',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _statusText(status),
                style: TextStyle(
                  color: _statusColor(status),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            onTap: () => _showRoomDetail(room),
          ),
        );
      },
    );
  }

  void _showRoomDetail(Map<String, dynamic> room) {
    final status = room['room_status']?.toString() ??
        room['status']?.toString() ??
        'available';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${room['room_number']}号房',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusText(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow('房型', room['room_name'] ?? room['room_type'] ?? '标准间'),
            _buildDetailRow('楼层', '${room['floor'] ?? '-'}层'),
            _buildDetailRow('面积', '${room['area'] ?? '-'}㎡'),
            _buildDetailRow('床型', room['bed_type'] ?? '-'),
            _buildDetailRow('最大入住', '${room['max_guests'] ?? 2}人'),
            const SizedBox(height: 20),
            if (status != 'maintenance')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _reportMaintenance(room),
                  icon: const Icon(Icons.build, size: 18),
                  label: const Text('报修'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (status != 'maintenance') const SizedBox(height: 16),
            const Text(
              '修改房间状态',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                'available',
                'occupied',
                'reserved',
                'cleaning',
                'maintenance',
              ].map((s) => ChoiceChip(
                label: Text(_statusText(s)),
                selected: status == s,
                selectedColor: _statusColor(s).withValues(alpha: 0.2),
                onSelected: status == s
                    ? null
                    : (_) => _updateRoomStatus(room, s),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRoomStatus(Map<String, dynamic> room, String newStatus) async {
    final roomId = room['id'] as int?;
    if (roomId == null) return;

    final currentStatus = room['room_status']?.toString() ??
        room['status']?.toString() ??
        'available';

    if ((currentStatus == 'reserved' || currentStatus == 'occupied') &&
        newStatus == 'available') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认释放房间'),
          content: Text(
            '${room['room_number']}号房当前状态为${_statusText(currentStatus)}，确定要释放为空闲吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认释放'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final result = await ref
          .read(roomServiceProvider)
          .updateRoomStatus(roomId, newStatus);
      if (result.success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('房间状态已更新')),
        );
        _loadRooms();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '更新失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请重试')),
        );
      }
    }
  }

  Future<void> _reportMaintenance(Map<String, dynamic> room) async {
    final roomId = room['id'] as int?;
    if (roomId == null) return;

    try {
      final result = await ref.read(maintenanceServiceProvider).createWorkOrder({
        'room_id': roomId,
        'fault_type': '设备故障',
        'fault_description': '${room['room_number']}房间需要维修',
        'priority': 'medium',
      });
      if (result.success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('报修工单已创建，房间状态已更新为维修中')),
        );
        _loadRooms();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '创建报修工单失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请重试')),
        );
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? bgColor : Colors.grey[300]!,
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _RoomGridCard extends StatelessWidget {
  final dynamic room;
  final Color statusColor;
  final VoidCallback onTap;

  const _RoomGridCard({
    required this.room,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${room['room_number']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              room['room_name']?.toString().substring(0,
                  room['room_name'].toString().length > 4 ? 4 : room['room_name'].toString().length) ??
                  '',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
