import 'package:json_annotation/json_annotation.dart';

class Payment {
  final int id;

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
    required this.orderType,
    required this.orderId,
    required this.amount,
    this.paymentMethod = 'balance',
    this.status = 'pending',
    this.transactionNo,
    this.createdAt,
    this.paidAt,
  });

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
      id: normalized['id'] ?? 0,
      orderType: normalized['order_type'] ?? 'booking',
      orderId: normalized['order_id'] ?? 0,
      amount: (normalized['amount'] ?? 0).toDouble(),
      paymentMethod: normalized['payment_method'] ?? 'balance',
      status: normalized['status'] ?? 'pending',
      transactionNo: normalized['transaction_no'],
      createdAt: normalized['created_at'],
      paidAt: normalized['paid_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
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
