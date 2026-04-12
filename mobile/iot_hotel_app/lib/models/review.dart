import 'package:json_annotation/json_annotation.dart';

class Review {
  final int id;

  @JsonKey(name: 'user_id')
  final int userId;

  @JsonKey(name: 'hotel_id')
  final int hotelId;

  @JsonKey(name: 'booking_id')
  final int? bookingId;

  @JsonKey(name: 'rating')
  final double rating;

  @JsonKey(name: 'cleanliness_rating')
  final double? cleanlinessRating;

  @JsonKey(name: 'service_rating')
  final double? serviceRating;

  @JsonKey(name: 'location_rating')
  final double? locationRating;

  @JsonKey(name: 'value_rating')
  final double? valueRating;

  @JsonKey(name: 'content')
  final String? content;

  @JsonKey(name: 'images')
  final List<String>? images;

  @JsonKey(name: 'reply')
  final String? reply;

  @JsonKey(name: 'username')
  final String? username;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.hotelId,
    this.bookingId,
    this.rating = 5.0,
    this.cleanlinessRating,
    this.serviceRating,
    this.locationRating,
    this.valueRating,
    this.content,
    this.images,
    this.reply,
    this.username,
    this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);

    List<String>? parseImages(dynamic val) {
      if (val is List) return List<String>.from(val);
      if (val is String && val.isNotEmpty) {
        return val.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      return null;
    }

    return Review(
      id: normalized['id'] ?? 0,
      userId: normalized['user_id'] ?? 0,
      hotelId: normalized['hotel_id'] ?? 0,
      bookingId: normalized['booking_id'],
      rating: (normalized['rating'] ?? 5.0).toDouble(),
      cleanlinessRating: normalized['cleanliness_rating'] != null
          ? (normalized['cleanliness_rating']).toDouble()
          : null,
      serviceRating: normalized['service_rating'] != null
          ? (normalized['service_rating']).toDouble()
          : null,
      locationRating: normalized['location_rating'] != null
          ? (normalized['location_rating']).toDouble()
          : null,
      valueRating: normalized['value_rating'] != null
          ? (normalized['value_rating']).toDouble()
          : null,
      content: normalized['content'] ?? normalized['comment'],
      images: parseImages(normalized['images']),
      reply: normalized['reply'] ?? normalized['hotel_reply'],
      username: normalized['username'] ?? normalized['user_name'],
      createdAt: normalized['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'hotel_id': hotelId,
        'booking_id': bookingId,
        'rating': rating,
        'cleanliness_rating': cleanlinessRating,
        'service_rating': serviceRating,
        'location_rating': locationRating,
        'value_rating': valueRating,
        'content': content,
        'images': images,
        'reply': reply,
        'username': username,
        'created_at': createdAt,
      };
}
