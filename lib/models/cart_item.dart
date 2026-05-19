// lib/models/cart_item.dart
import 'package:yjeek/models/menu_item.dart';
import 'package:yjeek/models/selected_option_choice.dart';

class CartItem {
  final String restaurantId;
  final MenuItem menuItem;
  final int quantity;

  final List<SelectedOptionChoice> selectedOptions;
  final double customUnitPrice;
  final String cartKey;

  const CartItem({
    required this.restaurantId,
    required this.menuItem,
    required this.quantity,
    this.selectedOptions = const [],
    required this.customUnitPrice,
    required this.cartKey,
  });

  CartItem copyWith({
    String? restaurantId,
    MenuItem? menuItem,
    int? quantity,
    List<SelectedOptionChoice>? selectedOptions,
    double? customUnitPrice,
    String? cartKey,
  }) {
    return CartItem(
      restaurantId: restaurantId ?? this.restaurantId,
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      customUnitPrice: customUnitPrice ?? this.customUnitPrice,
      cartKey: cartKey ?? this.cartKey,
    );
  }

  double get unitPrice => customUnitPrice;

  double get lineTotal => unitPrice * quantity;

  String get customizationSummary {
    if (selectedOptions.isEmpty) return '';

    return selectedOptions
        .map((option) => '${option.groupTitle}: ${option.choiceName}')
        .join(' • ');
  }
}
