import 'dart:math';
import 'package:food_delivery_platform/models/abstract_user.dart';

class IdGenerator {
  static String generateUserId(UserRole role) {
    final random = Random().nextInt(900) + 100; // 3 digits
    final time = DateTime.now().millisecondsSinceEpoch % 1000000;
    final prefix = role.name; // customer, driver, restaurant

    return '${prefix}_$time$random';
  }
  static String generateOrderId() {
    final random = Random().nextInt(900) + 100; // 3 digits
    final time = DateTime.now().millisecondsSinceEpoch % 1000000;

    return 'order_$time$random';
  }
  static String generatePaymentId() {
    final random = Random().nextInt(900) + 100; // 3 digits
    final time = DateTime.now().millisecondsSinceEpoch % 1000000;

    return 'payment_$time$random';
  }

  static String generateCardId() {
    final random = Random().nextInt(900) + 100;
    final time = DateTime.now().millisecondsSinceEpoch % 1000000;

    return 'card_$time$random';
  }
}
