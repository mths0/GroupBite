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

  /// Like [of] but does NOT subscribe the calling widget to changes.
  /// Use when you only need to call methods on the cart (e.g. `addItem`)
  /// from a build that shouldn't rebuild on every cart update.
  static CartController read(BuildContext context) {
    final scope = context.findAncestorWidgetOfExactType<CartScope>();
    if (scope == null) {
      throw FlutterError('CartScope not found in widget tree');
    }
    return scope.notifier!;
  }
}
