import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  final int bookingId;

  const CheckoutPage({super.key, required this.bookingId});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  Booking? _booking;
  bool _isLoading = true;
  bool _isCheckingOut = false;
  int _currentStep = 0;

  final _invoiceTitleController = TextEditingController();
  final _invoiceTaxController = TextEditingController();
  String _invoiceType = 'personal';
  final _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookingDetail();
  }

  @override
  void dispose() {
    _invoiceTitleController.dispose();
    _invoiceTaxController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingDetail() async {
    setState(() => _isLoading = true);
    try {
      final result =
          await ref.read(bookingServiceProvider).getBookingById(widget.bookingId);
      if (result.success && mounted) {
        setState(() => _booking = result.data);
      }
    } catch (e) {
      debugPrint('鉁?booking: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateNights() {
    return _booking?.nights ?? 1;
  }

  double _getTotalPrice() {
    return _booking?.totalPrice ?? 0.0;
  }

  Future<void> _performCheckout() async {
    setState(() => _isCheckingOut = true);
    try {
      final result = await ref.read(bookingServiceProvider).selfCheckout(
            widget.bookingId,
            invoiceTitle: _invoiceTitleController.text.trim().isNotEmpty
                ? _invoiceTitleController.text.trim()
                : null,
            invoiceTaxNumber: _invoiceTaxController.text.trim().isNotEmpty
                ? _invoiceTaxController.text.trim()
                : null,
            invoiceType: _invoiceType,
            remark: _remarkController.text.trim().isNotEmpty
                ? _remarkController.text.trim()
                : null,
          );

      if (result.success && mounted) {
        setState(() => _currentStep = 3);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '退房失败，请重试')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('退房失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '自助退房',
          style: GoogleFonts.notoSansSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _booking == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text('订单信息加载失败',
                          style: GoogleFonts.notoSansSc(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : _currentStep == 3
                  ? _buildSuccessView()
                  : Column(
                      children: [
                        _buildStepIndicator(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildBookingSummary(),
                                const SizedBox(height: 12),
                                if (_currentStep == 0) ...[
                                  _buildFeeConfirmation(),
                                  const SizedBox(height: 24),
                                  _buildNextButton('确认费用，下一步'),
                                ],
                                if (_currentStep == 1) ...[
                                  _buildInvoiceForm(),
                                  const SizedBox(height: 24),
                                  _buildStep1Buttons(),
                                ],
                                if (_currentStep == 2) ...[
                                  _buildCheckoutConfirmation(),
                                  const SizedBox(height: 24),
                                  _buildStep2Buttons(),
                                ],
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['费用确认', '发票信息', '确认退房'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.white,
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? AppColors.primary : AppColors.divider,
                        ),
                        child: Center(
                          child: isActive && index < _currentStep
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : Text(
                                  '${index + 1}',
                                  style: GoogleFonts.notoSansSc(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? Colors.white : AppColors.textHint,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[index],
                        style: GoogleFonts.notoSansSc(
                          fontSize: 11,
                          color: isCurrent
                              ? AppColors.primary
                              : isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: index < _currentStep ? AppColors.primary : AppColors.divider,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBookingSummary() {
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
                    Text(
                      _booking?.hotelName ?? '慧宿',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_booking?.displayRoomType} · ${_booking?.roomNumber ?? '${_booking?.roomId}号房'}',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('入住日期',
                        style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textHint)),
                    Text(DateUtils.formatDateCN(_booking?.checkInDate),
                        style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('退房日期',
                        style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textHint)),
                    Text(DateUtils.formatDateCN(_booking?.checkOutDate),
                        style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('入住天数',
                      style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textHint)),
                  Text('${_calculateNights()}晚',
                      style: GoogleFonts.notoSansSc(
                          fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeeConfirmation() {
    final totalPrice = _getTotalPrice();
    final nights = _calculateNights();
    final pricePerNight = nights > 0 ? totalPrice / nights : 0;

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
              style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildFeeRow('房费（¥${pricePerNight.toStringAsFixed(2)} × $nights晚）',
              '¥${totalPrice.toStringAsFixed(2)}'),
          _buildFeeRow('服务费', '¥0.00'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('应付总额',
                  style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('¥${totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.notoSansSc(
                      fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '退房后押金将在1-3个工作日内原路退回',
                    style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.notoSansSc(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.notoSansSc(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInvoiceForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('发票信息（可选）',
              style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('如需发票，请填写以下信息',
              style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 16),
          Text('发票类型',
              style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _invoiceType = 'personal'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _invoiceType == 'personal'
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _invoiceType == 'personal'
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                    ),
                    child: Center(
                      child: Text('个人',
                          style: GoogleFonts.notoSansSc(
                            fontSize: 14,
                            color: _invoiceType == 'personal'
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          )),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _invoiceType = 'company'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _invoiceType == 'company'
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _invoiceType == 'company'
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                    ),
                    child: Center(
                      child: Text('企业',
                          style: GoogleFonts.notoSansSc(
                            fontSize: 14,
                            color: _invoiceType == 'company'
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          )),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _invoiceTitleController,
            decoration: InputDecoration(
              labelText: _invoiceType == 'company' ? '企业名称' : '发票抬头',
              hintText: _invoiceType == 'company' ? '请输入企业全称' : '请输入个人姓名',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (_invoiceType == 'company') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _invoiceTaxController,
              decoration: InputDecoration(
                labelText: '税号',
                hintText: '请输入企业税号',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _remarkController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '退房备注（可选）',
              hintText: '如有特殊要求请在此备注',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutConfirmation() {
    final totalPrice = _getTotalPrice();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('退房确认',
              style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('请确认以下信息',
                          style: GoogleFonts.notoSansSc(
                              fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.warning)),
                      const SizedBox(height: 4),
                      Text(
                        '• 退房后房卡将自动失效\n• 押金将在1-3个工作日内退回\n• 如需发票，退房后可在订单详情中下载',
                        style: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildConfirmRow('房间', '${_booking?.displayRoomType} ${_booking?.roomNumber ?? '${_booking?.roomId}号房'}'),
          _buildConfirmRow('退房日期', DateUtils.formatDateCN(_booking?.checkOutDate)),
          _buildConfirmRow('应付金额', '¥${totalPrice.toStringAsFixed(2)}'),
          if (_invoiceTitleController.text.trim().isNotEmpty)
            _buildConfirmRow('发票抬头', _invoiceTitleController.text.trim()),
          if (_remarkController.text.trim().isNotEmpty)
            _buildConfirmRow('备注', _remarkController.text.trim()),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.notoSansSc(fontSize: 14, color: AppColors.textSecondary)),
          Flexible(
            child: Text(value,
                style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton(String text) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: () => setState(() => _currentStep++),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          text,
          style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStep1Buttons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('上一步', style: GoogleFonts.notoSansSc(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => setState(() => _currentStep = 2),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('下一步',
                  style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Buttons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('上一步', style: GoogleFonts.notoSansSc(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isCheckingOut ? null : _performCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                disabledBackgroundColor: AppColors.error.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCheckingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('确认退房',
                      style: GoogleFonts.notoSansSc(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: AppColors.success),
            ),
            const SizedBox(height: 24),
            Text('退房成功',
                style: GoogleFonts.notoSansSc(
                    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Text(
              '您的退房申请已提交成功\n押金将在1-3个工作日内原路退回\n感谢您的入住，期待再次光临！',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansSc(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.8),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('返回',
                    style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  context.push('/review-submit/${widget.bookingId}', extra: {
                    'bookingId': widget.bookingId,
                    'hotelId': _booking?.hotelId,
                    'hotelName': _booking?.hotelName,
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('去评价',
                    style: GoogleFonts.notoSansSc(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
