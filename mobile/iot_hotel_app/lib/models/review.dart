import 'dart:convert' show JsonDecoder;
import 'package:json_annotation/json_annotation.dart';

class Review {
  final int id;

  final int orderId;

  final int? hotelId;

  final int? roomTypeId;

  final int? userId;

  final int? memberId;

  final double score;

  final int environmentRating;

  final int facilityRating;

  final int comfortRating;

  final String? content;

  final List<String> photos;

  final String? reply;

  final String? repliedAt;

  final int isDeleted;

  final String? createdAt;

  final String? updatedAt;

  final String? memberName;

  final String? memberPhone;

  final String? hotelName;

  final String? roomTypeName;

  @JsonKey(name: 'user_avatar')
  final String? userAvatar;

  Review({
    required this.id,
    this.orderId = 0,
    this.hotelId,
    this.roomTypeId,
    this.userId,
    this.memberId,
    this.score = 5.0,
    this.environmentRating = 5,
    this.facilityRating = 5,
    this.comfortRating = 5,
    this.content,
    this.photos = const [],
    this.reply,
    this.repliedAt,
    this.isDeleted = 0,
    this.createdAt,
    this.updatedAt,
    this.memberName,
    this.memberPhone,
    this.hotelName,
    this.roomTypeName,
    this.userAvatar,
  });

  String get displayUsername {
    if (memberName != null && memberName!.isNotEmpty) {
      if (memberName!.length > 2) {
        return '${memberName![0]}**${memberName![memberName!.length - 1]}';
      }
      return memberName!;
    }
    if (memberPhone != null && memberPhone!.isNotEmpty) {
      if (memberPhone!.length >= 7) {
        return '${memberPhone!.substring(0, 3)}****${memberPhone!.substring(7)}';
      }
      return memberPhone!;
    }
    return '匿名用户';
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);

    List<String> parsePhotos(dynamic val) {
      if (val is List) return List<String>.from(val);
      if (val is String && val.isNotEmpty) {
        try {
          if (val.startsWith('[')) {
            return List<String>.from(const JsonDecoder().convert(val));
          }
          return val.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        } catch (_) {
          return val.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      }
      return [];
    }

    double parseScore(dynamic value) {
      if (value == null) return 5.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 5.0;
      return 5.0;
    }

    int _parseInt(dynamic v, [int defaultValue = 5]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? defaultValue;
      return defaultValue;
    }

    return Review(
      id: normalized['id'] ?? 0,
      orderId: normalized['order_id'] ?? 0,
      hotelId: normalized['hotel_id'],
      roomTypeId: normalized['room_type_id'],
      userId: normalized['user_id'],
      memberId: normalized['member_id'],
      score: parseScore(normalized['score']),
      environmentRating: _parseInt(normalized['environment_rating']),
      facilityRating: _parseInt(normalized['facility_rating']),
      comfortRating: _parseInt(normalized['comfort_rating']),
      content: normalized['content'],
      photos: parsePhotos(normalized['photos']),
      reply: normalized['reply'],
      repliedAt: normalized['replied_at'],
      isDeleted: normalized['is_deleted'] ?? 0,
      createdAt: normalized['created_at'],
      updatedAt: normalized['updated_at'],
      memberName: normalized['member_name'],
      memberPhone: normalized['member_phone'],
      hotelName: normalized['hotel_name'],
      roomTypeName: normalized['room_type_name'],
      userAvatar: normalized['user_avatar'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'hotel_id': hotelId,
        'room_type_id': roomTypeId,
        'user_id': userId,
        'member_id': memberId,
        'score': score,
        'environment_rating': environmentRating,
        'facility_rating': facilityRating,
        'comfort_rating': comfortRating,
        'content': content,
        'photos': photos,
        'reply': reply,
        'replied_at': repliedAt,
        'is_deleted': isDeleted,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'member_name': memberName,
        'member_phone': memberPhone,
        'hotel_name': hotelName,
        'room_type_name': roomTypeName,
        'user_avatar': userAvatar,
      };
}
