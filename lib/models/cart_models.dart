// lib/models/cart_models.dart
//
// Contains all data models used across the Cart and Checkout features.
// Designed to be Firebase-ready: each model includes a `toMap` and
// a named `fromMap` constructor for future Firestore serialization.

import 'package:food_delivery_platform/models/selected_option_choice.dart';

/// Represents a single item in the user's shopping cart.
class CartItem {
  final String id;
  final String name;

  /// A short descriptor shown below the name.
  final String description;

  /// Path or URL to the item image.
  final String imagePath;

  /// The price for ONE unit of this item.
  final double unitPrice;

  /// Selected customization choices.
  final List<SelectedOptionChoice> selectedOptions;

  /// Mutable quantity — updated via +/- buttons in the cart.
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.unitPrice,
    this.selectedOptions = const [],
    this.quantity = 1,
  });

  /// The total price for this line item (unitPrice × quantity).
  double get lineTotal => unitPrice * quantity;

  String get customizationSummary {
    if (selectedOptions.isEmpty) return '';

    return selectedOptions
        .map((option) => '${option.groupTitle}: ${option.choiceName}')
        .join(' • ');
  }

  // --- Firebase-ready serialization ---

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'imagePath': imagePath,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'selectedOptions': selectedOptions.map((e) => e.toJson()).toList(),
  };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    id: map['id'] as String,
    name: map['name'] as String,
    description: map['description'] as String,
    imagePath: map['imagePath'] as String,
    unitPrice: (map['unitPrice'] as num).toDouble(),
    quantity: (map['quantity'] as num).toInt(),
    selectedOptions: (map['selectedOptions'] as List<dynamic>? ?? [])
        .map(
          (e) => SelectedOptionChoice.fromMap(e as Map<String, dynamic>),
        )
        .toList(),
  );
}

// ---------------------------------------------------------------------------

/// Represents a saved delivery address belonging to the user.
class Address {
  final String id;

  /// Short human-readable label shown in bold (e.g., "Home", "Work").
  final String label;

  /// The full formatted address string.
  final String fullAddress;

  const Address({
    required this.id,
    required this.label,
    required this.fullAddress,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'fullAddress': fullAddress,
  };

  factory Address.fromMap(Map<String, dynamic> map) => Address(
    id: map['id'] as String,
    label: map['label'] as String,
    fullAddress: map['fullAddress'] as String,
  );
}

// ---------------------------------------------------------------------------

/// Represents a promotional discount coupon.
enum CouponDiscountType {
  percentage,
  fixed,
  freeDelivery,
}

class Coupon {
  final String code;
  final String label;
  final CouponDiscountType discountType;
  final double discountValue;

  const Coupon({
    required this.code,
    required this.label,
    required this.discountType,
    required this.discountValue,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'label': label,
    'discountType': discountType.name,
    'discountValue': discountValue,
  };

  factory Coupon.fromMap(Map<String, dynamic> map) {
    final raw = (map['discountType'] ?? 'percentage').toString();
    final type = switch (raw) {
      'fixed' => CouponDiscountType.fixed,
      'free_delivery' || 'freeDelivery' => CouponDiscountType.freeDelivery,
      _ => CouponDiscountType.percentage,
    };
    return Coupon(
      code: (map['code'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      discountType: type,
      discountValue: (map['discountValue'] as num).toDouble(),
    );
  }
}

// ---------------------------------------------------------------------------

/// Holds global checkout configuration fetched from the repository.
/// Keeps the UI free of any hardcoded business values.
class CheckoutData {
  /// Flat delivery fee applied to every order.
  final double deliveryFee;

  /// The current balance in the user's family/digital wallet.
  final double walletBalance;

  /// Tax rate as a fraction (e.g., 0.15 for 15%).
  final double taxRate;

  const CheckoutData({
    required this.deliveryFee,
    required this.walletBalance,
    required this.taxRate,
  });

  Map<String, dynamic> toMap() => {
    'deliveryFee': deliveryFee,
    'walletBalance': walletBalance,
    'taxRate': taxRate,
  };

  factory CheckoutData.fromMap(Map<String, dynamic> map) => CheckoutData(
    deliveryFee: (map['deliveryFee'] as num).toDouble(),
    walletBalance: (map['walletBalance'] as num).toDouble(),
    taxRate: (map['taxRate'] as num).toDouble(),
  );
}
