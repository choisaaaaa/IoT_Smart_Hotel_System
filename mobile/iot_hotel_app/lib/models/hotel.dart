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
  });

  factory Hotel.fromJson(Map<String, dynamic> json) => Hotel(
        id: json['id'] ?? 0, hotelName: json['hotel_name'] ?? '', hotelAddress: json['hotel_address'],
        hotelPhone: json['hotel_phone'], hotelStar: json['hotel_star'], totalRooms: json['total_rooms'] ?? 0,
        occupiedRooms: json['occupied_rooms'] ?? 0, occupancyRate: (json['occupancy_rate'] ?? 0).toDouble(),
        logo: json['logo'], description: json['description'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'hotel_name': hotelName, 'hotel_address': hotelAddress,
    'hotel_phone': hotelPhone, 'hotel_star': hotelStar, 'total_rooms': totalRooms,
    'occupied_rooms': occupiedRooms, 'occupancy_rate': occupancyRate, 'logo': logo, 'description': description};
}
