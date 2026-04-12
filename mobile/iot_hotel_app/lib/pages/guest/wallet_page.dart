import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/logic/member_logic.dart';
import '../../services/member_service.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  double _selectedAmount = 100;
  bool _isLoading = false;
  final List<double> _quickAmounts = [100, 300, 500, 1000, 2000, 5000];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('我的钱包', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final assetsAsync = ref.watch(myAssetsProvider);

          return assetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('加载失败: $err')),
            data: (apiResult) {
              final member = apiResult.data;
              final balance = member?.balance ?? 0.0;
              final level = MemberLevel.fromKey(member?.memberLevel ?? 'standard');

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(balance, level),
                    if (level.discount < 1.0) _buildBonusInfo(level),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Text('快捷充值', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _buildQuickAmountsGrid(level),
                    const SizedBox(height: 40),
                    _buildRechargeButton(level),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(double balance, MemberLevel level) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: level.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: level.gradientColors.first.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('当前可用余额', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(level.label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('¥', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(balance.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                level.discount < 1.0
                    ? '${level.label}充值额外赠送${((1 - level.discount) * 100).toStringAsFixed(0)}%'
                    : '充值享积分奖励',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBonusInfo(MemberLevel level) {
    final bonusPercent = ((1 - level.discount) * 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: level.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, color: level.color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${level.label}专享：充值满100元额外赠送$bonusPercent%余额',
              style: TextStyle(color: level.color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountsGrid(MemberLevel level) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
        ),
        itemCount: _quickAmounts.length,
        itemBuilder: (context, index) {
          final amount = _quickAmounts[index];
          final isSelected = _selectedAmount == amount;
          final bonus = level.discount < 1.0 ? (amount * (1 - level.discount)).toStringAsFixed(0) : null;

          return GestureDetector(
            onTap: () => setState(() => _selectedAmount = amount),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? level.color.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? level.color : AppColors.divider.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
          );
        },
      ),
    );
  }

  Widget _buildRechargeButton(MemberLevel level) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _handleRecharge(),
          style: ElevatedButton.styleFrom(
            backgroundColor: level.color,
            disabledBackgroundColor: AppColors.textHint,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('立即充值 ¥${_selectedAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  Future<void> _handleRecharge() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(memberServiceProvider).recharge(_selectedAmount);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('充值成功！¥${_selectedAmount.toStringAsFixed(0)} 已到账'), backgroundColor: AppColors.success),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
