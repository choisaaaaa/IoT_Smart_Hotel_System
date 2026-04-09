import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  final int orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(bookingServiceProvider).getBookingById(widget.orderId);
      if (result.success && mounted) {
        setState(() {
          _order = result.data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching order detail: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}年${date.month}月${date.day}日';
    } catch (e) {
      return dateStr;
    }
  }

  int _calculateNights(String? checkIn, String? checkOut) {
    if (checkIn == null || checkOut == null) return 1;
    try {
      final inDate = DateTime.parse(checkIn);
      final outDate = DateTime.parse(checkOut);
      return outDate.difference(inDate).inDays;
    } catch (e) {
      return 1;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return AppColors.primary;
      case 'checked_in': return AppColors.success;
      case 'checked_out': return AppColors.textSecondary;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending': return '待支付';
      case 'confirmed': return '待入住';
      case 'checked_in': return '已入住';
      case 'checked_out': return '已完成';
      case 'cancelled': return '已取消';
      default: return '未知状态';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/orders');
            }
          },
        ),
        title: Text('订单详情', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('订单不存在'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 12),
                      _buildHotelInfoCard(),
                      const SizedBox(height: 12),
                      _buildGuestInfoCard(),
                      const SizedBox(height: 12),
                      _buildPriceDetailCard(),
                      const SizedBox(height: 12),
                      if (_order!['status'] == 'confirmed' || _order!['status'] == 'pending' || _order!['status'] == 'checked_in' || _order!['status'] == 'checked_out')
                        _buildActionButtons(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getStatusColor(_order!['status']).withValues(alpha: 0.1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(_order!['status']),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusText(_order!['status']),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '订单号：${_order!['id'] ?? widget.orderId}',
            style: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelInfoCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _order!['hotel_name'] ?? '智联酒店',
            style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('房型', _order!['room_type'] ?? '标准间'),
          _buildInfoRow('房间号', '${_order!['room_id'] ?? '-'}号房'),
          _buildInfoRow('入住时间', _formatDate(_order!['check_in_date'])),
          _buildInfoRow('离店时间', _formatDate(_order!['check_out_date'])),
          _buildInfoRow('入住天数', '${_calculateNights(_order!['check_in_date'], _order!['check_out_date'])}晚'),
          _buildInfoRow('房间数量', '${_order!['guest_count'] ?? 1}间'),
        ],
      ),
    );
  }

  Widget _buildGuestInfoCard() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('入住信息', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildInfoRow('入住人', _order!['guest_name'] ?? '-'),
          _buildInfoRow('联系电话', _order!['guest_phone'] ?? '-'),
          _buildInfoRow('证件号码', _maskIdNumber(_order!['guest_id_number'])),
          if (_order!['special_requests'] != null && _order!['special_requests'].toString().isNotEmpty)
            _buildInfoRow('特殊要求', _order!['special_requests']),
        ],
      ),
    );
  }

  Widget _buildPriceDetailCard() {
    final totalPrice = double.tryParse(_order!['total_price']?.toString() ?? '0') ?? 0.0;
    final nights = _calculateNights(_order!['check_in_date'], _order!['check_out_date']);
    final pricePerNight = nights > 0 ? (totalPrice / nights).toStringAsFixed(2) : '0.00';

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('费用明细', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildPriceRow('房费（¥$pricePerNight × $nights晚）', totalPrice.toStringAsFixed(2)),
          const Divider(height: 1),
          _buildTotalRow('总计', totalPrice.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text('¥$value', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('¥$value', style: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_order!['status'] == 'pending')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _handlePayment,
                child: const Text('立即支付', style: TextStyle(fontSize: 16)),
              ),
            ),
          if (_order!['status'] == 'confirmed') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _handleCheckIn,
                child: const Text('办理入住', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _handleCancel,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('取消订单'),
              ),
            ),
          ],
          if (_order!['status'] == 'checked_in') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => context.push('/checkout', extra: {'bookingId': widget.orderId}),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('自助退房', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.push('/extend-stay', extra: {'bookingId': widget.orderId}),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Text('在线续住'),
              ),
            ),
          ],
          if (_order!['status'] == 'checked_out')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.push('/review-submit', extra: {
                  'bookingId': widget.orderId,
                  'hotelId': _order?['hotel_id'],
                  'hotelName': _order?['hotel_name'],
                }),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Text('去评价'),
              ),
            ),
        ],
      ),
    );
  }

  String _maskIdNumber(dynamic idNumber) {
    final str = idNumber?.toString() ?? '';
    if (str.length <= 10) return str.isEmpty ? '-' : str;
    return '${str.substring(0, 6)}********${str.substring(14)}';
  }

  Future<void> _handlePayment() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认支付'),
        content: Text('订单金额：¥${_order!['total_price']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // 1. 创建支付记录
                final createResult = await ref.read(paymentServiceProvider).createPayment({
                  'order_type': 'booking',
                  'order_id': widget.orderId,
                  'amount': _order!['total_price'],
                  'payment_method': 'alipay',
                });
                
                if (!createResult.success) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(createResult.message ?? '创建支付失败')));
                  return;
                }

                // 2. 执行支付（模拟第三方支付回调后的确认）
                final paymentId = createResult.data!['id'];
                final payResult = await ref.read(paymentServiceProvider).pay(paymentId);
                
                if (payResult.success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支付成功'), backgroundColor: AppColors.success));
                  _fetchOrderDetail();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(payResult.message ?? '支付确认失败')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('支付异常：$e')));
                }
              }
            },
            child: const Text('确认支付'),
          ),
        ],
      ),
    );
  }

  void _handleCheckIn() {
    context.go('/room-service');
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消订单'),
        content: const Text('确定要取消此订单吗？取消后可能无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('再想想')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('订单已取消')));
      _fetchOrderDetail();
    }
  }
}
