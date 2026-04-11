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
  final int hotelId;
  final DateTime checkInDate;
  final DateTime checkOutDate;

  const BookingFlowPage({
    super.key,
    required this.hotelName,
    required this.roomType,
    required this.price,
    required this.roomId,
    required this.hotelId,
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
  final int _roomCount = 1;
  List<dynamic> _coupons = [];
  dynamic _selectedCoupon;
  // ignore: unused_field
  bool _isLoadingCoupons = false;
  String _paymentMethod = 'balance'; // balance, wechat, alipay
  Map<String, dynamic>? _priceDetails;

  @override
  void initState() {
    super.initState();
    debugPrint('📝 [BookingFlow] Initialized with roomId: ${widget.roomId}, hotelName: ${widget.hotelName}');
    _loadUserInfo();
    _loadMemberInfo();
    _loadCoupons();
    _calculatePrice();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    // 只有当输入了完整的手机号（11位）时才重新计算价格，避免频繁调用
    if (_phoneController.text.trim().length == 11) {
      _calculatePrice();
    }
  }

  Future<void> _calculatePrice() async {
    final phone = _phoneController.text.trim().isNotEmpty 
        ? _phoneController.text.trim() 
        : (await ref.read(authServiceProvider).getCurrentUser())?.phone;

    final result = await ref.read(bookingServiceProvider).calculatePrice(
      roomId: widget.roomId,
      checkInDate: widget.checkInDate,
      checkOutDate: widget.checkOutDate,
      guestPhone: phone,
      couponId: _selectedCoupon?['id'],
      usedPoints: _usePoints ? _pointsToUse : 0,
    );

    if (result.success && mounted) {
      setState(() {
        _priceDetails = result.data;
        if (_usePoints && result.data?['used_points'] != null) {
          _pointsToUse = result.data!['used_points'];
        }
      });
    } else if (mounted) {
      debugPrint('❌ [BookingFlow] Price calculation failed: ${result.message}');
      // 如果后端报错房间不存在，说明可能是 roomId 传递错误
      if (result.message?.contains('房间不存在') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取房间信息失败，请尝试重新选择房间'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  bool _usePoints = false;
  int _pointsToUse = 0;
  Map<String, dynamic>? _memberInfo;

  Future<void> _loadMemberInfo() async {
    final result = await ref.read(memberServiceProvider).getMyAssets();
    if (result.success && mounted) {
      setState(() => _memberInfo = result.data);
    }
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

    if (mounted) {
      setState(() => _selectedCoupon = selected);
      _calculatePrice();
    }
  }

  Future<void> _loadUserInfo() async {
    final user = await ref.read(authServiceProvider).getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _nameController.text = user.username;
        _phoneController.text = '';
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

    if (widget.roomId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('房间信息异常，请返回重新选择房型'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. 创建预订 (状态为待支付)
      final result = await ref.read(bookingServiceProvider).createBooking({
        'hotel_id': widget.hotelId,
        'room_id': widget.roomId,
        'guest_name': _nameController.text.trim(),
        'guest_phone': _phoneController.text.trim(),
        'guest_id_number': _idNumberController.text.trim(),
        'check_in_date': widget.checkInDate.toIso8601String().split('T')[0],
        'check_out_date': widget.checkOutDate.toIso8601String().split('T')[0],
        'guest_count': _roomCount,
        'payment_method': _paymentMethod,
        'special_requests': _specialRequestController.text.trim(),
        'coupon_id': _selectedCoupon?['id'],
        'used_points': _usePoints ? _pointsToUse : 0,
      });

      if (!mounted) return;

      if (result.success) {
        final orderIdRaw = result.data!['id'];
        // 确保 orderId 是 int 类型
        final orderId = orderIdRaw is int ? orderIdRaw : int.tryParse(orderIdRaw.toString()) ?? 0;
        if (orderId == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('订单ID无效')));
          }
          setState(() => _isLoading = false);
          return;
        }
        
        final totalPrice = _priceDetails?['total_price'] ?? result.data!['total_price'] ?? result.data!['total_amount'] ?? widget.price * widget.checkOutDate.difference(widget.checkInDate).inDays;

        // 2. 创建支付记录
        debugPrint('💳 [BookingFlow] Creating payment for orderId: $orderId, amount: $totalPrice');
        final createPayResult = await ref.read(paymentServiceProvider).createPayment({
          'order_type': 'booking',
          'order_id': orderId,
          'amount': totalPrice,
          'payment_method': _paymentMethod,
        });

        debugPrint('💳 [BookingFlow] Create payment result: success=${createPayResult.success}, data=${createPayResult.data}');

        if (!createPayResult.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(createPayResult.message ?? '创建支付订单失败')));
            // 取消自动跳转到订单页，让用户留在当前页处理
          }
          setState(() => _isLoading = false);
          return;
        }

        // 3. 模拟支付确认流程
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在确认支付状态...')));
        await Future.delayed(const Duration(seconds: 1));

        // 4. 确认支付
        final paymentIdRaw = createPayResult.data?['id'];
        if (paymentIdRaw == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支付订单创建异常，请稍后在订单中查看')));
          }
          setState(() => _isLoading = false);
          return;
        }
        // 确保 paymentId 是 int 类型
        final paymentId = paymentIdRaw is int ? paymentIdRaw : int.tryParse(paymentIdRaw.toString()) ?? 0;
        if (paymentId == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支付订单ID无效')));
          }
          setState(() => _isLoading = false);
          return;
        }
        final payResult = await ref.read(paymentServiceProvider).pay(paymentId);
        
        if (payResult.success && mounted) {
          final bookingId = result.data!['id'] as int? ?? orderId;
          final bookingNo = result.data!['booking_number']?.toString() ?? result.data!['booking_no']?.toString() ?? 'BK${orderId.toString().padLeft(6, '0')}';
          _showSuccessDialog(bookingId, bookingNo);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(payResult.message ?? '支付确认失败，请稍后在订单中重试')));
          // 取消自动跳转，保持在当前预订流程页
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
              Navigator.pop(ctx);
              context.go('/orders');
            },
            child: const Text('查看订单', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
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
              RadioGroup<String>(
                groupValue: _paymentMethod,
                onChanged: (v) => setState(() => _paymentMethod = v!),
                child: Column(
                  children: [
                    _buildPaymentOption('balance', Icons.account_balance_wallet_outlined, '余额支付 (推荐)', Colors.blue),
                    _buildPaymentOption('wechat', Icons.wechat_outlined, '微信支付', Colors.green),
                    _buildPaymentOption('alipay', Icons.payment_outlined, '支付宝', Colors.blueAccent),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSectionCard('优惠与抵扣', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('使用优惠券', style: TextStyle(fontSize: 14)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCoupon != null 
                        ? (_selectedCoupon!['coupon_type'] == 'discount' 
                            ? '${_selectedCoupon!['discount_value']}折' 
                            : '-¥${_selectedCoupon!['discount_value']}')
                        : (_coupons.isNotEmpty ? '${_coupons.length}张可用' : '无可用'),
                      style: TextStyle(
                        color: _selectedCoupon != null ? AppColors.secondary : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
                  ],
                ),
                onTap: _showCouponSelector,
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('积分抵扣', style: TextStyle(fontSize: 14)),
                subtitle: Text('可用 ${_memberInfo?['points'] ?? 0} 积分', style: const TextStyle(fontSize: 12)),
                value: _usePoints,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _usePoints = val;
                    if (val) {
                      _pointsToUse = _memberInfo?['points'] ?? 0;
                    }
                  });
                  _calculatePrice();
                },
              ),
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
    final double basePrice = widget.price * widget.checkOutDate.difference(widget.checkInDate).inDays;
    double totalPrice = _priceDetails?['total_price']?.toDouble() ?? basePrice;
    double discountRate = _priceDetails?['discount_rate']?.toDouble() ?? 1.0;
    int pointsUsed = _priceDetails?['used_points'] ?? 0;
    double pointsDiscount = _priceDetails?['points_discount']?.toDouble() ?? 0.0;
    double couponDiscount = _priceDetails?['coupon_discount']?.toDouble() ?? 0.0;
    
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('总计', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('¥', style: TextStyle(color: AppColors.secondary, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      totalPrice.toStringAsFixed(2),
                      style: const TextStyle(color: AppColors.secondary, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (discountRate < 1.0)
                        _buildPriceTag('会员${(discountRate * 10).toStringAsFixed(1)}折', AppColors.gold),
                      if (couponDiscount > 0)
                        _buildPriceTag('优惠券-¥${couponDiscount.toStringAsFixed(0)}', Colors.redAccent),
                      if (pointsUsed > 0)
                        _buildPriceTag('积分抵¥${pointsDiscount.toStringAsFixed(1)}', Colors.orange),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitBookingAndPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('立即预订', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
