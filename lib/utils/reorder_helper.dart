import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/pages/customer/cart_screen.dart';

Future<void> reorderPastOrder({
  required BuildContext context,
  required Order order,
}) async {
  final cart = CartScope.of(context);
  cart.clearRestaurantCart(order.restaurantId);

  final menu = await DatabaseService().getMenuForRestaurant(
    restaurantId: order.restaurantId,
  );

  for (final item in order.items) {
    if (!menu.any((m) => m.id == item.menuId)) continue;
    final menuItem = menu.firstWhere((m) => m.id == item.menuId);
    for (int i = 0; i < item.quantity; i++) {
      cart.addItem(
        restaurantId: order.restaurantId,
        item: menuItem,
        selectedOptions: const [],
        customUnitPrice: menuItem.price,
      );
    }
  }

  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CartScope(
        notifier: cart,
        child: CartScreen(
          restaurantId: order.restaurantId,
          customerId: order.customerId,
        ),
      ),
    ),
  );
}
