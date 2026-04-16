import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/member_service.dart';
import '../../core/logic/member_logic.dart';

class MemberPage extends ConsumerStatefulWidget {
  const MemberPage({super.key});

  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  bool _isCheckinLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('会员中心', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildMemberCard(),
              const SizedBox(height: 16),
              _buildAssetsGrid(),
              const SizedBox(height: 16),
              _buildMemberRights(),
              const SizedBox(height: 16),
              _buildRechargeSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard() {
    final authService = ref.watch(authServiceProvider);
    final assetsAsync = ref.watch(myAssetsProvider);

    return FutureBuilder(
      future: authService.getCurrentUser(),
      builder: (context, userSnapshot) {
        return assetsAsync.when(
          loading: () => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
          error: (err, stack) => SizedBox(height: 260, child: Center(child: Text('加载失败: $err'))),
          data: (apiResult) {
            final user = userSnapshot.data;
            final member = apiResult.data ?? ref.read(memberServiceProvider).cachedMember;

            final levelKey = member?.memberLevel ?? 'standard';
            final level = MemberLevel.fromKey(levelKey);
            final experience = member?.experience ?? 0;
            final points = member?.points ?? 0;
            final nextExp = level.nextLevelExperience();
            final progress = (experience / nextExp).clamp(0.0, 1.0);

            final lastCheckin = member?.lastCheckinDate;
            final today = DateTime.now().toIso8601String().split('T')[0];
            final bool isAlreadyCheckedIn = lastCheckin != null && lastCheckin.contains(today);

            return Container(
              width: double.infinity,
              height: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: level.gradientColors,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: level.gradientColors.first.withValues(alpha: 0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Colors.white, Color(0xFFF9E29C)],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'IOT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'SMART HOTEL',
                                  style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 2),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF9E29C)]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                level.label,
                                style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF9E29C)]),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.white24,
                                child: const Icon(Icons.person, color: Colors.white, size: 36),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.username ?? '未登录',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user?.phone ?? '********',
                                    style: TextStyle(color: Colors.white60, fontSize: 13, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isAlreadyCheckedIn)
                              _buildCheckinButton(level, false)
                            else
                              _buildCheckinButton(level, true),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  level.isMaxLevel
                                      ? '成长值 $experience (已满级)'
                                      : '成长值 ${experience.toInt()} / $nextExp',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('积分 $points', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF9E29C)),
                                    minHeight: 8,
                                  ),
                                ],
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
          },
        );
      },
    );
  }

  Widget _buildCheckinButton(MemberLevel level, bool isAlreadyCheckedIn) {
    return ElevatedButton(
      onPressed: isAlreadyCheckedIn ? null : (_isCheckinLoading ? null : _handleCheckin),
      style: ElevatedButton.styleFrom(
        backgroundColor: isAlreadyCheckedIn ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.25),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: _isCheckinLoading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(
              isAlreadyCheckedIn ? '已签到' : '签到',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
    );
  }

  Widget _buildAssetsGrid() {
    final assetsAsync = ref.watch(myAssetsProvider);

    return assetsAsync.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (err, stack) => const SizedBox.shrink(),
      data: (apiResult) {
        final member = apiResult.data ?? ref.read(memberServiceProvider).cachedMember;
        final levelKey = member?.memberLevel ?? 'standard';
        final level = MemberLevel.fromKey(levelKey);

        final coupons = member?.couponCount ?? 0;
        final points = member?.points ?? 0;
        final balance = member?.balance ?? 0.0;
        final totalStays = member?.totalStays ?? 0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('我的资产', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildAssetItem(Icons.confirmation_number_outlined, '优惠券', '$coupons', level)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAssetItem(Icons.stars_outlined, '积分', '$points', level)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildAssetItem(Icons.account_balance_wallet_outlined, '余额', '¥${balance.toStringAsFixed(2)}', level)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAssetItem(Icons.bed_outlined, '累计入住', '$totalStays晚', level)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssetItem(IconData icon, String label, String value, MemberLevel level) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: level.themeBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: level.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: level.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRights() {
    final assetsAsync = ref.watch(myAssetsProvider);

    return assetsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (apiResult) {
        final member = apiResult.data ?? ref.read(memberServiceProvider).cachedMember;
        final levelKey = member?.memberLevel ?? 'standard';
        final level = MemberLevel.fromKey(levelKey);

        final allLevels = MemberLevel.allLevels;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('尊享权益', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(level.label, style: TextStyle(color: level.color, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildRightItem(
                      Icons.percent_rounded,
                      '订房折扣',
                      level.discountText,
                      isActive: level.discount < 1.0,
                      level: level,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRightItem(
                      Icons.bolt_rounded,
                      '积分倍率',
                      level.pointsText,
                      isActive: level.pointsMultiplier > 1,
                      level: level,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('等级权益对比', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...allLevels.map((l) => _buildLevelRow(l, l == level)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRightItem(IconData icon, String label, String value, {required bool isActive, required MemberLevel level}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? level.themeBg : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? level.color.withValues(alpha: 0.3) : AppColors.divider.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? level.color.withValues(alpha: 0.1) : AppColors.textHint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isActive ? level.color : AppColors.textHint,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: isActive ? AppColors.textPrimary : AppColors.textHint)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? level.color : AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow(MemberLevel level, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent ? level.themeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isCurrent ? Border.all(color: level.color.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: level.gradientColors),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              level.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? level.color : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              level.discountText,
              style: TextStyle(
                fontSize: 12,
                color: isCurrent ? level.color : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              level.pointsText,
              style: TextStyle(
                fontSize: 12,
                color: isCurrent ? level.color : AppColors.textSecondary,
              ),
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: level.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('当前', style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _buildRechargeSection() {
    final assetsAsync = ref.watch(myAssetsProvider);

    return assetsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (apiResult) {
        final member = apiResult.data ?? ref.read(memberServiceProvider).cachedMember;
        final levelKey = member?.memberLevel ?? 'standard';
        final level = MemberLevel.fromKey(levelKey);
        final balance = member?.balance ?? 0.0;

        final amounts = [100, 200, 500, 1000];
        int? selectedAmount;

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('余额充值', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('当前余额 ¥${balance.toStringAsFixed(2)}', style: TextStyle(color: level.color, fontSize: 13)),
                    ],
                  ),
                  if (level.discount < 1.0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: level.color.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.card_giftcard, color: level.color, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${level.label}充值专享额外赠送${((1 - level.discount) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(color: level.color, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: amounts.map((amount) {
                      final bonus = level.discount < 1.0 ? (amount * (1 - level.discount)).toStringAsFixed(0) : null;
                      final isSelected = selectedAmount == amount;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => selectedAmount = amount),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? level.color.withValues(alpha: 0.1) : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? level.color : AppColors.divider.withValues(alpha: 0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text('¥$amount', style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? level.color : AppColors.textPrimary,
                                )),
                                if (bonus != null)
                                  Text('送¥$bonus', style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected ? level.color : AppColors.secondary,
                                  )),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedAmount != null ? () => _handleRecharge(selectedAmount!) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: level.color,
                        disabledBackgroundColor: AppColors.textHint,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('立即充值', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCheckin() async {
    setState(() => _isCheckinLoading = true);
    final result = await ref.read(memberServiceProvider).checkin();
    if (mounted) {
      setState(() => _isCheckinLoading = false);
      if (result.alreadyCheckedIn) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('今日已签到过了哦')));
      } else {
        String msg = '签到成功！获得 ${result.experience} 成长值';
        if (result.couponName != null) {
          msg += '，赠送 ${result.couponName}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
      }
      ref.invalidate(myAssetsProvider);
    }
  }

  Future<void> _handleRecharge(int amount) async {
    try {
      final result = await ref.read(memberServiceProvider).recharge(amount.toDouble());
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('充值成功！¥$amount 已到账'), backgroundColor: AppColors.success),
        );
        ref.invalidate(myAssetsProvider);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '充值失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('充值失败，请重试')),
        );
      }
    }
  }
}
