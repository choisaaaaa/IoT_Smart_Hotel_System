import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/logic/member_logic.dart';
import '../../core/network/api_result.dart';
import '../../services/hotel_service.dart';
import '../../services/member_service.dart';
import '../../models/hotel.dart';
import '../../models/member.dart';

class HotelListPage extends ConsumerStatefulWidget {
  const HotelListPage({super.key});

  @override
  ConsumerState<HotelListPage> createState() => _HotelListPageState();
}

class _HotelListPageState extends ConsumerState<HotelListPage> {
  List<Hotel> _hotels = [];
  bool _isLoading = true;
  String _selectedCity = '全部';
  DateTime _checkInDate = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOutDate = DateTime.now().add(const Duration(days: 2));
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHotels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHotels() async {
    setState(() => _isLoading = true);
    try {
      final city = _selectedCity == '全部' ? null : _selectedCity;
      final keyword = _searchController.text.isNotEmpty ? _searchController.text : null;
      debugPrint('DEBUG: _fetchHotels - city=$city, keyword=$keyword');
      final result = await ref.read(hotelServiceProvider).getHotels(
            city: city,
            keyword: keyword,
          );
      debugPrint('DEBUG: _fetchHotels - result.success=${result.success}, data.length=${result.data?.length}');
      if (result.success && mounted) {
        setState(() => _hotels = result.data ?? []);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '获取酒店列表失败')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('DEBUG: _fetchHotels - error=$e');
      debugPrint('DEBUG: _fetchHotels - stackTrace=$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('网络异常: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _checkInDate, end: _checkOutDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _checkInDate = picked.start;
        _checkOutDate = picked.end;
      });
    }
  }

  void _showCityPicker() async {
    final cities = ['全部', '北京', '上海', '广州', '深圳', '珠海', '湛江', '杭州', '成都'];
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SizedBox(
        height: 300,
        child: ListView.builder(
          itemCount: cities.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(cities[i]),
            selected: cities[i] == _selectedCity,
            selectedColor: AppColors.primary,
            onTap: () => Navigator.pop(context, cities[i]),
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _selectedCity = result);
      _fetchHotels();
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
          onPressed: () => context.pop(),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _showCityPicker,
                child: Row(
                  children: [
                    Text(_selectedCity, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    const Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
              const VerticalDivider(indent: 10, endIndent: 10),
              GestureDetector(
                onTap: _selectDateRange,
                child: Text('${DateUtils.formatDotDate(_checkInDate)} - ${DateUtils.formatDotDate(_checkOutDate)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ),
              const VerticalDivider(indent: 10, endIndent: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _fetchHotels(),
                  onChanged: (v) => setState(() {}),
                  onEditingComplete: _fetchHotels,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '位置/酒店/关键词',
                    hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchController.clear(); setState(() {}); _fetchHotels(); })
                        : IconButton(icon: const Icon(Icons.search, size: 16), onPressed: _fetchHotels),
                  ),
                ),
              ),
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hotels.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.hotel_outlined, size: 64, color: AppColors.textHint),
                            const SizedBox(height: 16),
                            Text(_selectedCity == '全部' ? '暂无酒店数据' : '$_selectedCity 暂无酒店数据', style: const TextStyle(color: AppColors.textSecondary)),
                            TextButton(onPressed: () {
                              setState(() {
                                _selectedCity = '全部';
                                _searchController.clear();
                              });
                              _fetchHotels();
                            }, child: const Text('查看全部酒店')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchHotels,
                        child: _buildHotelList(context),
                      ),
          ),
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
    final filters = ['我的酒店', '服务设施', '官网特惠', '会员权益'];
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
    return Consumer(builder: (context, ref, _) {
      return FutureBuilder<ApiResult<Member>>(
        future: ref.read(memberServiceProvider).getMyAssets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.success) return const SizedBox.shrink();
          final member = snapshot.data!.data ?? ref.read(memberServiceProvider).cachedMember;
          if (member == null) return const SizedBox.shrink();
          final points = member.points;
          final discount = points / 100;

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
                Text('我的积分 $points | 可抵 ¥${discount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
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
        },
      );
    });
  }

  Widget _buildHotelList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _hotels.length,
      itemBuilder: (context, i) => _buildHotelCard(context, _hotels[i]),
    );
  }

  Widget _buildHotelCard(BuildContext context, Hotel hotel) {
    final member = ref.read(memberServiceProvider).cachedMember;
    final totalSpent = member?.totalSpent ?? 0;
    final level = MemberLevel.fromExperience(totalSpent.floor());

    final originalPrice = hotel.price ?? 299.0;
    final discountedPrice = originalPrice * level.discount;

    final shortName = hotel.hotelName.split('酒店').first;

    return GestureDetector(
      onTap: () => context.push('/hotel-detail', extra: {'hotelId': hotel.id}),
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
                  hotel.displayImage.isNotEmpty ? hotel.displayImage : 'https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, _, e) => Container(height: 200, color: AppColors.divider, child: const Icon(Icons.hotel, size: 48, color: AppColors.textHint)),
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
                    child: Text('$shortName · 旗舰店', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotel.hotelName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(hotel.effectiveRating.toStringAsFixed(1), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 4),
                      Text('很棒 ${hotel.reviewCount ?? 0}条好评', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(hotel.displayAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTag('智慧客控', Colors.blue.withValues(alpha: 0.1), Colors.blue),
                      _buildTag('免费停车', AppColors.background, AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(hotel.availableRooms != null ? '低价房仅剩${hotel.availableRooms}间' : '火热预订中', style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              if (originalPrice > discountedPrice)
                                Text('¥${originalPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textHint, decoration: TextDecoration.lineThrough, fontSize: 14)),
                              const SizedBox(width: 4),
                              const Text('¥', style: TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(discountedPrice.toStringAsFixed(0), style: const TextStyle(color: AppColors.secondary, fontSize: 24, fontWeight: FontWeight.bold)),
                              const Text('起', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                            ],
                          ),
                          Text('${level.label} | 优惠¥${(originalPrice - discountedPrice).toStringAsFixed(0)}', style: const TextStyle(color: AppColors.secondary, fontSize: 11)),
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
