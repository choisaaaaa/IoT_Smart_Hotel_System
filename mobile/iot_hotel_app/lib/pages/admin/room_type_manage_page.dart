import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/room_type_service.dart';

class RoomTypeManagePage extends ConsumerStatefulWidget {
  const RoomTypeManagePage({super.key});

  @override
  ConsumerState<RoomTypeManagePage> createState() => _RoomTypeManagePageState();
}

class _RoomTypeManagePageState extends ConsumerState<RoomTypeManagePage> {
  bool _isLoading = true;
  List<dynamic> _roomTypes = [];

  @override
  void initState() {
    super.initState();
    _loadRoomTypes();
  }

  Future<void> _loadRoomTypes() async {
    setState(() => _isLoading = true);
    final result = await ref.read(roomTypeServiceProvider).getRoomTypes();
    if (result.success && mounted) {
      setState(() => _roomTypes = result.data ?? []);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteRoomType(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除房型后，关联的房间将无法正常使用。确定要删除吗？'),
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
      final result = await ref.read(roomTypeServiceProvider).deleteRoomType(id);
      if (result.success) {
        _loadRoomTypes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('房型已删除')),
          );
        }
      }
    }
  }

  void _showEditDialog(Map<String, dynamic>? roomType) {
    final isEdit = roomType != null;
    final nameController = TextEditingController(text: roomType?['name'] ?? '');
    final codeController = TextEditingController(text: roomType?['code'] ?? '');
    final priceController = TextEditingController(
      text: roomType?['base_price']?.toString() ?? '0',
    );
    final areaController = TextEditingController(
      text: roomType?['area']?.toString() ?? '',
    );
    final capacityController = TextEditingController(
      text: roomType?['max_capacity']?.toString() ?? '2',
    );
    final bedTypeController = TextEditingController(
      text: roomType?['bed_type'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: roomType?['description'] ?? '',
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
                      isEdit ? '编辑房型' : '新增房型',
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
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: '房型名称 *',
                            hintText: '如：豪华大床房',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: '房型代码 *',
                            hintText: '如：DLX-KING',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: '基准价格 (元) *',
                            prefixText: '¥',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: areaController,
                                decoration: const InputDecoration(
                                  labelText: '面积 (㎡)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: capacityController,
                                decoration: const InputDecoration(
                                  labelText: '最大入住人数',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: bedTypeController,
                          decoration: const InputDecoration(
                            labelText: '床型',
                            hintText: '如：1.8米大床',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: '房型描述',
                            hintText: '房型特色、设施等描述',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final data = {
                      'name': nameController.text,
                      'code': codeController.text,
                      'base_price': double.tryParse(priceController.text) ?? 0,
                      'area': double.tryParse(areaController.text),
                      'max_capacity': int.tryParse(capacityController.text) ?? 2,
                      'bed_type': bedTypeController.text.isEmpty ? null : bedTypeController.text,
                      'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                    };

                    ApiResult result;
                    if (isEdit) {
                      result = await ref.read(roomTypeServiceProvider).updateRoomType(
                        roomType['id'],
                        data,
                      );
                    } else {
                      result = await ref.read(roomTypeServiceProvider).createRoomType(data);
                    }

                    if (result.success) {
                      _loadRoomTypes();
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? '房型已更新' : '房型已创建')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(isEdit ? '保存修改' : '创建房型'),
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
        title: Text('房型维护', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoomTypes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _roomTypes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hotel_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('暂无房型数据', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showEditDialog(null),
                        icon: const Icon(Icons.add),
                        label: const Text('添加房型'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRoomTypes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _roomTypes.length,
                    itemBuilder: (context, index) {
                      final roomType = _roomTypes[index];
                      return _RoomTypeCard(
                        roomType: roomType,
                        onEdit: () => _showEditDialog(roomType),
                        onDelete: () => _deleteRoomType(roomType['id']),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(null),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('新增房型'),
      ),
    );
  }
}

class _RoomTypeCard extends StatelessWidget {
  final Map<String, dynamic> roomType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoomTypeCard({
    required this.roomType,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final basePrice = roomType['base_price'] ?? 0;
    final area = roomType['area'];
    final maxCapacity = roomType['max_capacity'] ?? 2;
    final bedType = roomType['bed_type'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hotel, color: AppColors.primary, size: 32),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    roomType['name'] ?? '未命名',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    roomType['code'] ?? '-',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  '¥$basePrice/晚',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    if (area != null)
                      _InfoChip(icon: Icons.square_foot, text: '$area㎡'),
                    _InfoChip(icon: Icons.people, text: '最多$maxCapacity人'),
                    if (bedType != null && bedType.toString().isNotEmpty)
                      _InfoChip(icon: Icons.bed, text: bedType),
                  ],
                ),
                if (roomType['description'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    roomType['description'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 1, height: 40, child: VerticalDivider()),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}
