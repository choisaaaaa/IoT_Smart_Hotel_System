import 'package:json_annotation/json_annotation.dart';

class Booking {
  final int id;
  @JsonKey(name: 'guest_name')
  final String? guestName;
  @JsonKey(name: 'guest_phone')
  final String? guestPhone;
  @JsonKey(name: 'guest_id')
  final int? guestId;
  @JsonKey(name: 'room_id')
  final int roomId;
  @JsonKey(name: 'check_in_date')
  final DateTime checkInDate;
  @JsonKey(name: 'check_out_date')
  final DateTime checkOutDate;
  @JsonKey(name: 'status')
  final String status;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  Booking({
    required this.id,
    this.guestName,
    this.guestPhone,
    this.guestId,
    required this.roomId,
    required this.checkInDate,
    required this.checkOutDate,
    this.status = 'pending',
    this.totalAmount = 0.0,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] ?? 0, guestName: json['guest_name'], guestPhone: json['guest_phone'],
        guestId: json['guest_id'], roomId: json['room_id'] ?? 0,
        checkInDate: DateTime.parse(json['check_in_date']), checkOutDate: DateTime.parse(json['check_out_date']),
        status: json['status'] ?? 'pending', totalAmount: (json['total_amount'] ?? 0).toDouble(),
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      );

  Map<String, dynamic> toJson() => {'id': id, 'guest_name': guestName, 'guest_phone': guestPhone,
    'guest_id': guestId, 'room_id': roomId, 'check_in_date': checkInDate.toIso8601String(),
    'check_out_date': checkOutDate.toIso8601String(), 'status': status, 'total_amount': totalAmount,
    'created_at': createdAt?.toIso8601String()};

  String get statusText {
    const map = {'pending': '待确认', 'confirmed': '已确认', 'checked_in': '已入住', 'checked_out': '已退房', 'cancelled': '已取消'};
    return map[status] ?? status;
  }

  int get nights { return checkOutDate.difference(checkInDate).inDays; }
}
