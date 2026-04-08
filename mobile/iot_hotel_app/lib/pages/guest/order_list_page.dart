import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
          onPressed: () => context.pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('酒店订单', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary, size: 18),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('开发票', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(),
          const Center(child: Text('暂无待支付订单')),
          const Center(child: Text('暂无待入住订单')),
          const Center(child: Text('暂无待评价订单')),
          const Center(child: Text('暂无取消订单')),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _buildNoticeBar(),
        _buildSortBar(),
        _buildOrderItem(
          hotelName: '星程珠海金湾机场酒店',
          status: '已完成',
          dateRange: '04.04-04.06',
          nights: 2,
          roomType: '商务双床房',
          rooms: 1,
          price: '761.44',
          isCompleted: true,
        ),
        _buildOrderItem(
          hotelName: '星程珠海金湾机场酒店',
          status: '已取消',
          dateRange: '04.04-04.06',
          nights: 2,
          roomType: '商务双床房',
          rooms: 1,
          price: '781.44',
          isCompleted: false,
        ),
        _buildOrderItem(
          hotelName: '星程珠海金湾机场酒店',
          status: '已完成',
          dateRange: '03.28-03.29',
          nights: 1,
          roomType: '商务双床房',
          rooms: 1,
          price: '254.32',
          isCompleted: true,
        ),
        _buildOrderItem(
          hotelName: '星程珠海金湾机场酒店',
          status: '已完成',
          dateRange: '03.27-03.28',
          nights: 1,
          roomType: '商务双床房',
          rooms: 1,
          price: '254.32',
          isCompleted: true,
        ),
      ],
    );
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
    required String hotelName,
    required String status,
    required String dateRange,
    required int nights,
    required String roomType,
    required int rooms,
    required String price,
    required bool isCompleted,
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
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('再次预订', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.delete_outline, color: AppColors.textHint, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
