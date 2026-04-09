import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/member_service.dart';
import '../../services/payment_service.dart';

class BookingFlowPage extends ConsumerStatefulWidget {
  final String hotelName;
  final String roomType;
  final double price;
  final int roomId;
  final DateTime checkInDate;
  final DateTime checkOutDate;

  const BookingFlowPage({
    super.key,
    required this.hotelName,
    required this.roomType,
    required this.price,
    required this.roomId,
    required this.checkInDate,
    required this.checkOutDate,
  });

  @override
  ConsumerState<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends ConsumerState<BookingFlowPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _specialRequestController = TextEditingController();
  bool _isLoading = false;
  int _roomCount = 1;
  List<dynamic> _coupons = [];
  dynamic _selectedCoupon;
  bool _isLoadingCoupons = false;
  String _paymentMethod = 'balance'; // balance, wechat, alipay

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoadingCoupons = true);
    try {
      final result = await ref.read(memberServiceProvider).getMyCoupons();
      if (result.success && mounted) {
        setState(() => _coupons = result.data ?? []);
      }
    } catch (e) {
      debugPrint('Error loading coupons: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCoupons = false);
    }
  }

  void _showCouponSelector() async {
    final selected = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CouponBottomSheet(coupons: _coupons, selectedCoupon: _selectedCoupon),
    );

    if (selected != null && mounted) {
      setState(() => _selectedCoupon = selected);
    }
  }

  Future<void> _loadUserInfo() async {
    final user = await ref.read(authServiceProvider).getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _nameController.text = user.username;
        _phoneController.text = user.phone ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _specialRequestController.dispose();
    super.dispose();
  }

  Future<void> _submitBookingAndPay() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整的入住信息')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. 创建预订 (状态为待支付)
      final result = await ref.read(bookingServiceProvider).createBooking({
        'room_id': widget.roomId,
        'guest_name': _nameController.text.trim(),
        'guest_phone': _phoneController.text.trim(),
        'guest_id_number': _idNumberController.text.trim(),
        'check_in_date': widget.checkInDate.toIso8601String().split('T')[0],
        'check_out_date': widget.checkOutDate.toIso8601String().split('T')[0],
        'guest_count': _roomCount,
        'payment_method': _paymentMethod,
        'special_requests': _specialRequestController.text.trim(),
      });

      if (!mounted) return;

      if (result.success) {
        final orderId = result.data!['id'];
        final totalPrice = result.data!['total_price'];

        // 2. 创建支付记录
        final createPayResult = await ref.read(paymentServiceProvider).createPayment({
          'order_type': 'booking',
          'order_id': orderId,
          'amount': totalPrice,
          'payment_method': _paymentMethod,
        });

        if (!createPayResult.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(createPayResult.message ?? '创建支付订单失败')));
          context.go('/orders');
          return;
        }

        // 3. 模拟支付确认流程
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在跳转支付...')));
        await Future.delayed(const Duration(seconds: 1));

        // 4. 确认支付
        final paymentId = createPayResult.data!['id'];
        final payResult = await ref.read(paymentServiceProvider).pay(paymentId);
        
        if (payResult.success && mounted) {
          final bookingId = result.data!['id'] as int? ?? orderId;
          final bookingNo = result.data!['booking_number']?.toString() ?? result.data!['booking_no']?.toString() ?? 'BK${orderId.toString().padLeft(6, '0')}';
          _showSuccessDialog(bookingId, bookingNo);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(payResult.message ?? '支付确认失败，请稍后在订单中重试')));
          context.go('/orders');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '预订失败')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作异常：$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(int bookingId, String bookingNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('预订并支付成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预订编号：$bookingNo'),
            const SizedBox(height: 8),
            const Text('您的订单已生效，酒店将为您保留房间。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctx.pop();
              context.go('/orders');
            },
            child: const Text('查看订单', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.push('/online-checkin', extra: {'bookingId': bookingId});
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('在线办理入住'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20), onPressed: () => context.pop()),
        title: const Text('确认订单', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildOrderSummaryCard(),
            _buildSectionCard('入住人信息', [
              _InfoInputRow(label: '姓名', controller: _nameController, hint: '请填写真实姓名'),
              _InfoInputRow(label: '手机号', controller: _phoneController, hint: '接收确认短信', keyboardType: TextInputType.phone),
              _InfoInputRow(label: '证件号码', controller: _idNumberController, hint: '请输入有效证件号'),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(value: true, onChanged: (v) {}, activeColor: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  const Text('保存到常用入住人名册', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            _buildSectionCard('特殊要求', [
              TextField(
                controller: _specialRequestController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '如：高楼层、无烟房等',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSectionCard('支付方式', [
              _buildPaymentOption('balance', Icons.account_balance_wallet_outlined, '余额支付 (推荐)', Colors.blue),
              _buildPaymentOption('wechat', Icons.wechat_outlined, '微信支付', Colors.green),
              _buildPaymentOption('alipay', Icons.payment_outlined, '支付宝', Colors.blueAccent),
            ]),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildBottomPayBar(),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=200&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.hotelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${widget.roomType} · 1间', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateItem('入住', widget.checkInDate),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('1晚', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
              _buildDateItem('离店', widget.checkOutDate, isEnd: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem(String label, DateTime date, {bool isEnd = false}) {
    return Column(
      crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(DateFormat('MM-dd').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildBottomPayBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('应付总额 ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('¥', style: TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(widget.price.toStringAsFixed(0), style: const TextStyle(color: AppColors.secondary, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Row(
                  children: [
                    Icon(Icons.security, size: 12, color: AppColors.textHint),
                    SizedBox(width: 4),
                    Text('安全支付保障', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            height: 48,
            child: FilledButton(
              onPressed: _isLoading ? null : _submitBookingAndPay,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('确认支付', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, IconData icon, String label, Color iconColor) {
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v!),
              activeColor: AppColors.primary,
            ),
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

}

class _InfoInputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _InfoInputRow({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponBottomSheet extends StatelessWidget {
  final List<dynamic> coupons;
  final dynamic selectedCoupon;

  const _CouponBottomSheet({required this.coupons, this.selectedCoupon});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('选择优惠券', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('不使用优惠券'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: coupons.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.confirmation_number_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('暂无可用优惠券', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: coupons.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildCouponItem(context, null);
                        }
                        return _buildCouponItem(context, coupons[index - 1]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponItem(BuildContext context, dynamic coupon) {
    final isSelected = coupon != null && selectedCoupon != null && coupon['id'] == selectedCoupon['id'];
    final isNoneSelected = coupon == null && selectedCoupon == null;

    return GestureDetector(
      onTap: () => Navigator.pop(context, coupon),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isSelected || isNoneSelected) ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isSelected || isNoneSelected) ? AppColors.primary : AppColors.divider,
            width: (isSelected || isNoneSelected) ? 2 : 1,
          ),
        ),
        child: coupon == null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isNoneSelected)
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                  else
                    Icon(Icons.circle_outlined, color: AppColors.textHint.withValues(alpha: 0.5), size: 20),
                  const SizedBox(width: 8),
                  const Text('不使用优惠券', style: TextStyle(fontSize: 15)),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.secondary, AppColors.primary]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text('¥${coupon['discount_amount'] ?? '0'}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(coupon['min_spend'] != null ? '满${coupon['min_spend']}可用' : '无门槛', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(coupon['name'] ?? '优惠券', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('有效期至 ${coupon['expire_date'] ?? '长期有效'}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 24)
                  else
                    Icon(Icons.circle_outlined, color: AppColors.textHint.withValues(alpha: 0.3), size: 24),
                ],
              ),
      ),
    );
  }
}
