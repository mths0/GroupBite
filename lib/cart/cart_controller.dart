// lib/cart/cart_controller.dart
import 'package:flutter/foundation.dart';
import 'package:food_delivery_platform/cart/cart_state.dart';
import 'package:food_delivery_platform/models/cart_item.dart';
import 'package:food_delivery_platform/models/menu_item.dart';

class CartController extends ValueNotifier<CartState> {
  CartController() : super(CartState.empty());

  void addItem({
    required String restaurantId,
    required MenuItem item,
  }) {
    final next = _deepCopy(value.cartsByRestaurant);
    final restaurantCart = next.putIfAbsent(restaurantId, () => {});

    final existing = restaurantCart[item.id];
    if (existing == null) {
      restaurantCart[item.id] = CartItem(
        restaurantId: restaurantId,
        menuItem: item,
        quantity: 1,
      );
    } else {
      restaurantCart[item.id] = existing.copyWith(
        quantity: existing.quantity + 1,
      );
    }

    value = value.copyWith(cartsByRestaurant: next);
  }

  void decreaseItem({
    required String restaurantId,
    required String menuItemId,
  }) {
    final next = _deepCopy(value.cartsByRestaurant);
    final restaurantCart = next[restaurantId];
    if (restaurantCart == null) return;

    final existing = restaurantCart[menuItemId];
    if (existing == null) return;

    if (existing.quantity <= 1) {
      restaurantCart.remove(menuItemId);
    } else {
      restaurantCart[menuItemId] = existing.copyWith(
        quantity: existing.quantity - 1,
      );
    }

    if (restaurantCart.isEmpty) next.remove(restaurantId);
    value = value.copyWith(cartsByRestaurant: next);
  }

  void removeItem({
    required String restaurantId,
    required String menuItemId,
  }) {
    final next = _deepCopy(value.cartsByRestaurant);
    final restaurantCart = next[restaurantId];
    if (restaurantCart == null) return;

    restaurantCart.remove(menuItemId);
    if (restaurantCart.isEmpty) next.remove(restaurantId);

    value = value.copyWith(cartsByRestaurant: next);
  }

  void clearRestaurantCart(String restaurantId) {
    final next = _deepCopy(value.cartsByRestaurant);
    next.remove(restaurantId);
    value = value.copyWith(cartsByRestaurant: next);
  }

  void clearAll() {
    value = CartState.empty();
  }

  List<CartItem> itemsForRestaurant(String restaurantId) {
    final cart = value.cartsByRestaurant[restaurantId];
    if (cart == null) return const [];
    return cart.values.toList();
  }

  int itemCount(String restaurantId) {
    final items = itemsForRestaurant(restaurantId);
    return items.fold(0, (sum, e) => sum + e.quantity);
  }

  double subtotal(String restaurantId) {
    final items = itemsForRestaurant(restaurantId);
    return items.fold(0.0, (sum, e) => sum + e.lineTotal);
  }

  double subtotalForRestaurant(String restaurantId) {
    return subtotal(restaurantId);
  }

  int totalItemCount() {
    var total = 0;
    for (final restaurantCart in value.cartsByRestaurant.values) {
      for (final item in restaurantCart.values) {
        total += item.quantity;
      }
    }
    return total;
  }

  double grandTotal() {
    var total = 0.0;
    for (final restaurantId in value.cartsByRestaurant.keys) {
      total += subtotal(restaurantId);
    }
    return total;
  }

  Map<String, List<CartItem>> groupedItems() {
    final grouped = <String, List<CartItem>>{};
    for (final entry in value.cartsByRestaurant.entries) {
      grouped[entry.key] = entry.value.values.toList();
    }
    return grouped;
  }

  Map<String, Map<String, CartItem>> carts() {
    return _deepCopy(value.cartsByRestaurant);
  }

  bool hasAnyItems() {
    return value.cartsByRestaurant.isNotEmpty;
  }

  void removeLine({
    required String restaurantId,
    required String menuItemId,
  }) {
    removeItem(
      restaurantId: restaurantId,
      menuItemId: menuItemId,
    );
  }

  Map<String, Map<String, CartItem>> _deepCopy(
    Map<String, Map<String, CartItem>> source,
  ) {
    final result = <String, Map<String, CartItem>>{};
    for (final entry in source.entries) {
      result[entry.key] = Map<String, CartItem>.from(entry.value);
    }
    return result;
  }
}
