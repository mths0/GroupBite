// lib/cart/cart_scope.dart
import 'package:flutter/widgets.dart';
import 'package:food_delivery_platform/cart/cart_controller.dart';

class CartScope extends InheritedNotifier<CartController> {
  const CartScope({
    super.key,
    required CartController notifier,
    required super.child,
  }) : super(notifier: notifier);

  static CartController of(BuildContext context) {
  final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
  if (scope == null) {
    throw FlutterError('CartScope not found in widget tree');
  }
  return scope.notifier!;
}
}
