import 'package:json_annotation/json_annotation.dart';

class RoomType {
  final int id;

  @JsonKey(name: 'code')
  final String code;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'base_price')
  final double basePrice;

  @JsonKey(name: 'max_guests')
  final int maxGuests;

  @JsonKey(name: 'bed_type')
  final String? bedType;

  @JsonKey(name: 'area')
  final double? area;

  @JsonKey(name: 'description')
  final String? description;

  @JsonKey(name: 'facilities')
  final List<String>? facilities;

  @JsonKey(name: 'images')
  final List<String>? images;

  @JsonKey(name: 'hotel_id')
  final int? hotelId;

  @JsonKey(name: 'total_count')
  final int? totalCount;

  @JsonKey(name: 'available_count')
  final int? availableCount;

  RoomType({
    required this.id,
    required this.code,
    required this.name,
    this.basePrice = 0.0,
    this.maxGuests = 1,
    this.bedType,
    this.area,
    this.description,
    this.facilities,
    this.images,
    this.hotelId,
    this.totalCount,
    this.availableCount,
  });

  factory RoomType.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['code'] ??= normalized['type_code'] ?? normalized['room_type'] ?? '';
    normalized['name'] ??= normalized['type_name'] ?? normalized['room_name'] ?? '';
    normalized['base_price'] ??= normalized['price'] ?? normalized['room_price'] ?? 0;

    List<String>? parseList(dynamic val) {
      if (val is List) return List<String>.from(val);
      if (val is String && val.isNotEmpty) {
        return val.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      return null;
    }

    return RoomType(
      id: normalized['id'] ?? 0,
      code: normalized['code'] ?? '',
      name: normalized['name'] ?? '',
      basePrice: (normalized['base_price'] ?? 0).toDouble(),
      maxGuests: normalized['max_guests'] ?? 1,
      bedType: normalized['bed_type'],
      area: normalized['area'] != null ? (normalized['area']).toDouble() : null,
      description: normalized['description'],
      facilities: parseList(normalized['facilities']),
      images: parseList(normalized['images']),
      hotelId: normalized['hotel_id'],
      totalCount: normalized['total_count'],
      availableCount: normalized['available_count'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'base_price': basePrice,
        'max_guests': maxGuests,
        'bed_type': bedType,
        'area': area,
        'description': description,
        'facilities': facilities,
        'images': images,
        'hotel_id': hotelId,
        'total_count': totalCount,
        'available_count': availableCount,
      };
}
