// lib/cart/cart_state.dart
import 'package:food_delivery_platform/models/cart_item.dart';

class CartState {
  // restaurantId -> menuItemId -> CartItem
  final Map<String, Map<String, CartItem>> cartsByRestaurant;

  const CartState({required this.cartsByRestaurant});

  factory CartState.empty() => const CartState(cartsByRestaurant: {});

  CartState copyWith({
    Map<String, Map<String, CartItem>>? cartsByRestaurant,
  }) {
    return CartState(
      cartsByRestaurant: cartsByRestaurant ?? this.cartsByRestaurant,
    );
  }
}
