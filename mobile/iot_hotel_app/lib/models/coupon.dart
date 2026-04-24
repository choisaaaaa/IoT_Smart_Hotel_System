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

  @JsonKey(name: 'hotel_ids')
  final String? hotelIds;

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
    this.hotelIds,
    this.code,
    this.totalCount,
    this.usedCount,
    this.createdAt,
  });

  bool get isDiscount => couponType == 'discount' || couponType == 'percentage';

  String get displayValue {
    if (isDiscount) {
      if (discountValue == discountValue.roundToDouble()) {
        return '${discountValue.toInt()}折';
      }
      return '${discountValue.toStringAsFixed(1)}折';
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

  bool get isAvailable => (status == 'active' || status == 'unused') && !isExpired;

  bool isApplicableToHotel(int? targetHotelId) {
    if (targetHotelId == null || hotelId == 0 || hotelId == null) return true;
    if (hotelId == targetHotelId) return true;
    if (hotelIds != null) {
      final ids = hotelIds!.split(',').map((e) => e.trim());
      return ids.contains(targetHotelId.toString());
    }
    return false;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory Coupon.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['discount_value'] ??= normalized['discount_amount'] ?? normalized['value'] ?? 0;
    normalized['coupon_type'] ??= normalized['type'] ?? 'fixed';

    return Coupon(
      id: normalized['id'] ?? 0,
      name: normalized['name']?.toString() ?? normalized['coupon_name']?.toString() ?? '优惠券',
      couponType: normalized['coupon_type']?.toString() ?? 'fixed',
      discountValue: _toDouble(normalized['discount_value']),
      discountAmount: normalized['discount_amount'] != null
          ? _toDouble(normalized['discount_amount'])
          : null,
      minSpend: normalized['min_spend'] != null || normalized['min_amount'] != null
          ? _toDouble(normalized['min_spend'] ?? normalized['min_amount'])
          : null,
      expireDate: normalized['expire_date']?.toString() ?? normalized['valid_to']?.toString() ?? normalized['valid_until']?.toString() ?? normalized['expires_at']?.toString(),
      status: normalized['status']?.toString() ?? 'active',
      hotelId: normalized['hotel_id'] is num ? (normalized['hotel_id'] as num).toInt() : null,
      hotelIds: normalized['hotel_ids']?.toString(),
      code: normalized['code']?.toString() ?? normalized['coupon_code']?.toString(),
      totalCount: normalized['total_count'] is num ? (normalized['total_count'] as num).toInt() : null,
      usedCount: normalized['used_count'] is num ? (normalized['used_count'] as num).toInt() : null,
      createdAt: normalized['created_at']?.toString(),
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
        'hotel_ids': hotelIds,
        'code': code,
        'total_count': totalCount,
        'used_count': usedCount,
        'created_at': createdAt,
      };
}
