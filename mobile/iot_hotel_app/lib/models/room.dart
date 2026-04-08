import 'package:json_annotation/json_annotation.dart';

class Room {
  final int id;
  @JsonKey(name: 'room_number')
  final String roomNumber;
  @JsonKey(name: 'room_type')
  final String roomType;
  @JsonKey(name: 'floor')
  final int floor;
  @JsonKey(name: 'status')
  final String status;
  @JsonKey(name: 'price_per_night')
  final double pricePerNight;
  @JsonKey(name: 'max_guests')
  final int maxGuests;
  @JsonKey(name: 'hotel_id')
  final int hotelId;

  Room({
    required this.id,
    required this.roomNumber,
    this.roomType = '标准间',
    this.floor = 1,
    this.status = 'available',
    this.pricePerNight = 0.0,
    this.maxGuests = 2,
    this.hotelId = 1,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] ?? 0, roomNumber: json['room_number'] ?? '', roomType: json['room_type'] ?? '标准间',
        floor: json['floor'] ?? 1, status: json['status'] ?? 'available',
        pricePerNight: (json['price_per_night'] ?? 0).toDouble(), maxGuests: json['max_guests'] ?? 2,
        hotelId: json['hotel_id'] ?? 1,
      );

  Map<String, dynamic> toJson() => {'id': id, 'room_number': roomNumber, 'room_type': roomType,
    'floor': floor, 'status': status, 'price_per_night': pricePerNight, 'max_guests': maxGuests, 'hotel_id': hotelId};

  String get statusText {
    const map = {'available': '空闲', 'occupied': '已入住', 'cleaning': '清洁中', 'maintenance': '维修中', 'reserved': '已预订'};
    return map[status] ?? status;
  }
}
