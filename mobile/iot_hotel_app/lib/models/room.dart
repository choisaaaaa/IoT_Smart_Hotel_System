import 'package:json_annotation/json_annotation.dart';

class Room {
  final int id;
  @JsonKey(name: 'hotel_id')
  final int hotelId;
  @JsonKey(name: 'room_number')
  final String roomNumber;
  @JsonKey(name: 'room_type')
  final String roomType;
  @JsonKey(name: 'room_type_id')
  final int? roomTypeId;
  @JsonKey(name: 'room_name')
  final String? roomName;
  @JsonKey(name: 'room_price')
  final double roomPrice;
  @JsonKey(name: 'room_status')
  final String roomStatus;
  @JsonKey(name: 'floor')
  final int? floor;
  @JsonKey(name: 'area')
  final double? area;
  @JsonKey(name: 'bed_type')
  final String? bedType;
  @JsonKey(name: 'max_guests')
  final int maxGuests;
  @JsonKey(name: 'description')
  final String? description;
  @JsonKey(name: 'facilities')
  final dynamic facilities;
  @JsonKey(name: 'images')
  final dynamic images;
  @JsonKey(name: 'image_url')
  final String? imageUrl;

  Room({
    required this.id,
    this.hotelId = 1,
    required this.roomNumber,
    this.roomType = 'standard',
    this.roomTypeId,
    this.roomName,
    this.roomPrice = 0.0,
    this.roomStatus = 'available',
    this.floor,
    this.area,
    this.bedType,
    this.maxGuests = 1,
    this.description,
    this.facilities,
    this.images,
    this.imageUrl,
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

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: _toInt(json['id']) ?? 0,
        hotelId: _toInt(json['hotel_id']) ?? 1,
        roomNumber: json['room_number'] ?? '',
        roomType: json['room_type'] ?? 'standard',
        roomTypeId: _toInt(json['room_type_id']),
        roomName: json['room_name']?.toString(),
        roomPrice: _toDouble(json['room_price']),
        roomStatus: json['room_status'] ?? json['status'] ?? 'available',
        floor: _toInt(json['floor']),
        area: json['area'] != null ? _toDouble(json['area']) : null,
        bedType: json['bed_type']?.toString(),
        maxGuests: _toInt(json['max_guests']) ?? 1,
        description: json['description']?.toString(),
        facilities: json['facilities'],
        images: json['images'],
        imageUrl: json['image_url']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'hotel_id': hotelId, 'room_number': roomNumber, 'room_type': roomType,
        'room_type_id': roomTypeId, 'room_name': roomName, 'room_price': roomPrice,
        'room_status': roomStatus, 'floor': floor, 'area': area, 'bed_type': bedType,
        'max_guests': maxGuests, 'description': description, 'facilities': facilities,
        'images': images, 'image_url': imageUrl,
      };

  String get statusText {
    const map = {'available': '空闲', 'occupied': '已入住', 'cleaning': '清洁中', 'maintenance': '维修中', 'reserved': '已预订'};
    return map[roomStatus] ?? roomStatus;
  }
}
