import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/maintenance_service.dart';
import '../../services/room_service.dart';

class WorkOrdersPage extends ConsumerStatefulWidget {
  const WorkOrdersPage({super.key});

  @override
  ConsumerState<WorkOrdersPage> createState() => _WorkOrdersPageState();
}

class _WorkOrdersPageState extends ConsumerState<WorkOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = '';
  bool _isLoading = false;
  List<dynamic> _maintenanceOrders = [];
  List<dynamic> _cleaningTasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadMaintenanceOrders(),
      _loadCleaningTasks(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadMaintenanceOrders() async {
    final result = await ref.read(maintenanceServiceProvider).getWorkOrders(
          status: _statusFilter.isEmpty ? null : _statusFilter,
          pageSize: 100,
        );
    if (result.success && mounted) {
      setState(() => _maintenanceOrders = result.data ?? []);
    }
  }

  Future<void> _loadCleaningTasks() async {
    final result = await ref.read(roomServiceProvider).getRooms(
          status: 'cleaning',
          pageSize: 100,
        );
    if (result.success && mounted) {
      setState(() => _cleaningTasks = result.data ?? []);
    }
  }

  int get _pendingCount =>
      _maintenanceOrders.where((o) => o['status'] == 'pending').length;
  int get _processingCount =>
      _maintenanceOrders.where((o) => o['status'] == 'processing').length;
  int get _completedCount =>
      _maintenanceOrders.where((o) => o['status'] == 'completed').length;

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _priorityText(String priority) {
    switch (priority) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      case 'low':
        return '低';
      default:
        return '普通';
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'processing':
        return '处理中';
      case 'completed':
        return '已完成';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('工单处理', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.build), text: '维修处理'),
            Tab(icon: Icon(Icons.cleaning_services), text: '打扫处理'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildStatCards(),
          _buildFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMaintenanceTab(),
                _buildCleaningTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateModal,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('新建工单'),
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
              title: '待处理',
              value: _pendingCount.toString(),
              color: AppColors.warning,
              icon: Icons.access_time,
              onTap: () => _filterByStatus('pending'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '处理中',
              value: _processingCount.toString(),
              color: AppColors.primary,
              icon: Icons.build,
              onTap: () => _filterByStatus('processing'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '已完成',
              value: _completedCount.toString(),
              color: AppColors.success,
              icon: Icons.check_circle,
              onTap: () => _filterByStatus('completed'),
            ),
          ),
        ],
      ),
    );
  }

  void _filterByStatus(String status) {
    setState(() {
      _statusFilter = _statusFilter == status ? '' : status;
    });
    _loadMaintenanceOrders();
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: '全部',
              isSelected: _statusFilter.isEmpty,
              onTap: () => _filterByStatus(''),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '待处理',
              isSelected: _statusFilter == 'pending',
              onTap: () => _filterByStatus('pending'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '处理中',
              isSelected: _statusFilter == 'processing',
              onTap: () => _filterByStatus('processing'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '已完成',
              isSelected: _statusFilter == 'completed',
              onTap: () => _filterByStatus('completed'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_maintenanceOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无维修工单', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _maintenanceOrders.length,
      itemBuilder: (context, index) {
        final order = _maintenanceOrders[index];
        return _MaintenanceOrderCard(
          order: order,
          priorityColor: _priorityColor(order['priority'] ?? 'normal'),
          priorityText: _priorityText(order['priority'] ?? 'normal'),
          statusText: _statusText(order['status'] ?? 'pending'),
          statusColor: _statusColor(order['status'] ?? 'pending'),
          onStart: order['status'] == 'pending'
              ? () => _startProcess(order['id'])
              : null,
          onComplete: order['status'] == 'processing'
              ? () => _completeOrder(order['id'])
              : null,
        );
      },
    );
  }

  Widget _buildCleaningTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cleaningTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cleaning_services_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无待打扫房间', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cleaningTasks.length,
      itemBuilder: (context, index) {
        final room = _cleaningTasks[index];
        return _CleaningTaskCard(
          room: room,
          onMarkCleaning: () => _markCleaning(room['id']),
          onMarkAvailable: () => _markAvailable(room['id']),
        );
      },
    );
  }

  Future<void> _startProcess(int orderId) async {
    final result = await ref
        .read(maintenanceServiceProvider)
        .updateWorkOrderStatus(orderId, 'in_progress');
    if (result.success) {
      _loadMaintenanceOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已开始处理工单')),
        );
      }
    }
  }

  Future<void> _completeOrder(int orderId) async {
    final result = await ref
        .read(maintenanceServiceProvider)
        .updateWorkOrderStatus(orderId, 'completed');
    if (result.success) {
      _loadMaintenanceOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('工单已完成')),
        );
      }
    }
  }

  Future<void> _markCleaning(int roomId) async {
    final result =
        await ref.read(roomServiceProvider).updateRoomStatus(roomId, 'cleaning');
    if (result.success) {
      _loadCleaningTasks();
    }
  }

  Future<void> _markAvailable(int roomId) async {
    final result =
        await ref.read(roomServiceProvider).updateRoomStatus(roomId, 'available');
    if (result.success) {
      _loadCleaningTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('房间已标记为可售')),
        );
      }
    }
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateWorkOrderModal(
        onSubmit: (data) async {
          final result = await ref
              .read(maintenanceServiceProvider)
              .createWorkOrder(data);
          if (result.success) {
            _loadMaintenanceOrders();
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('工单创建成功')),
            );
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
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansSc(
            fontSize: 13,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MaintenanceOrderCard extends StatelessWidget {
  final dynamic order;
  final Color priorityColor;
  final String priorityText;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  const _MaintenanceOrderCard({
    required this.order,
    required this.priorityColor,
    required this.priorityText,
    required this.statusText,
    required this.statusColor,
    this.onStart,
    this.onComplete,
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priorityText,
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
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
          Text(
            order['title'] ?? '维修工单',
            style: GoogleFonts.notoSansSc(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.room, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                '房间 ${order['room_number'] ?? '-'}',
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
          if (order['description'] != null) ...[
            const SizedBox(height: 8),
            Text(
              order['description'],
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (onStart != null || onComplete != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onStart != null)
                  TextButton(
                    onPressed: onStart,
                    child: const Text('开始处理'),
                  ),
                if (onComplete != null)
                  ElevatedButton(
                    onPressed: onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('完成'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
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

class _CleaningTaskCard extends StatelessWidget {
  final dynamic room;
  final VoidCallback onMarkCleaning;
  final VoidCallback onMarkAvailable;

  const _CleaningTaskCard({
    required this.room,
    required this.onMarkCleaning,
    required this.onMarkAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final status = room['room_status'] ?? room['status'] ?? 'available';
    final isCleaning = status == 'cleaning';

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
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isCleaning ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCleaning ? Icons.cleaning_services : Icons.check_circle,
              color: isCleaning ? AppColors.warning : AppColors.success,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room['room_number'] ?? '-',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  room['room_name'] ?? '标准间',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCleaning ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCleaning ? '待清扫' : '可售房',
                    style: TextStyle(
                      color: isCleaning ? AppColors.warning : AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isCleaning)
            ElevatedButton(
              onPressed: onMarkAvailable,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('标记可售'),
            )
          else
            TextButton(
              onPressed: onMarkCleaning,
              child: const Text('标记清扫'),
            ),
        ],
      ),
    );
  }
}

class _CreateWorkOrderModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const _CreateWorkOrderModal({required this.onSubmit});

  @override
  State<_CreateWorkOrderModal> createState() => _CreateWorkOrderModalState();
}

class _CreateWorkOrderModalState extends State<_CreateWorkOrderModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'medium';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
                      '新建维修工单',
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
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '工单标题',
                    hintText: '请输入工单标题',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入工单标题';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '问题描述',
                    hintText: '请详细描述问题',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: '优先级',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('高')),
                    DropdownMenuItem(value: 'medium', child: Text('中')),
                    DropdownMenuItem(value: 'low', child: Text('低')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _priority = value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('创建工单'),
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
        'title': _titleController.text,
        'description': _descriptionController.text,
        'priority': _priority,
        'type': 'maintenance',
      });
    }
  }
}
