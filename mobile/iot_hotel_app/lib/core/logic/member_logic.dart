import 'package:flutter/material.dart';

enum MemberLevel {
  standard(
    label: '普通会员',
    color: Color(0xFF4B6CB7),
    discount: 1.0,
    pointsMultiplier: 1,
    levelNumber: 1,
    nextExp: 100,
    gradientColors: [Color(0xFF4B6CB7), Color(0xFF182848)],
    themeBg: Color(0xFFF0F5FF),
  ),
  silver(
    label: '银会员',
    color: Color(0xFF90A4AE),
    discount: 0.95,
    pointsMultiplier: 3,
    levelNumber: 2,
    nextExp: 500,
    gradientColors: [Color(0xFFBDC3C7), Color(0xFF2C3E50)],
    themeBg: Color(0xFFF0F4F8),
  ),
  gold(
    label: '金会员',
    color: Color(0xFFD4AF37),
    discount: 0.88,
    pointsMultiplier: 9,
    levelNumber: 3,
    nextExp: 2000,
    gradientColors: [Color(0xFFD4AF37), Color(0xFF1A1A1A)],
    themeBg: Color(0xFFFFFDF0),
  ),
  platinum(
    label: '铂金会员',
    color: Color(0xFF535C68),
    discount: 0.85,
    pointsMultiplier: 12,
    levelNumber: 4,
    nextExp: 5000,
    gradientColors: [Color(0xFFE5E4E2), Color(0xFF434343)],
    themeBg: Color(0xFFF1F2F6),
  ),
  diamond(
    label: '钻石会员',
    color: Color(0xFF30CFD0),
    discount: 0.80,
    pointsMultiplier: 15,
    levelNumber: 5,
    nextExp: 5000,
    gradientColors: [Color(0xFF30CFD0), Color(0xFF330867)],
    themeBg: Color(0xFFF0FBFF),
  );

  final String label;
  final Color color;
  final double discount;
  final int pointsMultiplier;
  final int levelNumber;
  final int nextExp;
  final List<Color> gradientColors;
  final Color themeBg;

  const MemberLevel({
    required this.label,
    required this.color,
    required this.discount,
    required this.pointsMultiplier,
    required this.levelNumber,
    required this.nextExp,
    required this.gradientColors,
    required this.themeBg,
  });

  static MemberLevel fromExperience(int experience) {
    if (experience >= 5000) return MemberLevel.diamond;
    if (experience >= 2000) return MemberLevel.platinum;
    if (experience >= 500) return MemberLevel.gold;
    if (experience >= 100) return MemberLevel.silver;
    return MemberLevel.standard;
  }

  static MemberLevel fromKey(String key) {
    switch (key.toLowerCase()) {
      case 'diamond': return MemberLevel.diamond;
      case 'platinum': return MemberLevel.platinum;
      case 'gold': return MemberLevel.gold;
      case 'silver': return MemberLevel.silver;
      default: return MemberLevel.standard;
    }
  }

  int nextLevelExperience() => nextExp;

  bool get isMaxLevel => this == MemberLevel.diamond;

  String get discountText => discount < 1.0 ? '${(discount * 10).toStringAsFixed(1)}折' : '无折扣';

  String get pointsText => '$pointsMultiplier倍积分';
}

class MemberLogic {
  static int calculateOrderPoints(double amount, MemberLevel level) {
    return (amount * level.pointsMultiplier).floor();
  }

  static int calculateOrderExperience(double amount) {
    return amount.floor();
  }

  static double calculateDiscountPrice(double originalPrice, MemberLevel level) {
    return originalPrice * level.discount;
  }
}
