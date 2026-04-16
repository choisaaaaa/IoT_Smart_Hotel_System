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
  final int hotelStar;

  @JsonKey(name: 'total_rooms')
  final int totalRooms;

  @JsonKey(name: 'occupied_rooms')
  final int occupiedRooms;

  @JsonKey(name: 'occupancy_rate')
  final double occupancyRate;

  final String? logo;
  final String? description;
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

  @JsonKey(name: 'hotel_code')
  final String? hotelCode;

  final List<String>? images;
  final List<String>? facilities;
  final double? price;
  final int? availableRooms;

  Hotel({
    required this.id,
    required this.hotelName,
    this.hotelAddress,
    this.hotelPhone,
    this.hotelStar = 3,
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
    this.hotelCode,
    this.images,
    this.facilities,
    this.price,
    this.availableRooms,
  });

  String get displayAddress => hotelAddress ?? location ?? city ?? '暂无地址';

  String get displayImage {
    if (logo != null && logo!.isNotEmpty) return logo!;
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl!;
    if (images != null && images!.isNotEmpty) return images!.first;
    return '';
  }

  int get effectiveStar => hotelStar > 0 ? hotelStar : (starRating ?? 3);

  double get effectiveRating => rating ?? 4.5;

  factory Hotel.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);

    normalized['hotel_name'] ??= normalized['name'];
    normalized['hotel_address'] ??= normalized['address'] ?? normalized['location'];
    normalized['hotel_star'] ??= normalized['star'] ?? normalized['star_rating'] ?? 3;
    normalized['logo'] ??= normalized['image'] ?? normalized['image_url'];

    if (normalized['images'] is String) {
      try {
        normalized['images'] = List<String>.from(
          (normalized['images'] as String).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      } catch (_) {
        normalized['images'] = <String>[];
      }
    } else if (normalized['images'] is List) {
      normalized['images'] = List<String>.from(normalized['images']);
    }

    if (normalized['facilities'] is String) {
      try {
        normalized['facilities'] = List<String>.from(
          (normalized['facilities'] as String).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      } catch (_) {
        normalized['facilities'] = <String>[];
      }
    } else if (normalized['facilities'] is List) {
      normalized['facilities'] = List<String>.from(normalized['facilities']);
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Hotel(
      id: normalized['id'] ?? 0,
      hotelName: normalized['hotel_name'] ?? '',
      hotelAddress: normalized['hotel_address'],
      hotelPhone: normalized['hotel_phone'],
      hotelStar: normalized['hotel_star'] ?? 3,
      totalRooms: normalized['total_rooms'] ?? 0,
      occupiedRooms: normalized['occupied_rooms'] ?? 0,
      occupancyRate: parseDouble(normalized['occupancy_rate'] ?? 0),
      logo: normalized['logo'],
      description: normalized['description'],
      city: normalized['city'],
      location: normalized['location'],
      starRating: normalized['star_rating'],
      rating: normalized['rating'] != null ? parseDouble(normalized['rating']) : null,
      reviewCount: normalized['review_count'],
      imageUrl: normalized['image_url'],
      hotelCode: normalized['hotel_code'],
      images: normalized['images'],
      facilities: normalized['facilities'],
      price: normalized['price'] != null ? parseDouble(normalized['price']) : null,
      availableRooms: normalized['available_rooms'] ?? normalized['availableRooms'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hotel_name': hotelName,
        'hotel_address': hotelAddress,
        'hotel_phone': hotelPhone,
        'hotel_star': hotelStar,
        'total_rooms': totalRooms,
        'occupied_rooms': occupiedRooms,
        'occupancy_rate': occupancyRate,
        'logo': logo,
        'description': description,
        'city': city,
        'location': location,
        'star_rating': starRating,
        'rating': rating,
        'review_count': reviewCount,
        'image_url': imageUrl,
        'hotel_code': hotelCode,
        'images': images,
        'facilities': facilities,
        'price': price,
      };
}
