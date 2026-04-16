import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/favorite_service.dart';
import '../../services/review_service.dart';
import '../../services/hotel_service.dart';
import '../../services/member_service.dart';
import '../../services/auth_service.dart';
import '../../core/logic/member_logic.dart';
import '../../models/hotel.dart';
import '../../models/room_type.dart';

class HotelDetailPage extends ConsumerStatefulWidget {
  final int? hotelId;

  const HotelDetailPage({super.key, this.hotelId});

  @override
  ConsumerState<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends ConsumerState<HotelDetailPage> {
  final List<dynamic> _reviews = [];
  bool _isLoadingReviews = false;
  int _reviewPage = 1;
  Map<String, dynamic>? _reviewStats;
  
  Hotel? _hotelInfo;
  List<RoomType> _rooms = [];
  bool _isLoadingHotel = true;
  bool _isLoadingRooms = true;
  bool _isFavorited = false;
  
  DateTime _checkInDate = DateTime.now();
  DateTime _checkOutDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    // 确保初始日期是“今天”和“明天”，避免因本地时间偏移导致查询跨度异常
    final now = DateTime.now();
    _checkInDate = DateTime(now.year, now.month, now.day);
    _checkOutDate = _checkInDate.add(const Duration(days: 1));
    
    _fetchHotelDetail();
    _fetchRooms();
    _fetchReviews();
    _loadFavoriteStatus();
    ref.read(memberServiceProvider).getMyAssets();
  }

  void _loadFavoriteStatus() async {
    final hotelId = widget.hotelId ?? 1;
    final isFav = await ref.read(favoriteServiceProvider).isFavorite(hotelId);
    if (mounted) setState(() => _isFavorited = isFav);
  }

  void _toggleFavorite() async {
    final hotelId = widget.hotelId ?? 1;
    if (_isFavorited) {
      await ref.read(favoriteServiceProvider).removeFavorite(hotelId);
    } else {
      await ref.read(favoriteServiceProvider).addFavorite(hotelId);
    }
    setState(() => _isFavorited = !_isFavorited);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFavorited ? '已收藏' : '已取消收藏')),
      );
    }
  }

  Future<void> _fetchHotelDetail() async {
    setState(() => _isLoadingHotel = true);
    try {
      final result = await ref.read(hotelServiceProvider).getHotelById(widget.hotelId ?? 1);
      if (result.success && mounted) {
        setState(() => _hotelInfo = result.data);
      }
    } catch (e) {
      debugPrint('hotelDetail: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHotel = false);
    }
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoadingRooms = true);
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final checkIn = dateFormat.format(_checkInDate);
      final checkOut = dateFormat.format(_checkOutDate);
      
      debugPrint('[HotelDetail] 正在查询房型: hotel_id=${widget.hotelId}, range=$checkIn to $checkOut');
      
      final result = await ref.read(hotelServiceProvider).getRoomAvailability(
        widget.hotelId ?? 1,
        checkIn,
        checkOut,
      );
      
      if (result.success && mounted) {
        final rooms = result.data ?? [];
        debugPrint('🏨 [HotelDetail] Loaded rooms: ${rooms.length} types. First room ID: ${rooms.isNotEmpty ? rooms[0].id : 'none'}');
        setState(() => _rooms = rooms);
      } else if (mounted) {
        debugPrint('[HotelDetail] 房型查询失败: ${result.message}');
      }
    } catch (e) {
      debugPrint('rooms: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  Future<void> _fetchReviews() async {
    if (_isLoadingReviews) return;

    setState(() => _isLoadingReviews = true);
    try {
      final hotelId = widget.hotelId ?? _hotelInfo?.id ?? 1;

      final results = await Future.wait([
        ref.read(reviewServiceProvider).getHotelReviews(
          hotelId,
          page: _reviewPage,
          pageSize: 10,
        ),
        if (_reviewStats == null)
          ref.read(reviewServiceProvider).getReviewStats(hotelId),
      ]);

      final reviewResult = results[0];
      if (reviewResult.success && mounted) {
        final data = reviewResult.data;
        final newReviews = data is Map ? (data?['list'] as List<dynamic>? ?? []) : (data as List<dynamic>? ?? []);
        setState(() {
          _reviews.addAll(newReviews);
          _reviewPage++;
        });
      }

      if (results.length > 1 && results[1].success && results[1].data != null) {
        setState(() => _reviewStats = results[1].data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Fetch reviews error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingHotel && _hotelInfo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(child: _buildHotelHeader()),
          SliverToBoxAdapter(child: _buildHotelInfo()),
          SliverToBoxAdapter(child: _buildDateSelector()),
          if (_isLoadingRooms)
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
          else if (_rooms.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyRooms())
          else
            SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => _buildRoomItem(context, _rooms[i]), childCount: _rooms.length)),
          SliverToBoxAdapter(child: _buildReviewSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildEmptyRooms() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.hotel_outlined, size: 48, color: AppColors.textHint),
            SizedBox(height: 16),
            Text('该日期范围内无可用房间', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    String imageUrl = _hotelInfo?.displayImage ?? '';
    if (imageUrl.isEmpty) {
      imageUrl = 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80';
    }
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white), 
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
      actions: [
        IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white), onPressed: () {}),
        IconButton(
          icon: Icon(_isFavorited ? Icons.favorite : Icons.favorite_border, color: _isFavorited ? Colors.red : Colors.white),
          onPressed: _toggleFavorite,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (ctx, _, e) => Container(color: AppColors.divider, child: const Icon(Icons.hotel, size: 64, color: AppColors.textHint))),
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
          Text(_hotelInfo?.hotelName ?? '智联酒店', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${_hotelInfo?.effectiveStar ?? 5}星级 | 智慧酒店', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag('智慧客控', Colors.blue.withValues(alpha: 0.1), Colors.blue),
              _buildTag('免费停车', AppColors.background, AppColors.textSecondary),
              // 如果有设施列表，安全地处理
              if (_hotelInfo?.facilities != null)
                ...(() {
                  final facilities = _hotelInfo!.facilities!;
                  return facilities.take(2).map((f) => _buildTag(f, AppColors.background, AppColors.textSecondary)).toList();
                })(),
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
                Row(
                  children: [
                    Text(_reviewStats?['avg_score'] ?? _hotelInfo?.rating?.toString() ?? '4.5', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(width: 4),
                    Text('很棒 ${_reviewStats?['total_reviews'] ?? _reviews.length}条好评', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_hotelInfo?.displayAddress ?? '酒店地址加载中...', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
    final format = DateFormat('MM月dd日');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _selectDates,
      child: Container(
        color: Colors.white,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${format.format(_checkInDate)} - ${format.format(_checkOutDate)} >', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${DateFormat('E', 'zh_CN').format(_checkInDate)}入住 - ${DateFormat('E', 'zh_CN').format(_checkOutDate)}离店', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20)),
              child: const Text('全日房', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDates() async {
    final checkIn = await showDatePicker(
      context: context,
      initialDate: _checkInDate.isAfter(DateTime.now()) ? _checkInDate : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择入住日期',
    );
    if (checkIn == null || !mounted) return;

    final checkOut = await showDatePicker(
      context: context,
      initialDate: checkIn.add(const Duration(days: 1)),
      firstDate: checkIn.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择退房日期',
    );
    if (checkOut == null || !mounted) return;

    setState(() {
      _checkInDate = checkIn;
      _checkOutDate = checkOut;
    });
    _fetchRooms();
  }

  Widget _buildRoomItem(BuildContext context, RoomType room) {
    String imageUrl = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=400&q=80';
    if (room.images != null && room.images!.isNotEmpty) {
      imageUrl = room.images!.first;
    }
    final originalPrice = room.basePrice;
    
    // 获取会员折扣
    final totalSpent = ref.read(memberServiceProvider).cachedMember?.totalSpent ?? 0;
    final level = MemberLevel.fromExperience(totalSpent.floor());
    final discountedPrice = originalPrice * level.discount;

    final roomName = room.name;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roomName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.aspect_ratio, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('${room.area ?? 20}m²', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.king_bed_outlined, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(room.bedType ?? '大床', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.person_outline, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('${room.maxGuests}人', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.coffee_outlined, size: 12, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(_parseBool(room.facilities?.any((f) => f.contains('早餐') || f.contains('breakfast')) ?? false) ? '含早餐' : '不含早', style: const TextStyle(color: AppColors.success, fontSize: 11)),
                    const SizedBox(width: 12),
                    const Icon(Icons.wifi, size: 12, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(_parseBool(room.facilities?.any((f) => f.contains('WiFi') || f.contains('wifi') || f.contains('网络')) ?? false) ? '免费无线网络' : '无网络', style: const TextStyle(color: AppColors.success, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('优惠预订 >', style: TextStyle(fontSize: 12, color: Color(0xFF795548), fontWeight: FontWeight.bold)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (originalPrice > discountedPrice)
                              Text('¥${originalPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textHint, decoration: TextDecoration.lineThrough, fontSize: 12)),
                            const SizedBox(width: 4),
                            const Text('¥', style: TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(discountedPrice.toStringAsFixed(0), style: const TextStyle(color: AppColors.secondary, fontSize: 22, fontWeight: FontWeight.bold)),
                            const Text(' 起', style: TextStyle(color: AppColors.secondary, fontSize: 10, height: 2)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        SizedBox(
                          height: 36,
                          width: 60,
                          child: FilledButton(
                            onPressed: () async {
                              final isLoggedIn = await ref.read(authServiceProvider).isLoggedIn();
                              if (!isLoggedIn) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('请先登录后再预订'), backgroundColor: AppColors.warning),
                                );
                                context.push('/login');
                                return;
                              }
                              if (!context.mounted) return;
                              context.push('/booking-flow', extra: {
                                  'hotelName': _hotelInfo?.hotelName ?? '智联酒店',
                                  'hotelId': widget.hotelId ?? 1,
                                  'roomType': roomName,
                                  'price': discountedPrice,
                                  'roomId': room.id,
                                  'roomTypeId': room.id,
                                  'checkInDate': _checkInDate,
                                  'checkOutDate': _checkOutDate,
                                });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text('抢', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.1)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('仅剩${room.availableCount ?? 1}间', style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
                      ],
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

  Widget _buildReviewSection() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              final hotelId = widget.hotelId ?? _hotelInfo?.id;
              if (hotelId != null) {
                context.push('/hotel-reviews/$hotelId', extra: {
                  'hotelName': _hotelInfo?.hotelName ?? '酒店',
                });
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('住客评价', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    if (_reviewStats != null)
                      Text('${_reviewStats!['avg_score'] ?? '0.0'}分', style: GoogleFonts.notoSansSc(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    Text('${_reviewStats?['total_reviews'] ?? _reviews.length}条', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          if (_reviewStats != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMiniStat('环境', _reviewStats!['avg_environment'] ?? '0.0'),
                const SizedBox(width: 12),
                _buildMiniStat('设施', _reviewStats!['avg_facility'] ?? '0.0'),
                const SizedBox(width: 12),
                _buildMiniStat('舒适', _reviewStats!['avg_comfort'] ?? '0.0'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_reviews.isEmpty && !_isLoadingReviews)
            _buildEmptyReviews()
          else
            ..._reviews.take(3).map((review) => _buildReviewItem(review)),
          if (_reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    final hotelId = widget.hotelId ?? _hotelInfo?.id;
                    if (hotelId != null) {
                      context.push('/hotel-reviews/$hotelId', extra: {
                        'hotelName': _hotelInfo?.hotelName ?? '酒店',
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('查看全部评价', style: GoogleFonts.notoSansSc(fontSize: 14)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    final v = double.tryParse(value) ?? 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 4),
        Text(value, style: GoogleFonts.notoSansSc(fontSize: 12, fontWeight: FontWeight.bold, color: v >= 4 ? AppColors.success : v >= 3 ? AppColors.warning : AppColors.error)),
      ],
    );
  }

  Widget _buildEmptyReviews() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.reviews_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('暂无评价', style: GoogleFonts.notoSansSc(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('成为第一个评价的客人吧！', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildReviewItem(dynamic review) {
    final rating = (review['score'] ?? 5.0).toDouble();
    final userName = review['member_name'] ?? review['member_phone'] ?? '匿名用户';
    final content = review['content'] ?? '';
    final createdAt = review['created_at'] ?? '';
    final envRating = review['environment_rating'];
    final facRating = review['facility_rating'];
    final comRating = review['comfort_rating'];
    final reply = review['reply'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: AppColors.background, child: Icon(Icons.person, size: 16, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Expanded(child: Text(userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating.floor() ? Icons.star : Icons.star_border,
                    size: 16,
                    color: AppColors.gold,
                  );
                }),
              ),
            ],
          ),
          if (envRating != null || facRating != null || comRating != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (envRating != null) _buildReviewTag('环境$envRating'),
                if (facRating != null) ...[const SizedBox(width: 6), _buildReviewTag('设施$facRating')],
                if (comRating != null) ...[const SizedBox(width: 6), _buildReviewTag('舒适$comRating')],
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(content, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
          if (reply != null && reply.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(child: Text('酒店回复：$reply', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(_formatDate(createdAt), style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textSecondary)),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildTag(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: text, fontSize: 10)),
    );
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }
}
