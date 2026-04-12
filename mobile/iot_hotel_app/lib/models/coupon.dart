import 'package:json_annotation/json_annotation.dart';

class Coupon {
  final int id;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'coupon_type')
  final String couponType;

  @JsonKey(name: 'discount_value')
  final double discountValue;

  @JsonKey(name: 'discount_amount')
  final double? discountAmount;

  @JsonKey(name: 'min_spend')
  final double? minSpend;

  @JsonKey(name: 'expire_date')
  final String? expireDate;

  @JsonKey(name: 'status')
  final String status;

  @JsonKey(name: 'hotel_id')
  final int? hotelId;

  @JsonKey(name: 'code')
  final String? code;

  @JsonKey(name: 'total_count')
  final int? totalCount;

  @JsonKey(name: 'used_count')
  final int? usedCount;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  Coupon({
    required this.id,
    required this.name,
    this.couponType = 'fixed',
    this.discountValue = 0.0,
    this.discountAmount,
    this.minSpend,
    this.expireDate,
    this.status = 'active',
    this.hotelId,
    this.code,
    this.totalCount,
    this.usedCount,
    this.createdAt,
  });

  bool get isDiscount => couponType == 'discount' || couponType == 'percentage';

  String get displayValue {
    if (isDiscount) {
      return '${(discountValue * 10).toStringAsFixed(1)}折';
    }
    return '¥${discountValue.toStringAsFixed(0)}';
  }

  String get displayCondition {
    if (minSpend != null && minSpend! > 0) {
      return '满${minSpend!.toStringAsFixed(0)}可用';
    }
    return '无门槛';
  }

  String get displayExpiry {
    if (expireDate == null || expireDate!.isEmpty) return '长期有效';
    try {
      final date = DateTime.parse(expireDate!);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return expireDate ?? '长期有效';
    }
  }

  bool get isExpired {
    if (expireDate == null || expireDate!.isEmpty) return false;
    try {
      return DateTime.parse(expireDate!).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  bool get isAvailable => status == 'active' && !isExpired;

  factory Coupon.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['discount_value'] ??= normalized['discount_amount'] ?? normalized['value'] ?? 0;
    normalized['coupon_type'] ??= normalized['type'] ?? 'fixed';

    return Coupon(
      id: normalized['id'] ?? 0,
      name: normalized['name'] ?? '优惠券',
      couponType: normalized['coupon_type'],
      discountValue: (normalized['discount_value'] ?? 0).toDouble(),
      discountAmount: normalized['discount_amount'] != null
          ? (normalized['discount_amount']).toDouble()
          : null,
      minSpend: normalized['min_spend'] != null
          ? (normalized['min_spend']).toDouble()
          : null,
      expireDate: normalized['expire_date'] ?? normalized['valid_until'] ?? normalized['expires_at'],
      status: normalized['status'] ?? 'active',
      hotelId: normalized['hotel_id'],
      code: normalized['code'] ?? normalized['coupon_code'],
      totalCount: normalized['total_count'],
      usedCount: normalized['used_count'],
      createdAt: normalized['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'coupon_type': couponType,
        'discount_value': discountValue,
        'discount_amount': discountAmount,
        'min_spend': minSpend,
        'expire_date': expireDate,
        'status': status,
        'hotel_id': hotelId,
        'code': code,
        'total_count': totalCount,
        'used_count': usedCount,
        'created_at': createdAt,
      };
}
