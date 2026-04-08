import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class HotelListPage extends StatelessWidget {
  const HotelListPage({super.key});

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
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              SizedBox(width: 12),
              Text('珠海', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              Icon(Icons.keyboard_arrow_down, size: 16),
              VerticalDivider(indent: 10, endIndent: 10),
              Text('住 04.08 / 离 04.09', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              VerticalDivider(indent: 10, endIndent: 10),
              Expanded(child: Text('位置/酒店/关键词', style: TextStyle(color: AppColors.textHint, fontSize: 12))),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.map_outlined, color: AppColors.textPrimary), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          _buildQuickFilters(),
          _buildPointsInfo(),
          Expanded(child: _buildHotelList(context)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _FilterItem(label: '推荐排序'),
          _FilterItem(label: '品牌价格'),
          _FilterItem(label: '位置距离'),
          _FilterItem(label: '筛选', showIcon: true),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    final filters = ['我的酒店', '服务设施', '官网特惠', '金/铂金10倍积分'];
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, i) => Container(
          margin: const EdgeInsets.only(right: 8, top: 8, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Text(filters[i], style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
              const Icon(Icons.keyboard_arrow_down, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointsInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('我的积分 3522 | 可抵 ¥35', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          Row(
            children: [
              const Text('看抵扣价', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Switch.adaptive(value: false, onChanged: (v) {}, activeTrackColor: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotelList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, i) => _buildHotelCard(context, i),
    );
  }

  Widget _buildHotelCard(BuildContext context, int i) {
    return GestureDetector(
      onTap: () => context.push('/hotel-detail'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('星程酒店 · 旗舰店', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('星程珠海金湾机场酒店', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text('4.8', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(width: 4),
                      Text('很棒 连续281条好评', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('珠海金湾机场附近 | 近珠海金湾机场 T1 航站楼', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTag('2.5倍积分', AppColors.gold.withValues(alpha: 0.1), AppColors.gold),
                      _buildTag('新品·星程3.0', Colors.blue.withValues(alpha: 0.1), Colors.blue),
                      _buildTag('免费停车', AppColors.background, AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('低价房仅剩2间', style: TextStyle(color: AppColors.error, fontSize: 12)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text('¥289', style: TextStyle(color: AppColors.textHint, decoration: TextDecoration.lineThrough, fontSize: 14)),
                              const SizedBox(width: 4),
                              const Text('¥', style: TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
                              const Text('255', style: TextStyle(color: AppColors.secondary, fontSize: 24, fontWeight: FontWeight.bold)),
                              const Text('起', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                            ],
                          ),
                          const Text('金会员 | 优惠34', style: TextStyle(color: AppColors.secondary, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _FilterItem extends StatelessWidget {
  final String label;
  final bool showIcon;
  const _FilterItem({required this.label, this.showIcon = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        Icon(showIcon ? Icons.tune : Icons.keyboard_arrow_down, size: 16, color: AppColors.textHint),
      ],
    );
  }
}
