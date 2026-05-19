import 'package:flutter/foundation.dart';
import 'package:yjeek/cart/cart_state.dart';
import 'package:yjeek/models/cart_item.dart';
import 'package:yjeek/models/menu_item.dart';
import 'package:yjeek/models/selected_option_choice.dart';

class CartController extends ValueNotifier<CartState> {
  CartController() : super(CartState.empty());

  String _buildCartKey({
    required String menuItemId,
    required List<SelectedOptionChoice> selectedOptions,
  }) {
    if (selectedOptions.isEmpty) return menuItemId;

    final sorted = [...selectedOptions]
      ..sort((a, b) {
        final byGroup = a.groupId.compareTo(b.groupId);
        if (byGroup != 0) return byGroup;
        return a.choiceId.compareTo(b.choiceId);
      });

    final customizationKey = sorted
        .map((e) => '${e.groupId}:${e.choiceId}')
        .join('|');

    return '${menuItemId}__$customizationKey';
  }

  void addItem({
    required String restaurantId,
    required MenuItem item,
    required List<SelectedOptionChoice> selectedOptions,
    double? customUnitPrice,
  }) {
    final next = _deepCopy(value.cartsByRestaurant);
    final restaurantCart = next.putIfAbsent(restaurantId, () => {});

    final cartKey = _buildCartKey(
      menuItemId: item.id,
      selectedOptions: selectedOptions,
    );

    final existing = restaurantCart[cartKey];
    final unitPrice = customUnitPrice ?? item.price;

    if (existing == null) {
      restaurantCart[cartKey] = CartItem(
        restaurantId: restaurantId,
        menuItem: item,
        quantity: 1,
        selectedOptions: selectedOptions,
        customUnitPrice: unitPrice,
        cartKey: cartKey,
      );
    } else {
      restaurantCart[cartKey] = existing.copyWith(
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

  int quantityForMenuItem({
    required String restaurantId,
    required String menuItemId,
  }) {
    final cart = value.cartsByRestaurant[restaurantId];
    if (cart == null) return 0;
    return cart.values
        .where((e) => e.menuItem.id == menuItemId)
        .fold<int>(0, (sum, e) => sum + e.quantity);
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
