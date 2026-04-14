import 'package:flutter/material.dart';

@immutable
class AppNotification {
  final int id;
  final String title;
  final String content;
  final String? type;
  final bool isRead;
  final DateTime? createdAt;
  final int? relatedId;
  final String? relatedType;

  const AppNotification({
    required this.id,
    required this.title,
    this.content = '',
    this.type,
    this.isRead = false,
    this.createdAt,
    this.relatedId,
    this.relatedType,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['is_read'] ??= normalized['read'] ?? normalized['isRead'] ?? false;
    normalized['created_at'] ??= normalized['created_at'] ?? normalized['createdAt'];
    normalized['related_id'] ??= normalized['related_id'] ?? normalized['relatedId'];
    normalized['related_type'] ??= normalized['related_type'] ?? normalized['relatedType'];

    return AppNotification(
      id: normalized['id'] as int? ?? 0,
      title: normalized['title']?.toString() ?? '',
      content: normalized['content']?.toString() ?? normalized['body']?.toString() ?? '',
      type: normalized['type']?.toString() ?? normalized['category']?.toString(),
      isRead: normalized['is_read'] == true || normalized['is_read'] == 1,
      createdAt: _parseDateTime(normalized['created_at']),
      relatedId: normalized['related_id'] as int?,
      relatedType: normalized['related_type']?.toString(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String get typeLabel {
    switch (type) {
      case 'booking': return '预订通知';
      case 'checkin': return '入住通知';
      case 'checkout': return '退房通知';
      case 'payment': return '支付通知';
      case 'system': return '系统通知';
      case 'promotion': return '优惠活动';
      default: return '通知';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'booking': return Icons.receipt_long_outlined;
      case 'checkin': return Icons.hotel_outlined;
      case 'checkout': return Icons.logout_outlined;
      case 'payment': return Icons.payment_outlined;
      case 'system': return Icons.info_outline;
      case 'promotion': return Icons.local_offer_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      content: content,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      relatedId: relatedId,
      relatedType: relatedType,
    );
  }
}
