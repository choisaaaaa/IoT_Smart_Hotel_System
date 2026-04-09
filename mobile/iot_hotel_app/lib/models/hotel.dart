import 'package:json_annotation/json_annotation.dart';

class Hotel {
  final int id;
  @JsonKey(name: 'hotel_name')
  final String hotelName;
  @JsonKey(name: 'hotel_address')
  final String? hotelAddress;
  @JsonKey(name: 'hotel_phone')
  final String? hotelPhone;
  @JsonKey(name: 'hotel_star')
  final int? hotelStar;
  @JsonKey(name: 'total_rooms')
  final int totalRooms;
  @JsonKey(name: 'occupied_rooms')
  final int occupiedRooms;
  @JsonKey(name: 'occupancy_rate')
  final double occupancyRate;
  final String? logo;
  final String? description;
  @JsonKey(name: 'city')
  final String? city;
  @JsonKey(name: 'location')
  final String? location;
  @JsonKey(name: 'star_rating')
  final int? starRating;
  @JsonKey(name: 'rating')
  final double? rating;
  @JsonKey(name: 'review_count')
  final int? reviewCount;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'promotion')
  final String? promotion;

  Hotel({
    required this.id,
    required this.hotelName,
    this.hotelAddress,
    this.hotelPhone,
    this.hotelStar,
    this.totalRooms = 0,
    this.occupiedRooms = 0,
    this.occupancyRate = 0.0,
    this.logo,
    this.description,
    this.city,
    this.location,
    this.starRating,
    this.rating,
    this.reviewCount,
    this.imageUrl,
    this.promotion,
  });

  factory Hotel.fromJson(Map<String, dynamic> json) => Hotel(
        id: json['id'] ?? 0,
        hotelName: json['hotel_name'] ?? json['name'] ?? '',
        hotelAddress: json['hotel_address'],
        hotelPhone: json['hotel_phone'],
        hotelStar: json['hotel_star'],
        totalRooms: json['total_rooms'] ?? 0,
        occupiedRooms: json['occupied_rooms'] ?? 0,
        occupancyRate: (json['occupancy_rate'] ?? 0).toDouble(),
        logo: json['logo'],
        description: json['description'],
        city: json['city'],
        location: json['location'],
        starRating: json['star_rating'],
        rating: json['rating'] != null ? (json['rating']).toDouble() : null,
        reviewCount: json['review_count'],
        imageUrl: json['image_url'],
        promotion: json['promotion'],
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'hotel_name': hotelName, 'hotel_address': hotelAddress,
        'hotel_phone': hotelPhone, 'hotel_star': hotelStar, 'total_rooms': totalRooms,
        'occupied_rooms': occupiedRooms, 'occupancy_rate': occupancyRate, 'logo': logo,
        'description': description, 'city': city, 'location': location,
        'star_rating': starRating, 'rating': rating, 'review_count': reviewCount,
        'image_url': imageUrl, 'promotion': promotion,
      };
}
