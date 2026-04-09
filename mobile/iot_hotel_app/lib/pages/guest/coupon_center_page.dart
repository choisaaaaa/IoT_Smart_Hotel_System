import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/coupon_service.dart';
import '../../services/member_service.dart';

class CouponCenterPage extends ConsumerStatefulWidget {
  const CouponCenterPage({super.key});

  @override
  ConsumerState<CouponCenterPage> createState() => _CouponCenterPageState();
}

class _CouponCenterPageState extends ConsumerState<CouponCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _myCoupons = [];
  List<dynamic> _availableCoupons = [];
  String _currentFilter = 'all';

  final List<Map<String, String>> _tabs = [
    {'key': 'all', 'label': '全部'},
    {'key': 'unused', 'label': '未使用'},
    {'key': 'used', 'label': '已使用'},
    {'key': 'expired', 'label': '已过期'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final filter = _tabs[_tabController.index]['key']!;
    if (filter != _currentFilter) {
      _currentFilter = filter;
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadMyCoupons(),
        _loadAvailableCoupons(),
      ]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMyCoupons() async {
    final result = await ref.read(memberServiceProvider).getMyCoupons();
    if (result.success && mounted) {
      setState(() => _myCoupons = result.data ?? []);
    }
  }

  Future<void> _loadAvailableCoupons() async {
    final result = await ref.read(couponServiceProvider).getCoupons();
    if (result.success && mounted) {
      setState(() => _availableCoupons = result.data ?? []);
    }
  }

  List<dynamic> get _filteredCoupons {
    if (_currentFilter == 'all') return _myCoupons;
    return _myCoupons.where((c) {
      final status = c['status']?.toString() ?? '';
      switch (_currentFilter) {
        case 'unused':
          return status == 'unused' || status == 'active';
        case 'used':
          return status == 'used';
        case 'expired':
          return status == 'expired';
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _receiveCoupon(int couponId) async {
    final result = await ref.read(couponServiceProvider).receiveCoupon(couponId);
    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('领取成功！'), backgroundColor: AppColors.success),
      );
      _loadData();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '领取失败')),
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      return DateFormat('yyyy.MM.dd').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  Color _getCouponColor(String? type) {
    switch (type) {
      case 'discount':
        return AppColors.primary;
      case 'cash':
        return AppColors.secondary;
      case 'gift':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String _getCouponValue(Map<String, dynamic> coupon) {
    final type = coupon['type']?.toString();
    if (type == 'discount') {
      final discount = coupon['discount'] ?? coupon['value'];
      return '${discount}折';
    }
    final value = coupon['value'] ?? coupon['amount'] ?? 0;
    return '¥${value}';
  }

  String _getCouponTypeLabel(String? type) {
    switch (type) {
      case 'discount':
        return '折扣券';
      case 'cash':
        return '现金券';
      case 'gift':
        return '礼品券';
      default:
        return '优惠券';
    }
  }

  bool _isCouponExpired(Map<String, dynamic> coupon) {
    final endDate = coupon['end_date'] ?? coupon['expire_date'];
    if (endDate == null) return false;
    try {
      return DateTime.parse(endDate.toString()).isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  bool _isCouponUsed(Map<String, dynamic> coupon) {
    final status = coupon['status']?.toString() ?? '';
    return status == 'used';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('优惠券中心',
            style: GoogleFonts.notoSansSc(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 14),
          tabs: _tabs.map((tab) => Tab(text: tab['label'])).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  if (_availableCoupons.isNotEmpty)
                    SliverToBoxAdapter(child: _buildAvailableSection()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('我的优惠券',
                          style: GoogleFonts.notoSansSc(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  _filteredCoupons.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.confirmation_num_outlined,
                                    size: 64, color: AppColors.textHint),
                                const SizedBox(height: 16),
                                Text('暂无优惠券',
                                    style: GoogleFonts.notoSansSc(
                                        fontSize: 16, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildCouponCard(_filteredCoupons[index]),
                            childCount: _filteredCoupons.length,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  Widget _buildAvailableSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.05), AppColors.secondary.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text('可领取优惠券',
                  style: GoogleFonts.notoSansSc(
                      fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 12),
          ..._availableCoupons.take(3).map((coupon) => _buildAvailableCouponItem(coupon)),
        ],
      ),
    );
  }

  Widget _buildAvailableCouponItem(Map<String, dynamic> coupon) {
    final color = _getCouponColor(coupon['type']?.toString());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_getCouponValue(coupon),
                style: GoogleFonts.notoSansSc(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coupon['name'] ?? coupon['title'] ?? '优惠券',
                    style: GoogleFonts.notoSansSc(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(coupon['start_date']?.toString())} - ${_formatDate(coupon['end_date']?.toString())}',
                  style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: FilledButton(
              onPressed: () => _receiveCoupon(coupon['id']),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('领取',
                  style: GoogleFonts.notoSansSc(fontSize: 12, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon) {
    final isUsed = _isCouponUsed(coupon);
    final isExpired = _isCouponExpired(coupon);
    final isDisabled = isUsed || isExpired;
    final color = _getCouponColor(coupon['type']?.toString());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDisabled ? AppColors.divider : color.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? AppColors.textHint.withValues(alpha: 0.1)
                        : color.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _getCouponValue(coupon),
                        style: GoogleFonts.notoSansSc(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDisabled ? AppColors.textHint : color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getCouponTypeLabel(coupon['type']?.toString()),
                        style: GoogleFonts.notoSansSc(
                          fontSize: 11,
                          color: isDisabled ? AppColors.textHint : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon['name'] ?? coupon['title'] ?? '优惠券',
                          style: GoogleFonts.notoSansSc(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDisabled ? AppColors.textHint : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (coupon['min_amount'] != null &&
                            double.tryParse(coupon['min_amount'].toString()) != null &&
                            double.parse(coupon['min_amount'].toString()) > 0)
                          Text(
                            '满${coupon['min_amount']}可用',
                            style: GoogleFonts.notoSansSc(
                              fontSize: 12,
                              color: isDisabled ? AppColors.textHint : AppColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatDate(coupon['start_date']?.toString())} - ${_formatDate(coupon['end_date']?.toString())}',
                          style: GoogleFonts.notoSansSc(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isDisabled)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      height: 32,
                      child: FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请在预订时使用优惠券')),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('去使用',
                            style: GoogleFonts.notoSansSc(fontSize: 12, color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUsed)
            Positioned(
              top: 12,
              right: 12,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.textHint),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('已使用',
                      style: GoogleFonts.notoSansSc(
                          fontSize: 10, color: AppColors.textHint)),
                ),
              ),
            ),
          if (isExpired && !isUsed)
            Positioned(
              top: 12,
              right: 12,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.textHint),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('已过期',
                      style: GoogleFonts.notoSansSc(
                          fontSize: 10, color: AppColors.textHint)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
