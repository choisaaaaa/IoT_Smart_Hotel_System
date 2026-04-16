import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_result.dart';
import '../../services/floor_service.dart';
import '../../services/room_service.dart';

class FloorManagePage extends ConsumerStatefulWidget {
  const FloorManagePage({super.key});

  @override
  ConsumerState<FloorManagePage> createState() => _FloorManagePageState();
}

class _FloorManagePageState extends ConsumerState<FloorManagePage> {
  bool _isLoading = true;
  List<dynamic> _floors = [];
  List<dynamic> _rooms = [];
  int? _selectedFloorId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadFloors(),
      _loadRooms(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadFloors() async {
    final result = await ref.read(floorServiceProvider).getFloors();
    if (result.success && mounted) {
      setState(() => _floors = result.data ?? []);
    }
  }

  Future<void> _loadRooms() async {
    final result = await ref.read(roomServiceProvider).getRooms(pageSize: 200);
    if (result.success && mounted) {
      setState(() => _rooms = result.data ?? []);
    }
  }

  List<dynamic> get _roomsOnSelectedFloor {
    if (_selectedFloorId == null) return [];
    final selectedFloor = _floors.firstWhere(
      (f) => f['id'] == _selectedFloorId,
      orElse: () => {'floor_number': null},
    );
    final floorNumber = selectedFloor['floor_number']?.toString() ?? selectedFloor['floor']?.toString();
    if (floorNumber == null) return [];
    return _rooms.where((r) {
      final roomFloor = r['floor']?.toString() ?? r['floor_number']?.toString();
      return roomFloor == floorNumber;
    }).toList();
  }

  Future<void> _deleteFloor(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除楼层后，该楼层的房间将变为未分配状态。确定要删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ref.read(floorServiceProvider).deleteFloor(id);
      if (result.success) {
        _loadFloors();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('楼层已删除')),
          );
        }
      }
    }
  }

  void _showEditDialog(Map<String, dynamic>? floor) {
    final isEdit = floor != null;
    final floorController = TextEditingController(
      text: floor?['floor_number']?.toString() ?? floor?['floor']?.toString() ?? '',
    );
    final nameController = TextEditingController(text: floor?['floor_name'] ?? floor?['name'] ?? '');
    final descriptionController = TextEditingController(
      text: floor?['description'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? '编辑楼层' : '新增楼层',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: floorController,
                  decoration: const InputDecoration(
                    labelText: '楼层编号 *',
                    hintText: '如：1, 2, 3',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '楼层名称',
                    hintText: '如：大堂层、商务层',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '楼层描述',
                    hintText: '楼层特色、设施等描述',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final data = {
                      'floor_number': int.tryParse(floorController.text) ?? 1,
                      'floor_name': nameController.text.isEmpty ? null : nameController.text,
                      'description': descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                    };

                    ApiResult result;
                    if (isEdit) {
                      result = await ref.read(floorServiceProvider).updateFloor(
                        floor['id'],
                        data,
                      );
                    } else {
                      result = await ref.read(floorServiceProvider).createFloor(data);
                    }

                    if (result.success) {
                      _loadFloors();
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEdit ? '楼层已更新' : '楼层已创建')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(isEdit ? '保存修改' : '创建楼层'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('楼层管理', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Row(
        children: [
          // Floor List Sidebar
          Container(
            width: 120,
            color: Colors.white,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _floors.length,
                    itemBuilder: (context, index) {
                      final floor = _floors[index];
                      final isSelected = _selectedFloorId == floor['id'];
                      final floorNum = floor['floor_number'] ?? floor['floor'];
                      final floorName = floor['floor_name'] ?? floor['name'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFloorId = floor['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${floorNum}层',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (floorName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  floorName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Colors.white70 : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Floor Detail
          Expanded(
            child: _selectedFloorId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.layers_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('请选择楼层', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : _buildFloorDetail(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(null),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('新增楼层'),
      ),
    );
  }

  Widget _buildFloorDetail() {
    final floor = _floors.firstWhere(
      (f) => f['id'] == _selectedFloorId,
      orElse: () => {},
    );
    final rooms = _roomsOnSelectedFloor;
    final floorNum = floor['floor_number'] ?? floor['floor'];
    final floorName = floor['floor_name'] ?? floor['name'];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Floor Info Card
            Container(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${floorNum}层',
                            style: GoogleFonts.notoSansSc(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (floorName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              floorName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditDialog(floor),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteFloor(floor['id']),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (floor['description'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      floor['description'],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Room Stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: '房间总数',
                    value: rooms.length.toString(),
                    icon: Icons.hotel,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: '已入住',
                    value: rooms.where((r) => r['status'] == 'occupied').length.toString(),
                    icon: Icons.person,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: '空闲',
                    value: rooms.where((r) => r['status'] == 'available').length.toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Room List
            Text(
              '房间列表',
              style: GoogleFonts.notoSansSc(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (rooms.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    '该楼层暂无房间',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rooms.map((room) {
                  return _RoomChip(room: room);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
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

class _RoomChip extends StatelessWidget {
  final dynamic room;

  const _RoomChip({required this.room});

  @override
  Widget build(BuildContext context) {
    final status = room['status']?.toString() ?? 'available';
    Color statusColor;
    switch (status) {
      case 'available':
        statusColor = Colors.green;
        break;
      case 'occupied':
        statusColor = Colors.orange;
        break;
      case 'cleaning':
        statusColor = Colors.blue;
        break;
      case 'maintenance':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            room['room_number']?.toString() ?? '-',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
