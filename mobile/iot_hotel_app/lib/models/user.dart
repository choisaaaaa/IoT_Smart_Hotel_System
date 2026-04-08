import 'package:json_annotation/json_annotation.dart';

class User {
  final int id;
  final String username;
  final String? email;
  final String role;
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
    this.role = 'guest',
    this.avatar,
    this.permissions,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? 0,
        username: json['username'] ?? '',
        email: json['email'],
        role: json['role'] ?? 'guest',
        avatar: json['avatar'],
        permissions: json['permissions'] != null ? List<String>.from(json['permissions']) : null,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'username': username, 'email': email, 'role': role,
        'avatar': avatar, 'permissions': permissions, 'created_at': createdAt?.toIso8601String(),
      };
}
