import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class MemberPage extends StatelessWidget {
  const MemberPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('华住会会员', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildMemberCard(),
            const SizedBox(height: 24),
            _buildBenefitGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF424242), Color(0xFF212121)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GOLD MEMBER', style: TextStyle(color: AppColors.gold, letterSpacing: 2, fontSize: 12)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.gold),
                child: const Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('谭玮坤', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('186 **** 4262', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildCardStat('积分', '3522'),
              const SizedBox(width: 40),
              _buildCardStat('间夜', '12'),
              const SizedBox(width: 40),
              _buildCardStat('优惠券', '3'),
            ],
          ),
        ],
      ),
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

  Widget _buildBenefitGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 20,
      children: [
        _buildBenefitIcon(Icons.restaurant, '免费早餐'),
        _buildBenefitIcon(Icons.history, '延迟退房'),
        _buildBenefitIcon(Icons.trending_up, '积分加倍'),
        _buildBenefitIcon(Icons.room_preferences, '房型升级'),
        _buildBenefitIcon(Icons.wine_bar, '行政酒廊'),
        _buildBenefitIcon(Icons.local_parking, '免费停车'),
        _buildBenefitIcon(Icons.cleaning_services, '快速清洁'),
        _buildBenefitIcon(Icons.card_giftcard, '生日礼包'),
      ],
    );
  }

  Widget _buildBenefitIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textPrimary, size: 28),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
