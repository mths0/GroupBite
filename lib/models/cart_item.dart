// lib/models/cart_item.dart
import 'package:food_delivery_platform/models/menu_item.dart';

class CartItem {
  final String restaurantId;
  final MenuItem menuItem;
  final int quantity;

  const CartItem({
    required this.restaurantId,
    required this.menuItem,
    required this.quantity,
  });

  CartItem copyWith({
    String? restaurantId,
    MenuItem? menuItem,
    int? quantity,
  }) {
    return CartItem(
      restaurantId: restaurantId ?? this.restaurantId,
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
    );
  }

  double get lineTotal => menuItem.price * quantity;
}
