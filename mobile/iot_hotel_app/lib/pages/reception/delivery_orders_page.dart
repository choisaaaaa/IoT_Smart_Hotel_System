import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/delivery_service.dart';
import '../../services/room_service.dart';

class DeliveryOrdersPage extends ConsumerStatefulWidget {
  const DeliveryOrdersPage({super.key});

  @override
  ConsumerState<DeliveryOrdersPage> createState() => _DeliveryOrdersPageState();
}

class _DeliveryOrdersPageState extends ConsumerState<DeliveryOrdersPage> {
  bool _isLoading = false;
  List<dynamic> _orders = [];
  List<dynamic> _rooms = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadOrders(),
      _loadRooms(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadOrders() async {
    final result = await ref.read(deliveryServiceProvider).getDeliveryOrders(
          pageSize: 100,
        );
    if (result.success && mounted) {
      setState(() => _orders = result.data ?? []);
    }
  }

  Future<void> _loadRooms() async {
    final result = await ref.read(roomServiceProvider).getRooms(
          status: 'occupied',
          pageSize: 100,
        );
    if (result.success && mounted) {
      setState(() => _rooms = result.data ?? []);
    }
  }

  int get _pendingCount =>
      _orders.where((o) => o['status'] == 'pending').length;
  int get _deliveringCount =>
      _orders.where((o) => o['status'] == 'delivering').length;
  int get _doneCount =>
      _orders.where((o) => o['status'] == 'completed' || o['status'] == 'delivered').length;

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'delivering':
        return AppColors.primary;
      case 'completed':
      case 'delivered':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusText(String? status) {
    switch (status) {
      case 'pending':
        return '待配送';
      case 'delivering':
        return '配送中';
      case 'completed':
      case 'delivered':
        return '已完成';
      default:
        return status ?? '未知';
    }
  }

  String _categoryLabel(String? category) {
    switch (category) {
      case 'beverage':
        return '饮品';
      case 'food':
        return '食品';
      case 'daily':
        return '日用品';
      case 'electronic':
        return '电子';
      case 'bedding':
        return '床品';
      default:
        return '其他';
    }
  }

  List<dynamic> get _filteredOrders {
    if (_searchQuery.isEmpty) return _orders;
    return _orders.where((o) {
      final roomNum = (o['room_number'] ?? o['room_id']?.toString() ?? '').toString().toLowerCase();
      final itemName = (o['item_name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return roomNum.contains(query) || itemName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('客房送物', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
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
          _buildStatCards(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delivery_dining_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? '暂无送物订单' : '未找到匹配的订单',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _DeliveryOrderCard(
                              order: order,
                              statusColor: _statusColor(order['status']),
                              statusText: _statusText(order['status']),
                              categoryLabel: _categoryLabel(order['item_category']),
                              onStart: order['status'] == 'pending'
                                  ? () => _startDelivery(order['id'])
                                  : null,
                              onComplete: order['status'] == 'delivering'
                                  ? () => _completeDelivery(order['id'])
                                  : null,
                              onCancel: order['status'] == 'pending'
                                  ? () => _cancelOrder(order['id'])
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateModal,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('新建订单'),
      ),
    );
  }

  Widget _buildStatCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: '待配送',
              value: _pendingCount.toString(),
              color: AppColors.warning,
              icon: Icons.pending_actions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '配送中',
              value: _deliveringCount.toString(),
              color: AppColors.primary,
              icon: Icons.local_shipping,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '已完成',
              value: _doneCount.toString(),
              color: AppColors.success,
              icon: Icons.check_circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索订单号/房号',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Future<void> _startDelivery(int orderId) async {
    final result = await ref
        .read(deliveryServiceProvider)
        .updateDeliveryStatus(orderId, 'delivering');
    if (result.success) {
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已开始配送')),
        );
      }
    }
  }

  Future<void> _completeDelivery(int orderId) async {
    final result = await ref
        .read(deliveryServiceProvider)
        .updateDeliveryStatus(orderId, 'completed');
    if (result.success) {
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配送已完成')),
        );
      }
    }
  }

  Future<void> _cancelOrder(int orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认取消'),
        content: const Text('确定要取消此订单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 这里可以添加取消订单的API调用
      _loadOrders();
    }
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateDeliveryModal(
        rooms: _rooms,
        onSubmit: (data) async {
          final result = await ref
              .read(deliveryServiceProvider)
              .createDeliveryOrder(data);
          if (result.success) {
            _loadOrders();
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('订单创建成功')),
              );
            }
          }
        },
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
      padding: const EdgeInsets.all(16),
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.notoSansSc(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.notoSansSc(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryOrderCard extends StatelessWidget {
  final dynamic order;
  final Color statusColor;
  final String statusText;
  final String categoryLabel;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const _DeliveryOrderCard({
    required this.order,
    required this.statusColor,
    required this.statusText,
    required this.categoryLabel,
    this.onStart,
    this.onComplete,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCategoryColor(order['item_category']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  categoryLabel,
                  style: TextStyle(
                    color: _getCategoryColor(order['item_category']),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '#${order['id']}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  order['item_name'] ?? '送物品',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'x${order['quantity'] ?? 1}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.room, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                '房间 ${order['room_number'] ?? order['room_id'] ?? '-'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                _formatTime(order['created_at']),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          if (order['note'] != null && order['note'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.notes, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order['note'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onStart != null || onComplete != null || onCancel != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('取消'),
                  ),
                if (onStart != null)
                  TextButton(
                    onPressed: onStart,
                    child: const Text('开始配送'),
                  ),
                if (onComplete != null)
                  ElevatedButton(
                    onPressed: onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('送达确认'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'beverage':
        return Colors.blue;
      case 'food':
        return Colors.orange;
      case 'daily':
        return Colors.green;
      case 'electronic':
        return Colors.purple;
      case 'bedding':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(String? time) {
    if (time == null) return '-';
    try {
      final date = DateTime.parse(time);
      return '${date.month}-${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return time;
    }
  }
}

class _CreateDeliveryModal extends StatefulWidget {
  final List<dynamic> rooms;
  final Function(Map<String, dynamic>) onSubmit;

  const _CreateDeliveryModal({
    required this.rooms,
    required this.onSubmit,
  });

  @override
  State<_CreateDeliveryModal> createState() => _CreateDeliveryModalState();
}

class _CreateDeliveryModalState extends State<_CreateDeliveryModal> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedRoomId;
  String _itemCategory = 'daily';
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _noteController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'value': 'beverage', 'label': '饮品', 'icon': Icons.local_drink},
    {'value': 'food', 'label': '食品', 'icon': Icons.fastfood},
    {'value': 'daily', 'label': '日用品', 'icon': Icons.shopping_basket},
    {'value': 'electronic', 'label': '电子', 'icon': Icons.electrical_services},
    {'value': 'bedding', 'label': '床品', 'icon': Icons.bed},
    {'value': 'other', 'label': '其他', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '新建送物订单',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  value: _selectedRoomId,
                  decoration: const InputDecoration(
                    labelText: '目标房间 *',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('选择房间'),
                  items: widget.rooms.map<DropdownMenuItem<int>>((room) {
                    return DropdownMenuItem<int>(
                      value: room['id'] as int,
                      child: Text('${room['room_number']} - ${room['room_name'] ?? '标准间'}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedRoomId = value);
                  },
                  validator: (value) {
                    if (value == null) {
                      return '请选择目标房间';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _itemCategory,
                  decoration: const InputDecoration(
                    labelText: '物品类别 *',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map<DropdownMenuItem<String>>((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['value'] as String,
                      child: Row(
                        children: [
                          Icon(cat['icon'] as IconData, size: 20),
                          const SizedBox(width: 8),
                          Text(cat['label'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _itemCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _itemNameController,
                  decoration: const InputDecoration(
                    labelText: '物品名称 *',
                    hintText: '如：矿泉水、毛巾等',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入物品名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: '数量',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入数量';
                    }
                    final qty = int.tryParse(value);
                    if (qty == null || qty < 1) {
                      return '数量必须大于0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    hintText: '特殊要求...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('创建订单'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit({
        'room_id': _selectedRoomId,
        'item_category': _itemCategory,
        'item_name': _itemNameController.text,
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'note': _noteController.text.isEmpty ? null : _noteController.text,
      });
    }
  }
}
