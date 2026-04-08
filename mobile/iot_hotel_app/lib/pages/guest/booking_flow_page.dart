import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class BookingFlowPage extends StatelessWidget {
  const BookingFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20), onPressed: () => context.pop()),
        title: const Text('星程珠海金湾机场酒店', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildBookingInfo(),
            _buildGuestInfo(),
            _buildCouponSection(),
            _buildMemberBenefits(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: _buildBottomPayBar(context),
    );
  }

  Widget _buildBookingInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('4月08日 今天 - 4月09日 明天', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Text('1晚', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              Spacer(),
              Text('房型详情', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('商务双床房 | 金会员9倍积分房', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Text('28-30m² | 2张1.35米床 | 外景窗', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Divider(height: 32),
          const Text('4月8日 18:00 前可免费取消，18:00 后不可取消', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGuestInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Text('订房信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('30秒入住 >', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
              const Spacer(),
              const Icon(Icons.remove_circle_outline, color: AppColors.textHint),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('1间', style: TextStyle(fontWeight: FontWeight.bold))),
              const Icon(Icons.add_circle_outline, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 20),
          const _InfoInputRow(label: '入住人', value: '谭玮坤'),
          const _InfoInputRow(label: '联系手机', value: '+86 186 7506 4262'),
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('订房优惠', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('优惠券', style: TextStyle(fontSize: 14)),
              Text('暂无可用 >', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('积分当钱花', style: TextStyle(fontSize: 14)),
              Text('最高可用3500积分(抵 ¥35) >', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBenefits() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite, color: AppColors.gold, size: 16),
              SizedBox(width: 8),
              Text('金会员权益 · 20项', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildBenefitTile('早餐', '赠 1份/天'),
              const SizedBox(width: 12),
              _buildBenefitTile('延迟退房', '至 14:00'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('离店赠积分 (限本人)  9倍加速 预计 2601积分', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildBenefitTile(String title, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPayBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('订单金额 ', style: TextStyle(fontSize: 12)),
                  const Text('¥', style: TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
                  const Text('289', style: TextStyle(color: AppColors.secondary, fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('.00', style: TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('明细 ^', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 50,
            width: 140,
            child: FilledButton(
              onPressed: () => _showSuccessDialog(context),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
              child: const Text('提交订单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('预订成功'),
        content: const Text('您的订单已提交，请在我的订单中查看。'),
        actions: [TextButton(onPressed: () => ctx.pop(), child: const Text('确定'))],
      ),
    );
  }
}

class _InfoInputRow extends StatelessWidget {
  final String label, value;
  const _InfoInputRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
