import 'package:json_annotation/json_annotation.dart';
import '../core/auth/auth_state_notifier.dart';

class User {
  final int id;
  final String username;
  final String? email;
  @JsonKey(name: 'hotel_id')
  final int? hotelId;
  final String role;
  final String? phone;
  final String? uid;
  @JsonKey(name: 'avatar')
  final String? avatar;
  @JsonKey(name: 'permissions')
  final List<String>? permissions;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  User({
    required this.id,
    required this.username,
    this.email,
    this.hotelId,
    this.role = AppRoles.customer,
    this.phone,
    this.uid,
    this.avatar,
    this.permissions,
    this.createdAt,
  });

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: _toInt(json['id']) ?? 0,
        username: json['username']?.toString() ?? '',
        email: json['email']?.toString(),
        hotelId: _toInt(json['hotel_id']),
        role: json['role']?.toString() ?? AppRoles.customer,
        phone: json['phone']?.toString(),
        uid: json['uid']?.toString(),
        avatar: json['avatar']?.toString(),
        permissions: json['permissions'] != null ? List<String>.from(json['permissions']) : null,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'username': username, 'email': email, 'hotel_id': hotelId, 'role': role,
        'phone': phone, 'uid': uid, 'avatar': avatar, 'permissions': permissions, 'created_at': createdAt?.toIso8601String(),
      };

  String get displayName => username;
}
