import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import '../../models/booking.dart';

class OrderListPage extends ConsumerStatefulWidget {
  final int? initialTab;
  const OrderListPage({super.key, this.initialTab});

  @override
  ConsumerState<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends ConsumerState<OrderListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Booking> _orders = [];

  static const _tabs = [
    {'key': 'all', 'label': '全部'},
    {'key': 'pending', 'label': '待付款'},
    {'key': 'confirmed', 'label': '已支付'},
    {'key': 'checked_in', 'label': '已入住'},
    {'key': 'checked_out', 'label': '已完成'},
    {'key': 'cancelled', 'label': '已取消'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: widget.initialTab ?? 0);
    _fetchOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(bookingServiceProvider).getBookings(pageSize: 50);
      if (result.success) {
        setState(() => _orders = result.data ?? []);
      }
    } catch (e) {
      debugPrint('orders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              context.go('/');
            }
          },
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('我的订单', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary, size: 18),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _fetchOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _tabs.map((t) => _buildOrderList(t['key']!)).toList(),
            ),
    );
  }

  Widget _buildOrderList(String filterStatus) {
    final filteredOrders = filterStatus == 'all'
        ? _orders
        : _orders.where((o) => o.status == filterStatus).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('暂无相关订单', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/hotel-list'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('去预订'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return GestureDetector(
            onTap: () => context.push('/order-detail/${order.id}'),
            child: _buildOrderItem(order),
          );
        },
      ),
    );
  }

  Widget _buildOrderItem(Booking order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=400&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            order.hotelName ?? '智联酒店',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusTag(order.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${DateUtils.formatDotDateTime(order.checkInDate)} - ${DateUtils.formatDotDateTime(order.checkOutDate)} 共${order.nights}晚',
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.displayRoomType} | ${order.guestCount}间',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('¥', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(order.totalPrice.toStringAsFixed(2), style: const TextStyle(color: AppColors.secondary, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActionButtons(order),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'pending':
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        break;
      case 'confirmed':
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        textColor = AppColors.primary;
        break;
      case 'pre_checked_in':
        bgColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        break;
      case 'checked_in':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        break;
      case 'checked_out':
        bgColor = AppColors.textHint.withValues(alpha: 0.1);
        textColor = AppColors.textSecondary;
        break;
      case 'cancelled':
        bgColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
        break;
      default:
        bgColor = AppColors.textHint.withValues(alpha: 0.1);
        textColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        Booking(id: 0, roomId: 0, checkInDate: DateTime.now(), checkOutDate: DateTime.now(), status: status).statusText,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildActionButtons(Booking order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (order.canPay) ...[
          FilledButton(
            onPressed: () => _handlePay(order),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('去支付', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _showCancelDialog(order),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('取消订单', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ),
        ],
        if (order.status == 'confirmed') ...[
          FilledButton(
            onPressed: () => context.push('/online-checkin/${order.id}', extra: {'bookingId': order.id}),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('预入住', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _showCancelDialog(order),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('取消订单', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ),
        ],
        if (order.status == 'pre_checked_in') ...[
          OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('待确认', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
          ),
        ],
        if (order.canEnterRoom) ...[
          FilledButton(
            onPressed: () => context.push('/room-service', extra: {'bookingId': order.id}),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('进入房间', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          if (order.canExtend)
            OutlinedButton(
              onPressed: () => context.push('/extend-stay/${order.id}', extra: {'bookingId': order.id}),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('续住', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            ),
        ],
        if (order.canReview)
          FilledButton(
            onPressed: () => context.push('/review-submit/${order.id}', extra: {
              'bookingId': order.id,
              'hotelId': order.hotelId,
              'hotelName': order.hotelName,
            }),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('评价', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        if (order.canEditReview)
          OutlinedButton(
            onPressed: () => context.push('/my-reviews'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('修改评价', style: TextStyle(color: AppColors.primary, fontSize: 12)),
          ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => context.push('/hotel-detail', extra: {'hotelId': order.hotelId ?? 1}),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('再次预订', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _handlePay(Booking order) async {
    try {
      final createPayResult = await ref.read(paymentServiceProvider).createPayment({
        'order_type': 'booking',
        'order_id': order.id,
        'amount': order.totalPrice,
        'payment_method': 'balance',
      });

      if (createPayResult.success && createPayResult.data != null) {
        final paymentIdRaw = createPayResult.data!['id'];
        final int paymentId = paymentIdRaw is int ? paymentIdRaw : (int.tryParse(paymentIdRaw?.toString() ?? '0') ?? 0);
        if (paymentId == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('支付订单创建异常')),
            );
          }
          return;
        }
        final payResult = await ref.read(paymentServiceProvider).pay(paymentId);
        if (payResult.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('支付成功'), backgroundColor: AppColors.success),
          );
          _fetchOrders();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(payResult.message ?? '支付失败')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(createPayResult.message ?? '创建支付订单失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支付失败，请重试')),
        );
      }
    }
  }

  Future<void> _showCancelDialog(Booking order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消订单'),
        content: const Text('确定要取消此订单吗？取消后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await ref.read(bookingServiceProvider).cancelBooking(order.id);
        if (result.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('订单已取消'), backgroundColor: AppColors.success),
          );
          _fetchOrders();
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
      }
    }
  }
}
