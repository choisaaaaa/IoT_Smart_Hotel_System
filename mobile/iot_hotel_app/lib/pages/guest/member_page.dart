import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/member_service.dart';
import '../../core/logic/member_logic.dart';
import '../../models/user.dart';
import '../../core/network/api_result.dart';

class MemberPage extends ConsumerStatefulWidget {
  const MemberPage({super.key});

  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  bool _isCheckedIn = false;
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    _loadCheckinStatus();
  }

  Future<void> _loadCheckinStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckin = prefs.getString('last_checkin_date') ?? '';
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (mounted) setState(() => _isCheckedIn = lastCheckin == today);
  }

  Future<void> _doCheckin() async {
    if (_isCheckingIn || _isCheckedIn) return;
    setState(() => _isCheckingIn = true);
    try {
      final result = await ref.read(memberServiceProvider).checkin();
      if (mounted) {
        setState(() {
          _isCheckedIn = true;
          _isCheckingIn = false;
        });
        if (result.alreadyCheckedIn) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('今日已签到')));
        } else {
          final msg = StringBuffer('签到成功！获得${result.experience}经验');
          if (result.couponName != null) {
            msg.write('，额外获得${result.couponName}');
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg.toString()),
            backgroundColor: AppColors.success,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('签到失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('会员中心', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildMemberCard(ref),
            const SizedBox(height: 16),
            _buildCheckinCard(),
            const SizedBox(height: 24),
            _buildBenefitGrid(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('每日签到', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              FutureBuilder<int>(
                future: _getCheckinStreak(),
                builder: (context, snapshot) {
                  final streak = snapshot.data ?? 0;
                  return Text('已连续签到$streak天', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (i) {
              final dayLabel = ['一', '二', '三', '四', '五', '六', '日'][i];
              final isToday = DateTime.now().weekday == (i + 1 > 7 ? 1 : i + 1);
              final isPast = DateTime.now().weekday > (i + 1);
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isPast || (_isCheckedIn && isToday))
                            ? AppColors.primary
                            : isToday
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : AppColors.divider,
                      ),
                      child: Center(
                        child: (isPast || (_isCheckedIn && isToday))
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(dayLabel, style: TextStyle(fontSize: 11, color: isToday ? AppColors.primary : AppColors.textHint)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('周$dayLabel', style: TextStyle(fontSize: 9, color: isToday ? AppColors.primary : AppColors.textHint)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _isCheckedIn ? null : _doCheckin,
              style: FilledButton.styleFrom(
                backgroundColor: _isCheckedIn ? AppColors.divider : AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCheckingIn
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isCheckedIn ? '今日已签到 ✓' : '立即签到 +10经验',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _isCheckedIn ? AppColors.textHint : Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getCheckinStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('checkin_streak') ?? 0;
  }

  Widget _buildMemberCard(WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final memberService = ref.watch(memberServiceProvider);

    return FutureBuilder(
      future: Future.wait([
        authService.getCurrentUser(),
        memberService.getMyAssets(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        
        final user = snapshot.data![0] as User?;
        final assetsResult = snapshot.data![1] as ApiResult?;
        final assets = assetsResult?.data ?? {};
        
        final double totalSpent = double.tryParse(assets['total_spent']?.toString() ?? '0') ?? 0;
        final level = MemberLevel.fromExperience(totalSpent.floor());
        final points = assets['points']?.toString() ?? '0';
        final coupons = assets['coupons_count']?.toString() ?? '0';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [level.color.withValues(alpha: 0.8), level.color]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: level.color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(level.label.toUpperCase(), style: const TextStyle(color: Colors.white, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                    child: const Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(user?.username ?? '未登录', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(user?.email != null ? user!.email! : '邮箱未绑定', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildCardStat('积分', points),
                  const SizedBox(width: 40),
                  _buildCardStat('经验', totalSpent.floor().toString()),
                  const SizedBox(width: 40),
                  _buildCardStat('优惠券', coupons),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildCardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBenefitGrid(WidgetRef ref) {
    final memberService = ref.watch(memberServiceProvider);
    return FutureBuilder(
      future: memberService.getMyAssets(),
      builder: (context, snapshot) {
        final apiResult = snapshot.data;
        final assets = apiResult?.data ?? {};
        final double totalSpent = double.tryParse(assets['total_spent']?.toString() ?? '0') ?? 0;
        final level = MemberLevel.fromExperience(totalSpent.floor());

        final allBenefits = [
          _BenefitDef(Icons.restaurant, '免费早餐', MemberLevel.gold),
          _BenefitDef(Icons.history, '延迟退房', MemberLevel.silver),
          _BenefitDef(Icons.trending_up, '积分加倍', MemberLevel.silver),
          _BenefitDef(Icons.room_preferences, '房型升级', MemberLevel.platinum),
          _BenefitDef(Icons.wine_bar, '行政酒廊', MemberLevel.platinum),
          _BenefitDef(Icons.local_parking, '免费停车', MemberLevel.gold),
          _BenefitDef(Icons.cleaning_services, '快速清洁', MemberLevel.silver),
          _BenefitDef(Icons.card_giftcard, '生日礼包', MemberLevel.diamond),
        ];

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 20,
          children: allBenefits.map((b) {
            final unlocked = level.index >= b.requiredLevel.index;
            return _buildBenefitIcon(b.icon, b.label, unlocked);
          }).toList(),
        );
      },
    );
  }

  Widget _buildBenefitIcon(IconData icon, String label, bool unlocked) {
    return Column(
      children: [
        Stack(
          children: [
            Icon(icon, color: unlocked ? AppColors.primary : AppColors.textHint, size: 28),
            if (!unlocked)
              Positioned(
                right: -4,
                top: -4,
                child: Icon(Icons.lock, size: 12, color: AppColors.textHint),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: unlocked ? AppColors.textSecondary : AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

class _BenefitDef {
  final IconData icon;
  final String label;
  final MemberLevel requiredLevel;
  const _BenefitDef(this.icon, this.label, this.requiredLevel);
}
