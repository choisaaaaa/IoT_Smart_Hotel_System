import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class RoomManagePage extends StatefulWidget {
  const RoomManagePage({super.key});

  @override
  State<RoomManagePage> createState() => _RoomManagePageState();
}

class _RoomManagePageState extends State<RoomManagePage> {
  final List<Map<String, dynamic>> rooms = [
    {'number': '101', 'type': '标准间', 'floor': 1, 'status': 'occupied', 'price': 388},
    {'number': '102', 'type': '标准间', 'floor': 1, 'status': 'available', 'price': 388},
    {'number': '103', 'type': '大床房', 'floor': 1, 'status': 'cleaning', 'price': 588},
    {'number': '201', 'type': '大床房', 'floor': 2, 'status': 'available', 'price': 588},
    {'number': '202', 'type': '套房', 'floor': 2, 'status': 'occupied', 'price': 1288},
    {'number': '203', 'type': '套房', 'floor': 2, 'status': 'maintenance', 'price': 1288},
    {'number': '301', 'type': '豪华套房', 'floor': 3, 'status': 'reserved', 'price': 2088},
    {'number': '302', 'type': '豪华套房', 'floor': 3, 'status': 'available', 'price': 2088},
  ];

  String _filterStatus = 'all';

  List<Map<String, dynamic>> get filteredRooms {
    if (_filterStatus == 'all') return rooms;
    return rooms.where((r) => r['status'] == _filterStatus).toList();
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
                    onSelected: (_) => setState(() => _filterStatus = s),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
              itemCount: filteredRooms.length,
              itemBuilder: (context, index) => _buildRoomCard(filteredRooms[index]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('添加房间'),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(room['number'] + '号房', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: getStatusColor(room['status']).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(getStatusText(room['status']), style: TextStyle(fontSize: 11, color: getStatusColor(room['status']), fontWeight: FontWeight.w600))),
            ]),
            const Spacer(),
            Text(room['type'], style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('${room['floor']}F · ¥${room['price']}/晚', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
