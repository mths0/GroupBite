import 'dart:async';
import 'dart:math';
import 'package:food_delivery_platform/models/payment.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';

class MockPaymentService {
  // Simulate the actual "Charge" process
  Future<Payment> processMockPayment({
    required String userId,
    required String orderId,
    required double amount,
    required PaymentMethod method,
  }) async {
    // 1. Simulate network latency (The "Processing..." spinner time)
    await Future.delayed(const Duration(seconds: 3));

    // 2. Simulate a random result (90% success, 10% failure)
    final bool isSuccessful = Random().nextDouble() < 0.9;

    if (isSuccessful) {
      return Payment(
        id: IdGenerator.generatePaymentId(),
        orderId: orderId,
        userId: userId,
        amount: amount,
        method: method,
        status: PaymentStatus.completed,
        timestamp: DateTime.now(),
      );
    } else {
      return Payment(
        id: 'PAY_FAILED',
        orderId: orderId,
        userId: userId,
        amount: amount,
        method: method,
        status: PaymentStatus.failed,
        timestamp: DateTime.now(),
        errorMessage: "The bank declined the transaction. Please try again.",
      );
    }
  }
}