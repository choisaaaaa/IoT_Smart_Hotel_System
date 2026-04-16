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

  @JsonKey(name: 'room_type')
  final String? roomType;

  @JsonKey(name: 'room_number')
  final String? roomNumber;

  @JsonKey(name: 'hotel_name')
  final String? hotelName;

  @JsonKey(name: 'coupon_id')
  final int? couponId;

  @JsonKey(name: 'used_points')
  final int? usedPoints;

  @JsonKey(name: 'payment_id')
  final int? paymentId;

  @JsonKey(name: 'room_name')
  final String? roomName;

  @JsonKey(name: 'has_review')
  final bool hasReview;

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
    this.roomType,
    this.roomNumber,
    this.hotelName,
    this.couponId,
    this.usedPoints,
    this.paymentId,
    this.roomName,
    this.hasReview = false,
  });

  String get statusText {
    const map = {
      'pending': '待付款',
      'confirmed': '已支付',
      'pre_checked_in': '待确认',
      'checked_in': '已入住',
      'checked_out': '已完成',
      'cancelled': '已取消',
    };
    return map[status] ?? status;
  }

  int get nights => checkOutDate.difference(checkInDate).inDays;

  String get displayRoomType => roomName ?? roomType ?? '标准间';

  String get displayBookingNumber =>
      bookingNumber ?? 'BK${id.toString().padLeft(6, '0')}';

  bool get canPay => status == 'pending';

  bool get canCheckin =>
      status == 'confirmed' || status == 'pre_checked_in';

  bool get canCancel =>
      status == 'pending' || status == 'confirmed';

  bool get canReview => status == 'checked_out' && !hasReview;

  bool get canEditReview => status == 'checked_out' && hasReview;

  bool get canExtend => status == 'checked_in';

  bool get canEnterRoom => status == 'checked_in';

  factory Booking.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);

    normalized['booking_number'] ??= normalized['booking_no'];
    normalized['check_in_date'] ??= normalized['check_in'];
    normalized['check_out_date'] ??= normalized['check_out'];
    normalized['room_type'] ??= normalized['room_name'];

    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return fallback;
        }
      }
      return fallback;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Booking(
      id: normalized['id'] ?? 0,
      bookingNumber: normalized['booking_number']?.toString(),
      userId: normalized['user_id'],
      guestName: normalized['guest_name'],
      guestPhone: normalized['guest_phone'],
      guestIdNumber: normalized['guest_id_number'],
      roomId: normalized['room_id'] ?? 0,
      hotelId: normalized['hotel_id'],
      checkInDate: parseDate(normalized['check_in_date'], DateTime.now()),
      checkOutDate: parseDate(
          normalized['check_out_date'], DateTime.now().add(const Duration(days: 1))),
      guestCount: normalized['guest_count'] ?? 1,
      specialRequests: normalized['special_requests'],
      paymentMethod: normalized['payment_method'],
      status: normalized['status'] ?? 'pending',
      totalPrice: parseDouble(normalized['total_price'] ?? normalized['total_amount'] ?? 0),
      createdAt: normalized['created_at'] != null
          ? parseDate(normalized['created_at'], DateTime.now())
          : null,
      roomType: normalized['room_type'],
      roomNumber: normalized['room_number'],
      hotelName: normalized['hotel_name'],
      couponId: normalized['coupon_id'],
      usedPoints: normalized['used_points'],
      paymentId: normalized['payment_id'],
      roomName: normalized['room_name'],
      hasReview: normalized['has_review'] == 1 || normalized['has_review'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_number': bookingNumber,
        'user_id': userId,
        'guest_name': guestName,
        'guest_phone': guestPhone,
        'guest_id_number': guestIdNumber,
        'room_id': roomId,
        'hotel_id': hotelId,
        'check_in_date': checkInDate.toIso8601String().split('T')[0],
        'check_out_date': checkOutDate.toIso8601String().split('T')[0],
        'guest_count': guestCount,
        'special_requests': specialRequests,
        'payment_method': paymentMethod,
        'status': status,
        'total_price': totalPrice,
        'created_at': createdAt?.toIso8601String(),
        'room_type': roomType,
        'room_number': roomNumber,
        'hotel_name': hotelName,
        'coupon_id': couponId,
        'used_points': usedPoints,
        'payment_id': paymentId,
        'room_name': roomName,
        'has_review': hasReview,
      };
}
