import 'package:flutter/material.dart';

class MemberLevel {
  final String key;
  final String label;
  final Color color;
  final double discount;
  final int pointsMultiplier;
  final int levelNumber;
  final int nextExp;
  final List<Color> gradientColors;
  final Color themeBg;

  const MemberLevel({
    required this.key,
    required this.label,
    required this.color,
    required this.discount,
    required this.pointsMultiplier,
    required this.levelNumber,
    required this.nextExp,
    required this.gradientColors,
    required this.themeBg,
  });

  static MemberLevel fromExperience(int experience, {Map<String, dynamic>? config}) {
    final tiers = config?['tiers'] as List<dynamic>? ?? _defaultTiers;
    for (int i = tiers.length - 1; i >= 0; i--) {
      final tier = tiers[i] as Map<String, dynamic>;
      final minExp = (tier['min_experience'] as num?)?.toInt() ?? 0;
      if (experience >= minExp) {
        return _fromTierConfig(tier, i);
      }
    }
    return standard;
  }

  static MemberLevel _fromTierConfig(Map<String, dynamic> tier, int index) {
    final key = (tier['tier_key'] as String?) ?? _defaultKeys[index];
    switch (key.toLowerCase()) {
      case 'diamond': return diamond;
      case 'platinum': return platinum;
      case 'gold': return gold;
      case 'silver': return silver;
      default: return standard;
    }
  }

  static MemberLevel fromKey(String key) {
    switch (key.toLowerCase()) {
      case 'diamond': return diamond;
      case 'platinum': return platinum;
      case 'gold': return gold;
      case 'silver': return silver;
      default: return standard;
    }
  }

  int nextLevelExperience() => nextExp;

  bool get isMaxLevel => this == MemberLevel.diamond;

  String get discountText => discount < 1.0 ? '${(discount * 10).toStringAsFixed(1)}折' : '无折扣';

  String get pointsText => '$pointsMultiplier倍积分';

  static const List<Map<String, dynamic>> _defaultTiers = [
    {'tier_key': 'standard', 'min_experience': 0},
    {'tier_key': 'silver', 'min_experience': 100},
    {'tier_key': 'gold', 'min_experience': 500},
    {'tier_key': 'platinum', 'min_experience': 2000},
    {'tier_key': 'diamond', 'min_experience': 5000},
  ];

  static const List<String> _defaultKeys = ['standard', 'silver', 'gold', 'platinum', 'diamond'];

  static final MemberLevel standard = MemberLevel(
    key: 'standard',
    label: '普通会员',
    color: const Color(0xFF4B6CB7),
    discount: 1.0,
    pointsMultiplier: 1,
    levelNumber: 1,
    nextExp: 100,
    gradientColors: const [Color(0xFF4B6CB7), Color(0xFF182848)],
    themeBg: const Color(0xFFF0F5FF),
  );

  static final MemberLevel silver = MemberLevel(
    key: 'silver',
    label: '银会员',
    color: const Color(0xFF90A4AE),
    discount: 0.95,
    pointsMultiplier: 5,
    levelNumber: 2,
    nextExp: 500,
    gradientColors: const [Color(0xFFBDC3C7), Color(0xFF2C3E50)],
    themeBg: const Color(0xFFF0F4F8),
  );

  static final MemberLevel gold = MemberLevel(
    key: 'gold',
    label: '金会员',
    color: const Color(0xFFD4AF37),
    discount: 0.88,
    pointsMultiplier: 9,
    levelNumber: 3,
    nextExp: 2000,
    gradientColors: const [Color(0xFFD4AF37), Color(0xFF1A1A1A)],
    themeBg: const Color(0xFFFFFDF0),
  );

  static final MemberLevel platinum = MemberLevel(
    key: 'platinum',
    label: '铂金会员',
    color: const Color(0xFF535C68),
    discount: 0.85,
    pointsMultiplier: 12,
    levelNumber: 4,
    nextExp: 5000,
    gradientColors: const [Color(0xFFE5E4E2), Color(0xFF434343)],
    themeBg: const Color(0xFFF1F2F6),
  );

  static final MemberLevel diamond = MemberLevel(
    key: 'diamond',
    label: '钻石会员',
    color: const Color(0xFF30CFD0),
    discount: 0.80,
    pointsMultiplier: 15,
    levelNumber: 5,
    nextExp: 5000,
    gradientColors: const [Color(0xFF30CFD0), Color(0xFF330867)],
    themeBg: const Color(0xFFF0FBFF),
  );

  static List<MemberLevel> get allLevels => [standard, silver, gold, platinum, diamond];
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
