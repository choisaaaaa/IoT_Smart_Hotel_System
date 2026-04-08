import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class HotelDetailPage extends StatelessWidget {
  const HotelDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(child: _buildHotelHeader()),
          SliverToBoxAdapter(child: _buildHotelInfo()),
          SliverToBoxAdapter(child: _buildDateSelector()),
          SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => _buildRoomItem(context, i), childCount: 3)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => context.pop()),
      actions: [
        IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white), onPressed: () {}),
        IconButton(icon: const Icon(Icons.favorite_border, color: Colors.white), onPressed: () {}),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Image.network(
          'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildHotelHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('星程珠海金湾机场酒店', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('舒适型 | 2025年1月开业', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildTag('2.5倍积分', AppColors.gold.withValues(alpha: 0.1), AppColors.gold),
              _buildTag('新品·星程3.0', Colors.blue.withValues(alpha: 0.1), Colors.blue),
              _buildTag('免费停车', AppColors.background, AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotelInfo() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('4.8', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    SizedBox(width: 4),
                    Text('很棒 连续281条好评', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('距珠海金湾机场 T1 航站楼 驾车10分钟', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const VerticalDivider(),
          const Column(
            children: [
              Icon(Icons.map_outlined, color: AppColors.primary),
              Text('地图', style: TextStyle(fontSize: 10, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('04月08日 - 04月09日 >', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('周三入住 - 周四离店', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20)),
            child: const Text('全日房', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          const Text('时租房', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRoomItem(BuildContext context, int i) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: const DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=400&q=80'), fit: BoxFit.cover)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('商务双床房', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('28-30m² | 2张1.35米床 | 外景窗', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('金会员价 >', style: TextStyle(fontSize: 13, color: Color(0xFF795548), fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text('¥255', style: TextStyle(color: AppColors.secondary, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(' 优惠34', style: TextStyle(color: AppColors.secondary, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 40,
                      child: FilledButton(
                        onPressed: () => context.push('/booking-flow'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('抢', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: text, fontSize: 10)),
    );
  }
}
