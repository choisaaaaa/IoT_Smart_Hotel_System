import 'package:json_annotation/json_annotation.dart';

class Booking {
  final int id;
  @JsonKey(name: 'booking_number')
  final String? bookingNumber;
  @JsonKey(name: 'user_id')
  final int? userId;
  @JsonKey(name: 'guest_name')
  final String? guestName;
  @JsonKey(name: 'guest_phone')
  final String? guestPhone;
  @JsonKey(name: 'guest_id_number')
  final String? guestIdNumber;
  @JsonKey(name: 'room_id')
  final int roomId;
  @JsonKey(name: 'hotel_id')
  final int? hotelId;
  @JsonKey(name: 'check_in_date')
  final DateTime checkInDate;
  @JsonKey(name: 'check_out_date')
  final DateTime checkOutDate;
  @JsonKey(name: 'guest_count')
  final int guestCount;
  @JsonKey(name: 'special_requests')
  final String? specialRequests;
  @JsonKey(name: 'payment_method')
  final String? paymentMethod;
  @JsonKey(name: 'total_price')
  final double totalPrice;
  @JsonKey(name: 'status')
  final String status;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  Booking({
    required this.id,
    this.bookingNumber,
    this.userId,
    this.guestName,
    this.guestPhone,
    this.guestIdNumber,
    required this.roomId,
    this.hotelId,
    required this.checkInDate,
    required this.checkOutDate,
    this.guestCount = 1,
    this.specialRequests,
    this.paymentMethod,
    this.status = 'pending',
    this.totalPrice = 0.0,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] ?? 0,
        bookingNumber: json['booking_number'],
        userId: json['user_id'],
        guestName: json['guest_name'],
        guestPhone: json['guest_phone'],
        guestIdNumber: json['guest_id_number'],
        roomId: json['room_id'] ?? 0,
        hotelId: json['hotel_id'],
        checkInDate: DateTime.parse(json['check_in_date']),
        checkOutDate: DateTime.parse(json['check_out_date']),
        guestCount: json['guest_count'] ?? 1,
        specialRequests: json['special_requests'],
        paymentMethod: json['payment_method'],
        status: json['status'] ?? 'pending',
        totalPrice: (json['total_price'] ?? 0).toDouble(),
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'booking_number': bookingNumber, 'user_id': userId,
        'guest_name': guestName, 'guest_phone': guestPhone, 'guest_id_number': guestIdNumber,
        'room_id': roomId, 'hotel_id': hotelId, 'check_in_date': checkInDate.toIso8601String().split('T')[0],
        'check_out_date': checkOutDate.toIso8601String().split('T')[0],
        'guest_count': guestCount, 'special_requests': specialRequests,
        'payment_method': paymentMethod, 'status': status, 'total_price': totalPrice,
        'created_at': createdAt?.toIso8601String()};

  String get statusText {
    const map = {'pending': '待确认', 'confirmed': '已确认', 'checked_in': '已入住', 'checked_out': '已退房', 'cancelled': '已取消'};
    return map[status] ?? status;
  }

  int get nights => checkOutDate.difference(checkInDate).inDays;
}
