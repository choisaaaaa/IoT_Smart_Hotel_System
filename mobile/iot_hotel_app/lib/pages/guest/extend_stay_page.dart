import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../services/member_service.dart';
import '../../services/payment_service.dart';
import '../../models/booking.dart';
import '../../models/member.dart';
import '../../models/coupon.dart';

class ExtendStayPage extends ConsumerStatefulWidget {
  final int bookingId;

  const ExtendStayPage({super.key, required this.bookingId});

  @override
  ConsumerState<ExtendStayPage> createState() => _ExtendStayPageState();
}

class _ExtendStayPageState extends ConsumerState<ExtendStayPage> {
  Booking? _booking;
  bool _isLoading = true;
  bool _isSubmitting = false;
  DateTime? _newCheckOutDate;
  int _extendNights = 1;

  List<Coupon> _coupons = [];
  Coupon? _selectedCoupon;
  bool _usePoints = false;
  int _pointsToUse = 0;
  Member? _memberInfo;
  String _paymentMethod = 'balance';
  Map<String, dynamic>? _priceDetails;

  @override
  void initState() {
    super.initState();
    _loadBookingDetail();
    _loadMemberInfo();
    _loadCoupons();
  }

  Future<void> _loadBookingDetail() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(bookingServiceProvider).getBookingById(widget.bookingId);
      if (result.success && mounted) {
        setState(() {
          _booking = result.data;
          if (_booking != null) {
            _newCheckOutDate = _booking!.checkOutDate.add(Duration(days: _extendNights));
          }
        });
        _calculatePrice();
      }
    } catch (e) {
      debugPrint('booking: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMemberInfo() async {
    final result = await ref.read(memberServiceProvider).getMyAssets();
    if (result.success && mounted) {
      setState(() => _memberInfo = result.data);
    }
  }

  Future<void> _loadCoupons() async {
    try {
      final result = await ref.read(memberServiceProvider).getMyCoupons();
      if (result.success && mounted) {
        setState(() => _coupons = result.data ?? []);
      }
    } catch (e) {
      debugPrint('coupons: $e');
    }
  }

  void _updateExtendNights(int nights) {
    if (_booking == null) return;
    setState(() {
      _extendNights = nights.clamp(1, 30);
      _newCheckOutDate = _booking!.checkOutDate.add(Duration(days: _extendNights));
    });
    _calculatePrice();
  }

  Future<void> _calculatePrice() async {
    if (_newCheckOutDate == null || _booking == null) return;

    try {
      final result = await ref.read(bookingServiceProvider).calculateExtendPrice(
        widget.bookingId,
        newCheckOutDate: _newCheckOutDate!,
        couponId: _selectedCoupon?.id,
        usedPoints: _usePoints ? _pointsToUse : 0,
      );

      if (result.success && mounted) {
        setState(() {
          _priceDetails = result.data;
          if (_usePoints && result.data?['used_points'] != null) {
            _pointsToUse = result.data!['used_points'];
          }
        });
      }
    } catch (e) {
      debugPrint('calculateExtendPrice: $e');
    }
  }

  void _showCouponSelector() async {
    final selected = await showModalBottomSheet<Coupon?>(
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

  Future<void> _submitExtendStay() async {
    if (_newCheckOutDate == null) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(bookingServiceProvider).extendStay(
        widget.bookingId,
        newCheckOutDate: _newCheckOutDate!,
        couponId: _selectedCoupon?.id,
        usedPoints: _usePoints ? _pointsToUse : 0,
        paymentMethod: _paymentMethod,
      );

      if (result.success && mounted) {
        final needPayment = result.data?['need_payment'] == true;
        final paymentId = result.data?['payment_id'];

        if (needPayment && paymentId != null) {
          final additionalPrice = double.tryParse(result.data?['additional_price']?.toString() ?? '0') ?? 0;
          final payConfirmed = await _showPaymentConfirm(additionalPrice, paymentId);
          if (payConfirmed == true) {
            _showSuccess();
          }
        } else {
          _showSuccess();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '续住申请失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('续住失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool?> _showPaymentConfirm(double additionalPrice, int paymentId) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认支付续住费用'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('续住$_extendNights晚，需支付额外费用：'),
            const SizedBox(height: 8),
            Text('¥${additionalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
            if ((_priceDetails?['coupon_discount'] ?? 0) > 0) ...[
              const SizedBox(height: 4),
              Text('优惠券抵扣：-¥${_priceDetails?['coupon_discount']}', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            if ((_priceDetails?['points_discount'] ?? 0) > 0) ...[
              const SizedBox(height: 2),
              Text('积分抵扣：-¥${_priceDetails?['points_discount']}', style: const TextStyle(color: Colors.orange, fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(paymentServiceProvider).pay(paymentId);
              } catch (e) {
                debugPrint('Payment error: $e');
              }
              if (mounted) _showSuccess();
            },
            child: const Text('确认支付'),
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 40, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            const Text('续住成功', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '您的退房日期已更新为${_newCheckOutDate != null ? DateFormat('yyyy年MM月dd日').format(_newCheckOutDate!) : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('确定', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
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
        title: const Text('在线续住', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _booking == null
              ? Center(child: Text('订单信息加载失败', style: TextStyle(color: AppColors.textSecondary)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentStayInfo(),
                      const SizedBox(height: 16),
                      _buildExtendSelector(),
                      const SizedBox(height: 16),
                      _buildDiscountSection(),
                      const SizedBox(height: 16),
                      _buildPaymentMethodSection(),
                      const SizedBox(height: 16),
                      _buildPriceSummary(),
                      const SizedBox(height: 16),
                      _buildNotes(),
                      const SizedBox(height: 32),
                      _buildSubmitButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCurrentStayInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.hotel_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_booking!.hotelName ?? '智联酒店', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${_booking!.displayRoomType} · ${_booking!.roomNumber ?? '${_booking!.roomId}号房'}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(child: _buildDateInfo('入住日期', _booking!.checkInDate)),
              Container(width: 1, height: 40, color: AppColors.divider),
              Expanded(child: _buildDateInfo('当前退房', _booking!.checkOutDate)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 4),
          Text(DateFormat('MM月dd日').format(date),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildExtendSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择续住天数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNightButton(Icons.remove, () => _updateExtendNights(_extendNights - 1)),
              Container(
                width: 120,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text('$_extendNights',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const Text('晚', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _buildNightButton(Icons.add, () => _updateExtendNights(_extendNights + 1)),
            ],
          ),
          const SizedBox(height: 16),
          if (_newCheckOutDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('新退房日期：${DateFormat('yyyy年MM月dd日').format(_newCheckOutDate!)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNightButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('优惠与抵扣', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('使用优惠券', style: TextStyle(fontSize: 14)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedCoupon != null
                      ? _selectedCoupon!.displayValue
                      : (_coupons.isNotEmpty ? '${_coupons.length}张可用' : '无可用'),
                  style: TextStyle(color: _selectedCoupon != null ? AppColors.secondary : AppColors.textSecondary, fontSize: 13),
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
            subtitle: Text('可用 ${_memberInfo?.points ?? 0} 积分', style: const TextStyle(fontSize: 12)),
            value: _usePoints,
            activeThumbColor: AppColors.primary,
            onChanged: (val) {
              setState(() {
                _usePoints = val;
                if (val) {
                  _pointsToUse = _memberInfo?.points ?? 0;
                }
              });
              _calculatePrice();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('支付方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: _paymentMethod,
            onChanged: (v) { if (v != null) setState(() => _paymentMethod = v); },
            child: Column(
              children: [
                _buildPaymentOption('balance', Icons.account_balance_wallet_outlined, '余额支付 (推荐)', Colors.blue),
                _buildPaymentOption('wechat', Icons.wechat_outlined, '微信支付', Colors.green),
                _buildPaymentOption('alipay', Icons.payment_outlined, '支付宝', Colors.blueAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, IconData icon, String label, Color iconColor) {
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildPriceSummary() {
    final double basePrice = _priceDetails?['base_price']?.toDouble() ?? 0;
    final double discountRate = _priceDetails?['discount_rate']?.toDouble() ?? 1.0;
    final double memberDiscount = _priceDetails?['member_discount']?.toDouble() ?? 0;
    final double couponDiscount = _priceDetails?['coupon_discount']?.toDouble() ?? 0;
    final double pointsDiscount = _priceDetails?['points_discount']?.toDouble() ?? 0;
    final int usedPoints = _priceDetails?['used_points'] ?? 0;
    final double totalPrice = _priceDetails?['total_price']?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('费用明细', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildPriceRow('续住房费（$_extendNights晚）', '¥${basePrice.toStringAsFixed(2)}'),
          if (discountRate < 1.0)
            _buildPriceRow('会员折扣（${(discountRate * 10).toStringAsFixed(1)}折）', '-¥${memberDiscount.toStringAsFixed(2)}', color: AppColors.gold),
          if (couponDiscount > 0)
            _buildPriceRow('优惠券抵扣', '-¥${couponDiscount.toStringAsFixed(2)}', color: Colors.redAccent),
          if (usedPoints > 0)
            _buildPriceRow('积分抵扣（$usedPoints积分）', '-¥${pointsDiscount.toStringAsFixed(2)}', color: Colors.orange),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('续住费用合计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('¥${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 14, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.info),
              const SizedBox(width: 6),
              const Text('温馨提示', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.info)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('• 续住需视房间可用情况而定\n• 续住费用支持会员折扣、优惠券和积分抵扣\n• 续住成功后不可撤销\n• 如需帮助请联系前台',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.8)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _isSubmitting ? null : _submitExtendStay,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSubmitting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('确认续住', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _CouponBottomSheet extends StatelessWidget {
  final List<Coupon> coupons;
  final Coupon? selectedCoupon;

  const _CouponBottomSheet({required this.coupons, this.selectedCoupon});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('不使用', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: coupons.isEmpty
                  ? const Center(child: Text('暂无可用优惠券', style: TextStyle(color: AppColors.textHint)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: coupons.length,
                      itemBuilder: (ctx, index) {
                        final coupon = coupons[index];
                        final isSelected = selectedCoupon != null && coupon.id == selectedCoupon!.id;
                        return _buildCouponItem(coupon, isSelected, context);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponItem(Coupon coupon, bool isSelected, BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, coupon),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text(coupon.displayValue,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coupon.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(coupon.displayCondition, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
