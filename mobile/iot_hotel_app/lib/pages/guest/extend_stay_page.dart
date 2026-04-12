import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';

class ExtendStayPage extends ConsumerStatefulWidget {
  final int bookingId;

  const ExtendStayPage({super.key, required this.bookingId});

  @override
  ConsumerState<ExtendStayPage> createState() => _ExtendStayPageState();
}

class _ExtendStayPageState extends ConsumerState<ExtendStayPage> {
  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  bool _isSubmitting = false;
  DateTime? _newCheckOutDate;
  int _extendNights = 1;

  @override
  void initState() {
    super.initState();
    _loadBookingDetail();
  }

  Future<void> _loadBookingDetail() async {
    setState(() => _isLoading = true);
    try {
      final result =
          await ref.read(bookingServiceProvider).getBookingById(widget.bookingId);
      if (result.success && mounted) {
        setState(() {
          _booking = result.data;
          if (_booking?['check_out_date'] != null) {
            final currentCheckOut = DateTime.parse(_booking!['check_out_date']);
            _newCheckOutDate = currentCheckOut.add(Duration(days: _extendNights));
          }
        });
      }
    } catch (e) {
      debugPrint('鉁?booking: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime get _currentCheckOutDate {
    if (_booking?['check_out_date'] == null) return DateTime.now();
    try {
      return DateTime.parse(_booking!['check_out_date']);
    } catch (e) {
      return DateTime.now();
    }
  }

  double get _pricePerNight {
    final totalPrice = double.tryParse(_booking?['total_price']?.toString() ?? '0') ?? 0.0;
    final nights = _currentNights;
    return nights > 0 ? totalPrice / nights : 0;
  }

  int get _currentNights {
    final checkIn = _booking?['check_in_date'];
    final checkOut = _booking?['check_out_date'];
    if (checkIn == null || checkOut == null) return 1;
    try {
      return DateTime.parse(checkOut).difference(DateTime.parse(checkIn)).inDays;
    } catch (e) {
      return 1;
    }
  }

  double get _extendPrice => _pricePerNight * _extendNights;

  void _updateExtendNights(int nights) {
    setState(() {
      _extendNights = nights.clamp(1, 30);
      _newCheckOutDate = _currentCheckOutDate.add(Duration(days: _extendNights));
    });
  }

  Future<void> _submitExtendStay() async {
    if (_newCheckOutDate == null) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(bookingServiceProvider).extendStay(
            widget.bookingId,
            newCheckOutDate: _newCheckOutDate!,
          );

      if (result.success && mounted) {
        final needPayment = result.data?['need_payment'] == true ||
            result.data?['additional_price'] != null;
        if (needPayment) {
          final additionalPrice = result.data?['additional_price'];
          if (additionalPrice != null) {
            final payConfirmed = await _showPaymentConfirm(additionalPrice);
            if (payConfirmed == true) {
              _showSuccess();
            }
          } else {
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

  Future<bool?> _showPaymentConfirm(dynamic additionalPrice) async {
    final price = double.tryParse(additionalPrice.toString()) ?? _extendPrice;
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
            Text('¥${price.toStringAsFixed(2)}',
                style: GoogleFonts.notoSansSc(
                    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                final payResult = await ref.read(paymentServiceProvider).createPayment({
                  'order_type': 'booking_extend',
                  'order_id': widget.bookingId,
                  'amount': price,
                  'payment_method': 'alipay',
                });
                if (payResult.success && payResult.data != null) {
                  await ref.read(paymentServiceProvider).pay(payResult.data!['id']);
                }
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
              child: const Icon(Icons.check_circle_rounded,
                  size: 40, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            Text('续住成功',
                style: GoogleFonts.notoSansSc(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '您的退房日期已更新为${DateFormat('yyyy年MM月dd日').format(_newCheckOutDate!)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansSc(
                  fontSize: 14, color: AppColors.textSecondary),
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
              child: Text('确定',
                  style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
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
        title: Text('在线续住',
            style: GoogleFonts.notoSansSc(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _booking == null
              ? Center(
                  child: Text('订单信息加载失败',
                      style: GoogleFonts.notoSansSc(color: AppColors.textSecondary)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentStayInfo(),
                      const SizedBox(height: 16),
                      _buildExtendSelector(),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hotel_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_booking?['hotel_name'] ?? '智联酒店',
                        style: GoogleFonts.notoSansSc(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      '${_booking?['room_type'] ?? '标准间'} · ${_booking?['room_id'] ?? '-'}号房',
                      style: GoogleFonts.notoSansSc(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildDateInfo('入住日期', _booking?['check_in_date']),
              ),
              Container(width: 1, height: 40, color: AppColors.divider),
              Expanded(
                child: _buildDateInfo('当前退房', _booking?['check_out_date']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String? dateStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 4),
          Text(
            dateStr != null
                ? DateFormat('MM月dd日').format(DateTime.parse(dateStr))
                : '-',
            style: GoogleFonts.notoSansSc(
                fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildExtendSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择续住天数',
              style: GoogleFonts.notoSansSc(
                  fontSize: 16, fontWeight: FontWeight.bold)),
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
                        style: GoogleFonts.notoSansSc(
                            fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text('晚',
                        style: GoogleFonts.notoSansSc(
                            fontSize: 14, color: AppColors.textSecondary)),
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
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '新退房日期：${DateFormat('yyyy年MM月dd日').format(_newCheckOutDate!)}',
                    style: GoogleFonts.notoSansSc(
                        fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary),
                  ),
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
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('费用明细',
              style: GoogleFonts.notoSansSc(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('续住房费（¥${_pricePerNight.toStringAsFixed(2)} × $_extendNights晚）',
                  style: GoogleFonts.notoSansSc(
                      fontSize: 14, color: AppColors.textSecondary)),
              Text('¥${_extendPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.notoSansSc(fontSize: 14)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('续住费用合计',
                  style: GoogleFonts.notoSansSc(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text('¥${_extendPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.notoSansSc(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.info),
              const SizedBox(width: 6),
              Text('温馨提示',
                  style: GoogleFonts.notoSansSc(
                      fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.info)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• 续住需视房间可用情况而定\n• 续住费用将按原房型价格计算\n• 续住成功后不可撤销\n• 如需帮助请联系前台',
            style: GoogleFonts.notoSansSc(
                fontSize: 12, color: AppColors.textSecondary, height: 1.8),
          ),
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
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text('确认续住',
                style: GoogleFonts.notoSansSc(
                    fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
