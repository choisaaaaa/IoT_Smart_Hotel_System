import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/storage/local_storage.dart';
import '../../services/coupon_service.dart';

class CouponManagePage extends ConsumerStatefulWidget {
  const CouponManagePage({super.key});

  @override
  ConsumerState<CouponManagePage> createState() => _CouponManagePageState();
}

class _CouponManagePageState extends ConsumerState<CouponManagePage> {
  bool _isLoading = true;
  List<dynamic> _coupons = [];
  String _statusFilter = '';
  int? _selectedHotelId;
  List<dynamic> _hotels = [];
  bool _isSystemAdmin = false;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadHotels();
    _loadCoupons();
  }

  Future<void> _checkUserRole() async {
    final role = await LocalStorage.getUserRole();
    setState(() {
      _isSystemAdmin = role == 'system';
      _isStaff = role == 'staff';
    });
  }

  Future<void> _loadHotels() async {
    final result = await ref.read(couponServiceProvider).getHotels();
    if (result.success && mounted) {
      setState(() => _hotels = result.data ?? []);
    }
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoading = true);
    final result = await ref.read(couponServiceProvider).getCoupons(
          status: _statusFilter.isEmpty ? null : _statusFilter,
          hotelId: _selectedHotelId,
        );
    if (result.success && mounted) {
      setState(() => _coupons = result.data ?? []);
    }
    setState(() => _isLoading = false);
  }

  Map<String, int> get _statusCounts {
    final counts = <String, int>{};
    for (final coupon in _coupons) {
      final status = coupon['status']?.toString() ?? 'active';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _deleteCoupon(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除此优惠券吗？删除后无法恢复。'),
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
      final result = await ref.read(couponServiceProvider).deleteCoupon(id);
      if (result.success) {
        _loadCoupons();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('优惠券已删除')),
          );
        }
      }
    }
  }

  Future<void> _redeemCoupon(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('核销优惠券'),
        content: const Text('确定要核销此优惠券吗？核销后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('确认核销'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ref.read(couponServiceProvider).redeemCoupon(id);
      if (result.success) {
        _loadCoupons();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('优惠券已核销')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '核销失败')),
        );
      }
    }
  }

  void _showCreateDialog() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final discountController = TextEditingController();
    final minAmountController = TextEditingController();
    final quantityController = TextEditingController(text: '100');
    String couponType = 'percentage';
    DateTime? startDate;
    DateTime? endDate;
    int? selectedHotelForCreate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                        '新建优惠券',
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
                            controller: codeController,
                            decoration: const InputDecoration(
                              labelText: '优惠券代码 *',
                              hintText: '如：SUMMER2024',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: '优惠券名称 *',
                              hintText: '如：夏季特惠券',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: couponType,
                            decoration: const InputDecoration(
                              labelText: '优惠券类型',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'discount',
                                child: Text('折扣券 (百分比折扣)'),
                              ),
                              DropdownMenuItem(
                                value: 'cash',
                                child: Text('直减券 (固定金额)'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() => couponType = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: discountController,
                            decoration: InputDecoration(
                              labelText: couponType == 'discount' ? '折扣率 (%) *' : '减免金额 (元) *',
                              hintText: couponType == 'discount' ? '如：20 表示8折' : '如：50',
                              border: OutlineInputBorder(),
                              suffixText: couponType == 'discount' ? '%' : '元',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: minAmountController,
                            decoration: const InputDecoration(
                              labelText: '最低消费金额',
                              hintText: '0 表示无限制',
                              border: OutlineInputBorder(),
                              prefixText: '¥',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: quantityController,
                            decoration: const InputDecoration(
                              labelText: '发放数量 *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          if (_isSystemAdmin && _hotels.isNotEmpty) ...[
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: '选择门店 *',
                                border: OutlineInputBorder(),
                                helperText: '不选则创建为通用券（所有门店可用）',
                              ),
                              value: selectedHotelForCreate,
                              items: [
                                const DropdownMenuItem<int>(
                                  value: 0,
                                  child: Text('通用券（所有门店可用）'),
                                ),
                                ..._hotels.map<DropdownMenuItem<int>>((hotel) {
                                  return DropdownMenuItem<int>(
                                    value: hotel['id'] as int,
                                    child: Text(hotel['hotel_name']?.toString() ?? ''),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setModalState(() => selectedHotelForCreate = val);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          ListTile(
                            title: const Text('开始日期'),
                            subtitle: Text(
                              startDate != null
                                  ? DateFormat('yyyy-MM-dd').format(startDate!)
                                  : '立即生效',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setModalState(() => startDate = date);
                              }
                            },
                          ),
                          ListTile(
                            title: const Text('结束日期'),
                            subtitle: Text(
                              endDate != null
                                  ? DateFormat('yyyy-MM-dd').format(endDate!)
                                  : '长期有效',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                              );
                              if (date != null) {
                                setModalState(() => endDate = date);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final data = <String, dynamic>{
                        'coupon_code': codeController.text.toUpperCase().trim(),
                        'coupon_name': nameController.text.trim(),
                        'coupon_type': couponType,
                        'discount_value': double.tryParse(discountController.text) ?? 0,
                        'min_amount': double.tryParse(minAmountController.text) ?? 0,
                        'total_count': int.tryParse(quantityController.text) ?? 100,
                        'valid_from': startDate != null
                            ? DateFormat('yyyy-MM-dd').format(startDate!)
                            : null,
                        'valid_to': endDate != null
                            ? DateFormat('yyyy-MM-dd').format(endDate!)
                            : null,
                      };
                      if (_isSystemAdmin && selectedHotelForCreate != null) {
                        data['hotel_id'] = selectedHotelForCreate;
                      }

                      final result = await ref.read(couponServiceProvider).createCoupon(data);
                      if (result.success) {
                        _loadCoupons();
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('优惠券创建成功')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('创建优惠券'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDistributeDialog(dynamic coupon) {
    final phoneController = TextEditingController();

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
                      '发放优惠券',
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon['coupon_name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '代码: ${coupon['coupon_code']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: '用户手机号 *',
                    hintText: '输入要发放的用户手机号',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final phone = phoneController.text.trim();
                    if (phone.isEmpty || phone.length < 11) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入有效的手机号')),
                      );
                      return;
                    }

                    final result = await ref.read(couponServiceProvider).distributeCoupon(
                      coupon['id'],
                      phone,
                    );
                    if (result.success) {
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('优惠券发放成功')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('发放给用户'),
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
    final statusCounts = _statusCounts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isStaff ? '优惠券核销' : '优惠券管理', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCoupons,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isStaff) _buildStatCards(statusCounts),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _coupons.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('暂无优惠券', style: TextStyle(color: grey[500])),
                            if (!_isStaff) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showCreateDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('创建优惠券'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCoupons,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _coupons.length,
                          itemBuilder: (context, index) {
                            final coupon = _coupons[index];
                            return _CouponCard(
                              coupon: coupon,
                              onDistribute: () => _showDistributeDialog(coupon),
                              onDelete: () => _deleteCoupon(coupon['id']),
                              onRedeem: () => _redeemCoupon(coupon['id']),
                              isStaff: _isStaff,
                              isSystemAdmin: _isSystemAdmin,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      if (!_isStaff)
        FloatingActionButton.extended(
          onPressed: _showCreateDialog,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add),
          label: const Text('新建优惠券'),
        ),
    );
  }

  Widget _buildStatCards(Map<String, int> counts) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: '进行中',
              value: (counts['active'] ?? 0).toString(),
              color: Colors.green,
              icon: Icons.check_circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '已过期',
              value: (counts['expired'] ?? 0).toString(),
              color: Colors.grey,
              icon: Icons.timer_off,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '已发完',
              value: (counts['depleted'] ?? 0).toString(),
              color: Colors.orange,
              icon: Icons.block,
            ),
          ),
        ],
      ),
    );
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
              isSelected: _statusFilter.isEmpty && _selectedHotelId == null,
              onTap: () {
                setState(() { _statusFilter = ''; _selectedHotelId = null; });
                _loadCoupons();
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '进行中',
              isSelected: _statusFilter == 'active',
              onTap: () {
                setState(() => _statusFilter = 'active');
                _loadCoupons();
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '已过期',
              isSelected: _statusFilter == 'expired',
              onTap: () {
                setState(() => _statusFilter = 'expired');
                _loadCoupons();
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '已发完',
              isSelected: _statusFilter == 'depleted',
              onTap: () {
                setState(() => _statusFilter = 'depleted');
                _loadCoupons();
              },
            ),
            if (_isSystemAdmin && _hotels.isNotEmpty) ...[
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  hint: const Text('筛选门店', style: TextStyle(fontSize: 13)),
                  value: _selectedHotelId,
                  iconSize: 18,
                  style: const TextStyle(fontSize: 13, color: AppColors.primary),
                  items: [
                    const DropdownMenuItem<int>(
                      value: -1,
                      child: Text('所有门店', style: TextStyle(fontSize: 13)),
                    ),
                    ..._hotels.map<DropdownMenuItem<int>>((h) {
                      return DropdownMenuItem<int>(
                        value: h['id'] as int,
                        child: Text(h['hotel_name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedHotelId = val == -1 ? null : val);
                    _loadCoupons();
                  },
                ),
              ),
            ],
          ],
        ),
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
            color: black.withValues(alpha: 0.05),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : grey[300]!,
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

class _CouponCard extends StatelessWidget {
  final dynamic coupon;
  final VoidCallback onDistribute;
  final VoidCallback onDelete;
  final VoidCallback onRedeem;
  final bool isStaff;
  final bool isSystemAdmin;

  const _CouponCard({
    required this.coupon,
    required this.onDistribute,
    required this.onDelete,
    required this.onRedeem,
    required this.isStaff,
    required this.isSystemAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final type = coupon['coupon_type'] ?? 'discount';
    final status = coupon['status'] ?? 'active';
    final discountValue = coupon['discount_value'] ?? 0;
    final receivedCount = coupon['received_count'] ?? 0;
    final totalQuantity = coupon['total_count'] ?? 0;
    final remaining = totalQuantity > 0 ? totalQuantity - receivedCount : -1;
    final hotelName = coupon['hotel_name'];
    final isGeneral = (coupon['hotel_id'] ?? 0) == 0;

    String discountText;
    if (type == 'discount') {
      discountText = '${discountValue.toStringAsFixed(0)}% OFF';
    } else {
      discountText = '\u00a5${discountValue.toStringAsFixed(0)}';
    }

    Color statusColor;
    String statusText;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusText = '进行中';
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusText = '已过期';
        break;
      case 'depleted':
        statusColor = Colors.orange;
        statusText = '已发完';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        discountText,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                    if (hotelName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isGeneral ? Colors.blue.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isGeneral ? '通用' : hotelName.toString(),
                          style: TextStyle(
                            color: isGeneral ? Colors.blue : purple,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (coupon['coupon_code'] != null)
                      Text(
                        '#${coupon['coupon_code']}',
                        style: TextStyle(color: grey[400], fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  coupon['coupon_name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.confirmation_number,
                      text: remaining >= 0 ? '剩余 $remaining/$totalQuantity' : '不限量',
                    ),
                    const SizedBox(width: 16),
                    if (coupon['min_amount'] != null && coupon['min_amount'] > 0)
                      _InfoChip(
                        icon: Icons.shopping_cart,
                        text: '\u00a5${coupon['min_amount']}起',
                      ),
                  ],
                ),
                if (coupon['valid_from'] != null || coupon['valid_to'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.date_range, size: 14, color: grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${coupon['valid_from'] ?? '即日起'} 至 ${coupon['valid_to'] ?? '长期有效'}',
                        style: TextStyle(color: grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!isStaff || status == 'active') const Divider(height: 1),
          if (isStaff && status == 'active')
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onRedeem,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('核销'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ),
              ],
            )
          else if (!isStaff)
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: status == 'active' ? onDistribute : null,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('发放'),
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
        Icon(icon, size: 14, color: grey[500]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: grey[600], fontSize: 12),
        ),
      ],
    );
  }
}
