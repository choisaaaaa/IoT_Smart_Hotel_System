import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import '../../models/booking.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  final int orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  Booking? _order;
  bool _isLoading = true;
  bool _isCancelling = false;

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
      debugPrint('orderDetail: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return AppColors.primary;
      case 'pre_checked_in': return Colors.cyan;
      case 'checked_in': return AppColors.success;
      case 'checked_out': return AppColors.textSecondary;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending': return '待付款';
      case 'confirmed': return '已支付';
      case 'pre_checked_in': return '待确认';
      case 'checked_in': return '已入住';
      case 'checked_out': return '已完成';
      case 'cancelled': return '已取消';
      default: return '未知状态';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending': return Icons.access_time_rounded;
      case 'confirmed': return Icons.check_circle_outline_rounded;
      case 'pre_checked_in': return Icons.pending_actions_rounded;
      case 'checked_in': return Icons.hotel_rounded;
      case 'checked_out': return Icons.task_alt_rounded;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.help_outline_rounded;
    }
  }

  String _getStatusDesc(String? status) {
    switch (status) {
      case 'pending': return '请尽快完成支付，超时订单将自动取消';
      case 'confirmed': return '支付成功，可在线办理预入住';
      case 'pre_checked_in': return '预入住申请已提交，等待前台确认';
      case 'checked_in': return '已入住，祝您旅途愉快';
      case 'checked_out': return '已退房，期待您的再次光临';
      case 'cancelled': return '订单已取消';
      default: return '';
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
        title: const Text('订单详情', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_order != null && _order!.status != 'cancelled')
            IconButton(
              icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
              onPressed: () => _showMoreActions(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _fetchOrderDetail,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                        _buildTimelineCard(),
                        const SizedBox(height: 12),
                        if (_order!.canPay || _order!.canCheckin || _order!.canCancel || _order!.canExtend || _order!.canEnterRoom || _order!.canReview || _order!.canEditReview)
                          _buildActionButtons(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text('订单不存在或加载失败', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _fetchOrderDetail,
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusColor = _getStatusColor(_order!.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withValues(alpha: 0.15), statusColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getStatusIcon(_order!.status), color: statusColor, size: 28),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(_order!.status),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getStatusDesc(_order!.status),
            style: TextStyle(fontSize: 13, color: statusColor.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '订单号：${_order!.displayBookingNumber}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                      _order!.hotelName ?? '慧宿',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_order!.displayRoomType} · ${_order!.roomNumber ?? '${_order!.roomId}号房'}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('房型', _order!.displayRoomType),
          _buildInfoRow('房间号', _order!.roomNumber ?? '${_order!.roomId}号房'),
          _buildInfoRow('入住时间', DateUtils.formatDateTimeFull(_order!.checkInDate)),
          _buildInfoRow('离店时间', DateUtils.formatDateTimeFull(_order!.checkOutDate)),
          _buildInfoRow('入住天数', '${_order!.nights}晚'),
          _buildInfoRow('房间数量', '${_order!.guestCount}间'),
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
          const Text('入住信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildInfoRow('入住人', _order!.guestName ?? '-'),
          _buildInfoRow('联系电话', _order!.guestPhone ?? '-'),
          _buildInfoRow('证件号码', _maskIdNumber(_order!.guestIdNumber)),
          if (_order!.specialRequests != null && _order!.specialRequests.toString().isNotEmpty)
            _buildInfoRow('特殊要求', _order!.specialRequests!),
          if (_order!.paymentMethod != null && _order!.paymentMethod!.isNotEmpty)
            _buildInfoRow('支付方式', _paymentMethodText(_order!.paymentMethod!)),
        ],
      ),
    );
  }

  String _paymentMethodText(String method) {
    switch (method) {
      case 'alipay': return '支付宝';
      case 'wechat': return '微信支付';
      case 'balance': return '余额支付';
      case 'points': return '积分支付';
      default: return method;
    }
  }

  Widget _buildPriceDetailCard() {
    final totalPrice = _order!.totalPrice;
    final nights = _order!.nights;
    final pricePerNight = nights > 0 ? (totalPrice / nights).toStringAsFixed(2) : '0.00';

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('费用明细', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildPriceRow('房费（¥$pricePerNight × $nights晚）', totalPrice.toStringAsFixed(2)),
          if (_order!.usedPoints != null && _order!.usedPoints! > 0)
            _buildPriceRow('积分抵扣（${_order!.usedPoints}积分）', '-¥${(_order!.usedPoints! / 100).toStringAsFixed(2)}', color: Colors.orange),
          if (_order!.couponId != null)
            _buildPriceRow('优惠券抵扣', '-¥0.00', color: Colors.redAccent),
          const Divider(height: 1),
          _buildTotalRow('实付金额', totalPrice.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('订单进度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTimelineItem(
            Icons.receipt_long_outlined,
            '创建订单',
            _order!.createdAt != null ? DateUtils.formatDateTime(_order!.createdAt!) : '-',
            true,
          ),
          _buildTimelineItem(
            Icons.payment_rounded,
            '完成支付',
            _order!.status != 'pending' ? '已支付' : '待支付',
            _order!.status != 'pending',
          ),
          if (_order!.status == 'pre_checked_in' || _order!.status == 'checked_in' || _order!.status == 'checked_out')
            _buildTimelineItem(
              Icons.fact_check_outlined,
              '预入住申请',
              '已提交',
              true,
            ),
          if (_order!.status == 'checked_in' || _order!.status == 'checked_out')
            _buildTimelineItem(
              Icons.hotel_rounded,
              '正式入住',
              '已入住',
              true,
            ),
          if (_order!.status == 'checked_out')
            _buildTimelineItem(
              Icons.task_alt_rounded,
              '已退房',
              '已完成',
              true,
            ),
          if (_order!.status == 'cancelled')
            _buildTimelineItem(
              Icons.cancel_outlined,
              '已取消',
              '订单已取消',
              true,
              isLast: true,
              iconColor: AppColors.error,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(IconData icon, String title, String subtitle, bool completed, {bool isLast = false, Color? iconColor}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed ? (iconColor ?? AppColors.primary).withValues(alpha: 0.1) : AppColors.divider.withValues(alpha: 0.3),
                  ),
                  child: Icon(icon, size: 14, color: completed ? (iconColor ?? AppColors.primary) : AppColors.textHint),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: completed ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: completed ? AppColors.textPrimary : AppColors.textHint)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
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
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text('¥$value', style: TextStyle(fontSize: 14, color: color)),
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
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('¥$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
          if (_order!.canPay) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _handlePayment,
                child: const Text('立即支付', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_order!.status == 'confirmed') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => context.push('/online-checkin/${_order!.id}', extra: {'bookingId': _order!.id}),
                child: const Text('在线办理入住', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_order!.status == 'pre_checked_in') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: null,
                child: const Text('等待前台确认', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_order!.canEnterRoom) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => context.go('/room-service', extra: {'bookingId': widget.orderId}),
                child: const Text('进入房间', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (_order!.canExtend)
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => context.push('/extend-stay/${widget.orderId}', extra: {'bookingId': widget.orderId}),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                      child: const Text('在线续住'),
                    ),
                  ),
                ),
              if (_order!.canExtend && _order!.status == 'checked_in')
                const SizedBox(width: 12),
              if (_order!.status == 'checked_in')
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => context.push('/checkout/${widget.orderId}', extra: {'bookingId': widget.orderId}),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('自助退房'),
                    ),
                  ),
                ),
            ],
          ),
          if (_order!.canReview) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => context.push('/review-submit/${widget.orderId}', extra: {
                  'bookingId': widget.orderId,
                  'hotelId': _order?.hotelId,
                  'hotelName': _order?.hotelName,
                }),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('去评价'),
              ),
            ),
          ],
          if (_order!.canEditReview) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.push('/my-reviews'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                child: const Text('修改评价'),
              ),
            ),
          ],
          if (_order!.canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _handleCancel,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                child: _isCancelling
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
                    : const Text('取消订单'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMoreActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            if (_order!.canCancel)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
                title: const Text('取消订单', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCancel();
                },
              ),
            ListTile(
              leading: const Icon(Icons.headset_mic_outlined),
              title: const Text('联系客服'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/ai-butler');
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制订单号'),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _maskIdNumber(dynamic idNumber) {
    final str = idNumber?.toString() ?? '';
    if (str.isEmpty) return '-';
    if (str.length <= 10) return str;
    return '${str.substring(0, 6)}********${str.substring(14)}';
  }

  Future<void> _handlePayment() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认支付'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('订单金额：¥${_order!.totalPrice}'),
            const SizedBox(height: 8),
            const Text('请选择支付方式：'),
            const SizedBox(height: 8),
            _buildPaymentOption('alipay', Icons.payment_outlined, '支付宝', Colors.blueAccent),
            _buildPaymentOption('wechat', Icons.account_balance_wallet_outlined, '微信支付', Colors.green),
            _buildPaymentOption('balance', Icons.account_balance_outlined, '余额支付', Colors.blue),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _performPayment('alipay');
            },
            child: const Text('确认支付'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String method, IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _performPayment(String method) async {
    try {
      final createResult = await ref.read(paymentServiceProvider).createPayment({
        'order_type': 'booking',
        'order_id': widget.orderId,
        'amount': _order!.totalPrice,
        'payment_method': method,
      });

      if (!createResult.success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(createResult.message ?? '创建支付失败')));
        return;
      }

      final paymentIdRaw = createResult.data!['id'];
      final paymentId = paymentIdRaw is int ? paymentIdRaw : int.tryParse(paymentIdRaw.toString()) ?? 0;
      if (paymentId == 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支付订单ID无效')));
        return;
      }
      final payResult = await ref.read(paymentServiceProvider).pay(paymentId);

      if (payResult.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支付成功'), backgroundColor: AppColors.success));
        _fetchOrderDetail();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(payResult.message ?? '支付确认失败')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支付失败，请重试')));
      }
    }
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

    if (confirm != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      final result = await ref.read(bookingServiceProvider).cancelBooking(widget.orderId);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('订单已取消'), backgroundColor: AppColors.success),
        );
        _fetchOrderDetail();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '取消失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('取消失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }
}
