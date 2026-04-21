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

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory RoomType.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['code'] ??= normalized['type_code'] ?? normalized['room_type'] ?? '';
    normalized['name'] ??= normalized['type_name'] ?? normalized['room_name'] ?? '';
    normalized['base_price'] ??= normalized['price'] ?? normalized['room_price'] ?? 0;
    normalized['id'] ??= normalized['room_type_id'];
    normalized['bed_type'] ??= normalized['bedType'];
    normalized['max_guests'] ??= normalized['maxGuests'];
    normalized['available_count'] ??= normalized['availableCount'];
    normalized['total_count'] ??= normalized['physicalRooms'] ?? normalized['totalCount'];

    List<String>? parseList(dynamic val) {
      if (val is List) return List<String>.from(val);
      if (val is String && val.isNotEmpty) {
        return val.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      return null;
    }

    double? bestPrice;
    if (normalized.containsKey('plans') && normalized['plans'] is List) {
      final plans = normalized['plans'] as List;
      if (plans.isNotEmpty) {
        final prices = plans
            .where((p) => p is Map && p['price'] != null)
            .map((p) => (p as Map)['price'] as num)
            .toList();
        if (prices.isNotEmpty) {
          bestPrice = prices.reduce((a, b) => a < b ? a : b).toDouble();
        }
      }
    }
    if (bestPrice != null) {
      normalized['base_price'] = bestPrice;
    }

    return RoomType(
      id: _toInt(normalized['id']) ?? 0,
      code: normalized['code']?.toString() ?? '',
      name: normalized['name']?.toString() ?? '',
      basePrice: _toDouble(normalized['base_price']),
      maxGuests: _toInt(normalized['max_guests']) ?? 1,
      bedType: normalized['bed_type']?.toString(),
      area: normalized['area'] != null ? _toDouble(normalized['area']) : null,
      description: normalized['description']?.toString(),
      facilities: parseList(normalized['facilities']),
      images: parseList(normalized['images']),
      hotelId: _toInt(normalized['hotel_id']),
      totalCount: _toInt(normalized['total_count']),
      availableCount: _toInt(normalized['available_count']),
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
