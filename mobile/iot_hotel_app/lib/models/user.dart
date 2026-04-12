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

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? 0,
        username: json['username'] ?? '',
        email: json['email'],
        hotelId: json['hotel_id'],
        role: json['role'] ?? AppRoles.customer,
        phone: json['phone'],
        uid: json['uid'],
        avatar: json['avatar'],
        permissions: json['permissions'] != null ? List<String>.from(json['permissions']) : null,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'username': username, 'email': email, 'hotel_id': hotelId, 'role': role,
        'phone': phone, 'uid': uid, 'avatar': avatar, 'permissions': permissions, 'created_at': createdAt?.toIso8601String(),
      };

  String get displayName => username;
}
