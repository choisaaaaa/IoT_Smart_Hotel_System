import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';

class OrderListPage extends ConsumerStatefulWidget {
  const OrderListPage({super.key});

  @override
  ConsumerState<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends ConsumerState<OrderListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(bookingServiceProvider).getBookings(pageSize: 50);
      if (result.success) {
        setState(() {
          final dynamic data = result.data;
          if (data is Map && data.containsKey('list')) {
            _orders = List<dynamic>.from(data['list'] ?? []);
          } else if (data is List) {
            _orders = List<dynamic>.from(data);
          } else if (data is Map && data.containsKey('bookings')) {
            _orders = List<dynamic>.from(data['bookings'] ?? []);
          } else {
            _orders = [];
          }
        });
      } else {
        debugPrint('Fetch orders failed: ${result.message}');
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
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
          isScrollable: false,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '待支付'),
            Tab(text: '待入住'),
            Tab(text: '待评价'),
            Tab(text: '取消'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildOrderList('all'),
              _buildOrderList('pending'),
              _buildOrderList('confirmed'),
              _buildOrderList('checked_out'),
              _buildOrderList('cancelled'),
            ],
          ),
    );
  }

  Widget _buildOrderList(String filterStatus) {
    final filteredOrders = filterStatus == 'all' 
        ? _orders 
        : _orders.where((o) => o['status'] == filterStatus).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('暂无相关订单', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: filteredOrders.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return _buildNoticeBar();
          if (index == 1) return _buildSortBar();
          
          final order = filteredOrders[index - 2];
          return GestureDetector(
            onTap: () => context.push('/order-detail/${order['id']}'),
            child: _buildOrderItem(
              orderId: order['id'] ?? 0,
              hotelName: order['hotel_name'] ?? '智联酒店',
              status: _getStatusText(order['status']),
              dateRange: '${_formatDate(order['check_in_date'])} - ${_formatDate(order['check_out_date'])}',
              nights: _calculateNights(order['check_in_date'], order['check_out_date']),
              roomType: order['room_type'] ?? '标准间',
              rooms: order['guest_count'] ?? 1,
              price: order['total_price']?.toString() ?? '0.00',
              isCompleted: order['status'] == 'checked_out',
              orderData: order,
            ),
          );
        },
      ),
    );
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

  Future<void> _handlePay(dynamic order) async {
    try {
      final totalPrice = double.tryParse(order['total_price']?.toString() ?? '0') ?? 0;
      final createPayResult = await ref.read(paymentServiceProvider).createPayment({
        'order_type': 'booking',
        'order_id': order['id'],
        'amount': totalPrice,
        'payment_method': 'balance',
      });

      if (createPayResult.success && createPayResult.data != null) {
        final paymentId = createPayResult.data!['id'];
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
          SnackBar(content: Text('支付异常：$e')),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}.${date.day}';
    } catch (e) {
      return dateStr;
    }
  }

  int _calculateNights(String? checkIn, String? checkOut) {
    if (checkIn == null || checkOut == null) return 1;
    try {
      final start = DateTime.parse(checkIn);
      final end = DateTime.parse(checkOut);
      return end.difference(start).inDays;
    } catch (e) {
      return 1;
    }
  }

  Widget _buildNoticeBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.white],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('安心订 贵即赔', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 14)),
          Row(
            children: [
              Text('降价了可以退 订贵了可以赔', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const Icon(Icons.chevron_right, size: 14, color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildSortChip('按预订时间排序', active: true),
          const SizedBox(width: 8),
          _buildSortChip('按入住时间排序'),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEDE7F6) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.primary : AppColors.divider),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: active ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildOrderItem({
    required int orderId,
    required String hotelName,
    required String status,
    required String dateRange,
    required int nights,
    required String roomType,
    required int rooms,
    required String price,
    required bool isCompleted,
    Map<String, dynamic>? orderData,
  }) {
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
                            hotelName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            color: status == '已完成' ? AppColors.textPrimary : AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$dateRange 共$nights晚',
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$roomType | $rooms间',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('¥', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(price, style: const TextStyle(color: AppColors.secondary, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == '待支付')
                FilledButton(
                  onPressed: () => _handlePay(orderData),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('去支付', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (status == '待入住')
                FilledButton(
                  onPressed: () => context.push('/online-checkin', extra: {'bookingId': orderData?['id'] ?? orderId}),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('办理入住', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (status == '已入住') ...[
                FilledButton(
                  onPressed: () => context.push('/extend-stay', extra: {'bookingId': orderData?['id'] ?? orderId}),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('续住', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => context.push('/checkout', extra: {'bookingId': orderData?['id'] ?? orderId}),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('退房', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
              if (status == '已完成')
                FilledButton(
                  onPressed: () => context.push('/review-submit', extra: {
                    'bookingId': orderData?['id'] ?? orderId,
                    'hotelId': orderData?['hotel_id'],
                    'hotelName': orderData?['hotel_name'] ?? hotelName,
                  }),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('评价', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.push('/hotel-detail', extra: {'hotelId': orderData?['hotel_id'] ?? 1}),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('再次预订', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
