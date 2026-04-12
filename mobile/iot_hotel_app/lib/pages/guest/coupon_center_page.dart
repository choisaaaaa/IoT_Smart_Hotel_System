import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../../services/member_service.dart';
import '../../models/coupon.dart';

class CouponCenterPage extends ConsumerStatefulWidget {
  const CouponCenterPage({super.key});

  @override
  ConsumerState<CouponCenterPage> createState() => _CouponCenterPageState();
}

class _CouponCenterPageState extends ConsumerState<CouponCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Coupon> _myCoupons = [];
  String _currentFilter = 'all';

  final List<Map<String, String>> _tabs = [
    {'key': 'all', 'label': '全部'},
    {'key': 'unused', 'label': '未使用'},
    {'key': 'used', 'label': '已使用'},
    {'key': 'expired', 'label': '已过期'},
  ];

  final _redeemController = TextEditingController();
  bool _isRedeeming = false;

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
    _redeemController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() => _currentFilter = _tabs[_tabController.index]['key']!);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(memberServiceProvider).getMyCoupons();
      if (mounted) {
        setState(() {
          _myCoupons = result.data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRedeem() async {
    final code = _redeemController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入兑换码')));
      return;
    }

    setState(() => _isRedeeming = true);
    try {
      final dioClient = DioClient();
      final response = await dioClient.post('/coupons/redeem', data: {'code': code});
      if (mounted) {
        if (response.statusCode == 200 && response.data['code'] == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('兑换成功！'), backgroundColor: AppColors.success),
          );
          _redeemController.clear();
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '兑换失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('兑换失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  List<Coupon> get _filteredCoupons {
    switch (_currentFilter) {
      case 'unused':
        return _myCoupons.where((c) => c.status == 'active' && !c.isExpired).toList();
      case 'used':
        return _myCoupons.where((c) => c.status == 'used').toList();
      case 'expired':
        return _myCoupons.where((c) => c.isExpired || c.status == 'expired').toList();
      default:
        return _myCoupons;
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('优惠券', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
        ),
      ),
      body: Column(
        children: [
          _buildRedeemBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCouponList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _redeemController,
              decoration: InputDecoration(
                hintText: '输入兑换码',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                prefixIcon: const Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _isRedeeming ? null : _handleRedeem,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: _isRedeeming
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('兑换'),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponList() {
    final coupons = _filteredCoupons;

    if (coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('暂无优惠券', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coupons.length,
        itemBuilder: (context, index) => _buildCouponCard(coupons[index]),
      ),
    );
  }

  Widget _buildCouponCard(Coupon coupon) {
    final isAvailable = coupon.isAvailable;
    final isUsed = coupon.status == 'used';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAvailable ? AppColors.primary.withValues(alpha: 0.2) : AppColors.divider.withValues(alpha: 0.3),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 100,
              decoration: BoxDecoration(
                gradient: isAvailable
                    ? const LinearGradient(colors: [AppColors.secondary, AppColors.primary])
                    : LinearGradient(colors: [AppColors.textHint, AppColors.textHint.withValues(alpha: 0.7)]),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(coupon.displayValue, style: TextStyle(
                    color: isAvailable ? Colors.white : Colors.white70,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 4),
                  Text(coupon.displayCondition, style: TextStyle(
                    color: isAvailable ? Colors.white70 : Colors.white54,
                    fontSize: 10,
                  )),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coupon.name, style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isAvailable ? AppColors.textPrimary : AppColors.textHint,
                    )),
                    const SizedBox(height: 6),
                    Text('有效期至 ${coupon.displayExpiry}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    if (isUsed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.textHint.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('已使用', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
                      )
                    else if (coupon.isExpired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('已过期', style: TextStyle(color: AppColors.error, fontSize: 10)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('可使用', style: TextStyle(color: AppColors.primary, fontSize: 10)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
