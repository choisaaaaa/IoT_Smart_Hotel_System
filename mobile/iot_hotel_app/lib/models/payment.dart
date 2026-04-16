import 'package:json_annotation/json_annotation.dart';

class Payment {
  final int id;

  @JsonKey(name: 'payment_no')
  final String? paymentNo;

  @JsonKey(name: 'order_type')
  final String orderType;

  @JsonKey(name: 'order_id')
  final int orderId;

  @JsonKey(name: 'amount')
  final double amount;

  @JsonKey(name: 'payment_method')
  final String paymentMethod;

  @JsonKey(name: 'status')
  final String status;

  @JsonKey(name: 'transaction_no')
  final String? transactionNo;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'paid_at')
  final String? paidAt;

  Payment({
    required this.id,
    this.paymentNo,
    required this.orderType,
    required this.orderId,
    required this.amount,
    this.paymentMethod = 'balance',
    this.status = 'pending',
    this.transactionNo,
    this.createdAt,
    this.paidAt,
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

  bool get isPaid => status == 'paid' || status == 'completed';

  String get statusText {
    switch (status) {
      case 'pending': return '待支付';
      case 'paid': return '已支付';
      case 'completed': return '已完成';
      case 'failed': return '支付失败';
      case 'refunded': return '已退款';
      default: return '未知';
    }
  }

  String get paymentMethodText {
    switch (paymentMethod) {
      case 'balance': return '余额支付';
      case 'wechat': return '微信支付';
      case 'alipay': return '支付宝';
      default: return paymentMethod;
    }
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    return Payment(
      id: _toInt(normalized['id']) ?? 0,
      paymentNo: normalized['payment_no']?.toString(),
      orderType: normalized['order_type']?.toString() ?? 'booking',
      orderId: _toInt(normalized['order_id']) ?? 0,
      amount: _toDouble(normalized['amount'] ?? 0),
      paymentMethod: normalized['payment_method']?.toString() ?? 'balance',
      status: normalized['status']?.toString() ?? 'pending',
      transactionNo: normalized['transaction_no']?.toString(),
      createdAt: normalized['created_at']?.toString(),
      paidAt: normalized['paid_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'payment_no': paymentNo,
        'order_type': orderType,
        'order_id': orderId,
        'amount': amount,
        'payment_method': paymentMethod,
        'status': status,
        'transaction_no': transactionNo,
        'created_at': createdAt,
        'paid_at': paidAt,
      };
}
