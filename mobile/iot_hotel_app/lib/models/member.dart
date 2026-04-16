import 'package:json_annotation/json_annotation.dart';

class Member {
  final int id;

  @JsonKey(name: 'phone')
  final String phone;

  @JsonKey(name: 'name')
  final String? name;

  @JsonKey(name: 'member_level')
  final String memberLevel;

  @JsonKey(name: 'points')
  final int points;

  @JsonKey(name: 'experience')
  final double experience;

  @JsonKey(name: 'total_spent')
  final double totalSpent;

  @JsonKey(name: 'balance')
  final double balance;

  @JsonKey(name: 'total_stays')
  final int totalStays;

  @JsonKey(name: 'last_checkin_date')
  final String? lastCheckinDate;

  @JsonKey(name: 'coupon_count')
  final int? couponCount;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  Member({
    required this.id,
    required this.phone,
    this.name,
    this.memberLevel = 'standard',
    this.points = 0,
    this.experience = 0.0,
    this.totalSpent = 0.0,
    this.balance = 0.0,
    this.totalStays = 0,
    this.lastCheckinDate,
    this.couponCount,
    this.createdAt,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);

    return Member(
      id: _toInt(normalized['id']) ?? 0,
      phone: normalized['phone']?.toString() ?? '',
      name: normalized['name']?.toString() ?? normalized['username']?.toString(),
      memberLevel: normalized['member_level']?.toString() ?? 'standard',
      points: _toInt(normalized['points']) ?? 0,
      experience: _toDouble(normalized['experience'] ?? normalized['total_spent'] ?? 0),
      totalSpent: _toDouble(normalized['total_spent'] ?? 0),
      balance: _toDouble(normalized['balance'] ?? 0),
      totalStays: _toInt(normalized['total_stays'] ?? normalized['checkin_days'] ?? 0) ?? 0,
      lastCheckinDate: normalized['last_checkin_date']?.toString(),
      couponCount: _toInt(normalized['coupon_count'] ?? normalized['coupons_count']),
      createdAt: normalized['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'member_level': memberLevel,
        'points': points,
        'experience': experience,
        'total_spent': totalSpent,
        'balance': balance,
        'total_stays': totalStays,
        'last_checkin_date': lastCheckinDate,
        'coupon_count': couponCount,
        'created_at': createdAt,
      };
}
