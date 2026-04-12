import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/room_service.dart';
import '../../../services/room_type_service.dart';
import '../../../services/floor_service.dart';

class RoomManagePage extends ConsumerStatefulWidget {
  const RoomManagePage({super.key});

  @override
  ConsumerState<RoomManagePage> createState() => _RoomManagePageState();
}

class _RoomManagePageState extends ConsumerState<RoomManagePage> {
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(roomServiceProvider).getRooms(status: _filterStatus == 'all' ? null : _filterStatus);
      if (result.success && mounted) {
        final List<dynamic> roomList = result.data ?? [];
        setState(() {
          _rooms = roomList.map((r) => {
            'id': r['id'] ?? 0,
            'number': r['room_number']?.toString() ?? '',
            'type': r['room_type'] ?? '标准间',
            'floor': r['floor'] ?? 1,
            'status': r['room_status'] ?? r['status'] ?? 'available',
            'price': r['room_price'] ?? r['price'] ?? 0,
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('✗ rooms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加载房间失败')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'available': return AppColors.roomAvailable;
      case 'occupied': return AppColors.roomOccupied;
      case 'cleaning': return AppColors.roomCleaning;
      case 'maintenance': return AppColors.roomMaintenance;
      case 'reserved': return AppColors.roomReserved;
      default: return AppColors.textSecondary;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'available': return '空闲';
      case 'occupied': return '已住';
      case 'cleaning': return '清洁中';
      case 'maintenance': return '维修中';
      case 'reserved': return '已预订';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('房间管理')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['all', 'available', 'occupied', 'cleaning', 'maintenance', 'reserved'].map((s) {
                final isSelected = _filterStatus == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s == 'all' ? '全部' : getStatusText(s)),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withAlpha(50),
                    checkmarkColor: AppColors.primary,
                    onSelected: (_) => setState(() { _filterStatus = s; _loadRooms(); }),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rooms.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.door_back_door, size: 64, color: AppColors.textHint.withValues(alpha: 0.3)), const SizedBox(height: 16), Text('暂无房间数据', style: TextStyle(color: AppColors.textSecondary))]))
                    : RefreshIndicator(
                        onRefresh: _loadRooms,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
                          itemCount: _rooms.length,
                          itemBuilder: (context, index) => _buildRoomCard(_rooms[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRoomDialog(),
        icon: const Icon(Icons.add),
        label: const Text('添加房间'),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showRoomDetail(room),
        onLongPress: () => _showRoomOptions(room),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${room['number']}号房', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: getStatusColor(room['status']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(getStatusText(room['status']), style: TextStyle(fontSize: 11, color: getStatusColor(room['status']), fontWeight: FontWeight.w600))),
              ]),
              const Spacer(),
              Text(room['type'], style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('${room['floor']}F · ¥${room['price']}/晚', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomDetail(Map<String, dynamic> room) {
    showModalBottomSheet(context: context, builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${room['number']}号房详情', style: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(height: 32),
              _buildInfoRow('房型', room['type']),
              _buildInfoRow('楼层', '${room['floor']}F'),
              _buildInfoRow('价格', '¥${room['price']}/晚'),
              _buildInfoRow('状态', getStatusText(room['status'])),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _showEditRoomDialog(room), child: const Text('编辑'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => _confirmDeleteRoom(room), child: const Text('删除'))),
              ]),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [SizedBox(width: 60, child: Text(label, style: TextStyle(color: AppColors.textSecondary))), Text(value, style: const TextStyle(fontWeight: FontWeight.w500))]));
  }

  void _showRoomOptions(Map<String, dynamic> room) {
    showModalBottomSheet(context: context, builder: (ctx) {
      return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.edit), title: const Text('编辑房间'), onTap: () { Navigator.pop(ctx); _showEditRoomDialog(room); }),
        ListTile(
          leading: const Icon(Icons.delete, color: AppColors.error),
          title: const Text('删除房间', style: TextStyle(color: AppColors.error)),
          onTap: () { Navigator.pop(ctx); _confirmDeleteRoom(room); },
        ),
      ]));
    });
  }

  void _showAddRoomDialog() async {
    final numberController = TextEditingController();
    final priceController = TextEditingController(text: '388');
    int? selectedRoomTypeId;
    int? selectedFloorId;
    List<dynamic> roomTypes = [];
    List<dynamic> floors = [];

    try {
      final rtResult = await ref.read(roomTypeServiceProvider).getRoomTypes();
      if (rtResult.success) roomTypes = rtResult.data ?? [];
      final fResult = await ref.read(floorServiceProvider).getFloors();
      if (fResult.success) floors = fResult.data ?? [];
    } catch (e) {
      debugPrint('鉁?roomTypesFloors: $e');
    }

    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Text('添加房间'),
      content: Form(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: numberController, decoration: const InputDecoration(labelText: '房间号 *'), validator: (v) => v!.isEmpty ? '请输入房间号' : null),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: '房型 *'),
          items: roomTypes.map<DropdownMenuItem<int>>((rt) => DropdownMenuItem(value: rt['id'] as int, child: Text(rt['name'] ?? rt['type_name'] ?? '房型${rt['id']}'))).toList(),
          initialValue: selectedRoomTypeId,
          onChanged: (v) => setDialogState(() => selectedRoomTypeId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: '楼层 *'),
          items: floors.map<DropdownMenuItem<int>>((f) => DropdownMenuItem(value: f['id'] as int, child: Text('${f['floor_number'] ?? f['name'] ?? f['id']}F'))).toList(),
          initialValue: selectedFloorId,
          onChanged: (v) => setDialogState(() => selectedFloorId = v),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: priceController, decoration: const InputDecoration(labelText: '价格 *'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          if (numberController.text.isEmpty || selectedRoomTypeId == null || selectedFloorId == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整信息')));
            return;
          }
          Navigator.pop(ctx);
          try {
            final result = await ref.read(roomServiceProvider).createRoom({
              'room_number': numberController.text.trim(),
              'room_type_id': selectedRoomTypeId,
              'floor_id': selectedFloorId,
              'room_price': double.tryParse(priceController.text) ?? 388,
              'room_status': 'available',
            });
            if (result.success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('房间添加成功')));
              _loadRooms();
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '添加失败')));
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('添加失败，请重试')));
          }
        }, child: const Text('确认添加')),
      ],
    )));
  }

  void _showEditRoomDialog(Map<String, dynamic> room) {
    final numberController = TextEditingController(text: room['number'].toString());
    final typeController = TextEditingController(text: room['type']);
    final floorController = TextEditingController(text: room['floor'].toString());
    final priceController = TextEditingController(text: room['price'].toString());

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('编辑房间'),
      content: Form(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: numberController, decoration: const InputDecoration(labelText: '房间号 *')),
        TextFormField(controller: typeController, decoration: const InputDecoration(labelText: '房型 *')),
        TextFormField(controller: floorController, decoration: const InputDecoration(labelText: '楼层 *'), keyboardType: TextInputType.number),
        TextFormField(controller: priceController, decoration: const InputDecoration(labelText: '价格 *'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          Navigator.pop(ctx);
          try {
            final result = await ref.read(roomServiceProvider).updateRoom(room['id'], {
              'room_number': numberController.text.trim(),
              'room_type': typeController.text.trim(),
              'floor': int.tryParse(floorController.text) ?? 1,
              'room_price': double.tryParse(priceController.text) ?? 388,
            });
            if (result.success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('房间更新成功')));
              _loadRooms();
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失败，请重试')));
          }
        }, child: const Text('保存修改')),
      ],
    ));
  }

  void _confirmDeleteRoom(Map<String, dynamic> room) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定要删除 ${room['number']}号房吗？此操作不可恢复。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () async {
          Navigator.pop(ctx);
          try {
            final result = await ref.read(roomServiceProvider).deleteRoom(room['id']);
            if (result.success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('房间已删除')));
              _loadRooms();
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
          }
        }, child: const Text('确定删除')),
      ],
    ));
  }
}
