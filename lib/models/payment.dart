import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethod { creditCard, applePay, stcPay, cashOnDelivery }
enum PaymentStatus { pending, completed, failed, refunded }

class Payment {
  final String id;
  final String orderId;
  final String userId;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final DateTime timestamp;
  final String? errorMessage; // Helpful for debugging failed transactions

  Payment({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.amount,
    required this.method,
    required this.status,
    required this.timestamp,
    this.errorMessage,
  });

  // Convert Firestore Map to Payment Object
  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      method: PaymentMethod.values.firstWhere((e) => e.name == map['method']),
      status: PaymentStatus.values.firstWhere((e) => e.name == map['status']),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      errorMessage: map['errorMessage'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'userId': userId,
    'amount': amount,
    'method': method.name,
    'status': status.name,
    'timestamp': Timestamp.fromDate(timestamp),
    'errorMessage': errorMessage,
  };
}