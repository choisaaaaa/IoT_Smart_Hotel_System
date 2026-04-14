import 'package:flutter/foundation.dart';

@immutable
class RoleApplication {
  final int? id;
  final String applicationType;
  final int? hotelId;
  final String? hotelName;
  final String? hotelAddress;
  final String? reason;
  final String status;
  final DateTime? createdAt;

  const RoleApplication({
    this.id,
    required this.applicationType,
    this.hotelId,
    this.hotelName,
    this.hotelAddress,
    this.reason,
    this.status = 'pending',
    this.createdAt,
  });

  factory RoleApplication.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['application_type'] ??= normalized['applicationType'] ?? normalized['type'] ?? '';
    normalized['hotel_name'] ??= normalized['hotel_name'] ?? normalized['target_hotel_name'] ?? normalized['hotelName'];
    normalized['hotel_address'] ??= normalized['hotel_address'] ?? normalized['hotelAddress'];
    normalized['created_at'] ??= normalized['created_at'] ?? normalized['createdAt'];

    return RoleApplication(
      id: normalized['id'] as int?,
      applicationType: normalized['application_type']?.toString() ?? '',
      hotelId: normalized['hotel_id'] as int?,
      hotelName: normalized['hotel_name']?.toString(),
      hotelAddress: normalized['hotel_address']?.toString(),
      reason: normalized['reason']?.toString(),
      status: normalized['status']?.toString() ?? 'pending',
      createdAt: _parseDateTime(normalized['created_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String get typeLabel {
    switch (applicationType) {
      case 'create_hotel': return '创建酒店';
      case 'bind_employee': return '绑定员工';
      default: return applicationType;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'approved': return '已通过';
      case 'rejected': return '已拒绝';
      case 'pending': return '待审核';
      default: return status;
    }
  }
}
