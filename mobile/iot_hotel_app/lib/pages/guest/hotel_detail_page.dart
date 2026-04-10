import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/review_service.dart';
import '../../services/hotel_service.dart';
import '../../services/member_service.dart';
import '../../services/auth_service.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../core/logic/member_logic.dart';

class HotelDetailPage extends ConsumerStatefulWidget {
  final int? hotelId;

  const HotelDetailPage({super.key, this.hotelId});

  @override
  ConsumerState<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends ConsumerState<HotelDetailPage> {
  final List<dynamic> _reviews = [];
  bool _isLoadingReviews = false;
  bool _hasMoreReviews = true;
  int _reviewPage = 1;
  
  Map<String, dynamic>? _hotelInfo;
  List<dynamic> _rooms = [];
  bool _isLoadingHotel = true;
  bool _isLoadingRooms = true;
  bool _isFavorited = false;
  
  DateTime _checkInDate = DateTime.now();
  DateTime _checkOutDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _fetchHotelDetail();
    _fetchRooms();
    _fetchReviews();
    _loadFavoriteStatus();
    ref.read(memberServiceProvider).getMyAssets();
  }

  void _loadFavoriteStatus() async {
    final favorites = await _getFavoritesList();
    final hotelId = widget.hotelId ?? 1;
    if (mounted) setState(() => _isFavorited = favorites.any((f) => f['id'] == hotelId));
  }

  String get _favKey {
    final userId = ref.read(authStateProvider).userId ?? 'guest';
    return '${AppConstants.favoriteHotelsKey}_$userId';
  }

  Future<List<Map<String, dynamic>>> _getFavoritesList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favKey) ?? '[]';
    final List<dynamic> decoded = jsonDecode(raw);
    return decoded.cast<Map<String, dynamic>>().toList();
  }

  void _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favKey) ?? '[]';
    final List<dynamic> decoded = jsonDecode(raw);
    final favorites = decoded.cast<Map<String, dynamic>>().toList();
    final hotelId = widget.hotelId ?? 1;

    if (_isFavorited) {
      favorites.removeWhere((f) => f['id'] == hotelId);
    } else {
      favorites.add({
        'id': hotelId,
        'name': _hotelInfo?['name'] ?? '智联酒店',
        'image': (_hotelInfo?['image'] is String) ? _hotelInfo!['image'] as String : '',
        'star': _hotelInfo?['star'] ?? 5,
        'location': _hotelInfo?['location'] ?? '',
      });
    }
    await prefs.setString(_favKey, jsonEncode(favorites));
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
        final raw = result.data;
        if (raw != null) {
          var hotelData = raw;
          if (raw.containsKey('hotel') && raw['hotel'] is Map) {
            hotelData = Map<String, dynamic>.from(raw['hotel'] as Map);
          }
          final normalized = <String, dynamic>{};
          hotelData.forEach((key, value) {
            normalized[key] = value;
          });
          if (!normalized.containsKey('name') && normalized.containsKey('hotel_name')) {
            normalized['name'] = normalized['hotel_name'];
          }
          if (!normalized.containsKey('location') && normalized.containsKey('hotel_address')) {
            normalized['location'] = normalized['hotel_address'];
          }
          if (!normalized.containsKey('star') && normalized.containsKey('hotel_star')) {
            normalized['star'] = normalized['hotel_star'];
          }
          if (!normalized.containsKey('image') && normalized.containsKey('logo')) {
            normalized['image'] = normalized['logo'];
          }
          if (normalized.containsKey('facilities') && normalized['facilities'] is String) {
            try {
              normalized['facilities'] = jsonDecode(normalized['facilities'] as String);
            } catch (_) {}
          }
          if (normalized.containsKey('images') && normalized['images'] is String) {
            try {
              normalized['images'] = jsonDecode(normalized['images'] as String);
            } catch (_) {}
          }
          setState(() => _hotelInfo = normalized);
        }
      }
    } catch (e) {
      debugPrint('Error fetching hotel detail: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHotel = false);
    }
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoadingRooms = true);
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final result = await ref.read(hotelServiceProvider).getRoomAvailability(
        widget.hotelId ?? 1,
        dateFormat.format(_checkInDate),
        dateFormat.format(_checkOutDate),
      );
      if (result.success && mounted) {
        setState(() => _rooms = result.data ?? []);
      }
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  Future<void> _fetchReviews() async {
    if (_isLoadingReviews || !_hasMoreReviews) return;

    setState(() => _isLoadingReviews = true);
    try {
      final result = await ref.read(reviewServiceProvider).getHotelReviews(
        widget.hotelId ?? 1,
        page: _reviewPage,
        pageSize: 10,
      );

      if (result.success && mounted) {
        final newReviews = result.data ?? [];
        setState(() {
          _reviews.addAll(newReviews);
          _reviewPage++;
          if (newReviews.length < 10) {
            _hasMoreReviews = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
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
    final rawImage = _hotelInfo?['image'];
    String imageUrl = 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80';
    if (rawImage is String && rawImage.isNotEmpty) {
      imageUrl = rawImage;
    } else if (rawImage is List && rawImage.isNotEmpty) {
      imageUrl = rawImage.first.toString();
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
          Text(_hotelInfo?['name'] ?? '智联酒店', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${_safeString(_hotelInfo?['star'])}星级 | 智慧酒店', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag('2.5倍积分', AppColors.gold.withValues(alpha: 0.1), AppColors.gold),
              _buildTag('智慧客控', Colors.blue.withValues(alpha: 0.1), Colors.blue),
              _buildTag('免费停车', AppColors.background, AppColors.textSecondary),
              // 如果有设施列表，安全地处理
              if (_hotelInfo?['facilities'] != null)
                ...(() {
                  final facilities = _hotelInfo!['facilities'];
                  if (facilities is List) {
                    return facilities.take(2).map((f) => _buildTag(f.toString(), AppColors.background, AppColors.textSecondary)).toList();
                  } else if (facilities is String) {
                    // 如果后端返回的是逗号分隔的字符串，尝试拆分
                    if (facilities.contains(',')) {
                      return facilities.split(',').take(2).map((f) => _buildTag(f.trim(), AppColors.background, AppColors.textSecondary)).toList();
                    }
                    return [_buildTag(facilities, AppColors.background, AppColors.textSecondary)];
                  }
                  return <Widget>[];
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
                    const Text('4.8', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(width: 4),
                    Text('很棒 ${_reviews.isEmpty ? "连续281条" : "${_reviews.length}条"}好评', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_safeString(_hotelInfo?['location'], defaultVal: '酒店地址加载中...'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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

  Widget _buildRoomItem(BuildContext context, dynamic room) {
    final rawImg = room['images'];
    String imageUrl = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=400&q=80';
    if (rawImg is String && rawImg.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawImg);
        if (decoded is List && decoded.isNotEmpty) imageUrl = decoded.first.toString();
      } catch (_) {
        imageUrl = rawImg;
      }
    } else if (rawImg is List && rawImg.isNotEmpty) {
      imageUrl = rawImg.first.toString();
    }
    final originalPrice = double.tryParse((room['room_price'] ?? 0).toString()) ?? 0.0;
    
    // 获取会员折扣
    final totalSpent = double.tryParse(ref.read(memberServiceProvider).assets?['total_spent']?.toString() ?? '0') ?? 0;
    final level = MemberLevel.fromExperience(totalSpent.floor());
    final discountedPrice = originalPrice * level.discount;

    final roomName = room['room_name'] ?? room['name'] ?? room['room_number']?.toString() ?? '标准间';

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
                    Text('${room['area'] ?? 20}m²', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.king_bed_outlined, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(room['bed_type'] ?? room['bedType'] ?? '大床', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.person_outline, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('${room['max_guests'] ?? 2}人', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.coffee_outlined, size: 12, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(_parseBool(room['has_breakfast']) ? '含早餐' : '不含早', style: const TextStyle(color: AppColors.success, fontSize: 11)),
                    const SizedBox(width: 12),
                    const Icon(Icons.wifi, size: 12, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(_parseBool(room['has_wifi']) ? '免费无线网络' : '无网络', style: const TextStyle(color: AppColors.success, fontSize: 11)),
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
                                  'hotelName': _hotelInfo?['name'] ?? '智联酒店',
                                  'hotelId': widget.hotelId,
                                  'roomType': roomName,
                                  'price': discountedPrice,
                                  'roomId': room['id'],
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
                        Text('仅剩${room['available_count'] ?? 1}间', style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('住客评价 (${_reviews.length})', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_reviews.isNotEmpty)
                TextButton(
                  onPressed: () {},
                  child: Text('查看全部', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_reviews.isEmpty && !_isLoadingReviews)
            _buildEmptyReviews()
          else
            ..._reviews.take(3).map((review) => _buildReviewItem(review)),
          if (_hasMoreReviews)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _fetchReviews,
                  child: _isLoadingReviews
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('加载更多评价'),
                ),
              ),
            ),
        ],
      ),
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
    final rating = review['rating'] ?? 5.0;
    final userName = review['user_name'] ?? '匿名用户';
    final content = review['content'] ?? '';
    final createdAt = review['created_at'] ?? '';

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
          const SizedBox(height: 8),
          Text(content, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
          const SizedBox(height: 8),
          Text(_formatDate(createdAt), style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Divider(height: 24),
        ],
      ),
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

  String _safeString(dynamic value, {String defaultVal = '5'}) {
    if (value == null) return defaultVal;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is num) return value.toString();
    return defaultVal;
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }
}
