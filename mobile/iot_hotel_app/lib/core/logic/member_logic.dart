import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum MemberLevel {
  none(label: '普通会员', color: AppColors.textSecondary, discount: 1.0, pointsMultiplier: 1),
  silver(label: '银会员', color: Color(0xFF9E9E9E), discount: 0.95, pointsMultiplier: 3),
  gold(label: '金会员', color: Color(0xFF795548), discount: 0.88, pointsMultiplier: 9),
  platinum(label: '铂金会员', color: Color(0xFF455A64), discount: 0.85, pointsMultiplier: 12),
  diamond(label: '钻石会员', color: Color(0xFF212121), discount: 0.80, pointsMultiplier: 15);

  final String label;
  final Color color;
  final double discount;
  final int pointsMultiplier;

  const MemberLevel({
    required this.label,
    required this.color,
    required this.discount,
    required this.pointsMultiplier,
  });

  static MemberLevel fromExperience(int experience) {
    if (experience >= 5000) return MemberLevel.diamond;
    if (experience >= 2000) return MemberLevel.platinum;
    if (experience >= 500) return MemberLevel.gold;
    if (experience >= 100) return MemberLevel.silver;
    return MemberLevel.none;
  }

  int nextLevelExperience() {
    switch (this) {
      case MemberLevel.none: return 100;
      case MemberLevel.silver: return 500;
      case MemberLevel.gold: return 2000;
      case MemberLevel.platinum: return 5000;
      case MemberLevel.diamond: return 5000;
    }
  }
}

class MemberLogic {
  // 计算订单可获得的积分
  static int calculateOrderPoints(double amount, MemberLevel level) {
    return (amount * level.pointsMultiplier).floor();
  }

  // 计算订单可获得的经验值 (1元 = 1经验)
  static int calculateOrderExperience(double amount) {
    return amount.floor();
  }

  // 获取会员折扣价
  static double calculateDiscountPrice(double originalPrice, MemberLevel level) {
    return originalPrice * level.discount;
  }
}
