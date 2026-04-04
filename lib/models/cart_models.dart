// lib/models/cart_models.dart
//
// Contains all data models used across the Cart and Checkout features.
// Designed to be Firebase-ready: each model includes a `toMap` and
// a named `fromMap` constructor for future Firestore serialization.

/// Represents a single item in the user's shopping cart.
class CartItem {
  final String id;
  final String name;

  /// A short descriptor shown below the name (e.g., "Medium • Extra Cheese").
  final String description;

  /// Path to the local asset image (e.g., "assets/restaurant_assets/pizza.jpg").
  final String imagePath;

  /// The price for ONE unit of this item.
  final double unitPrice;

  /// Mutable quantity — updated via +/- buttons in the cart.
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.unitPrice,
    this.quantity = 1,
  });

  /// The total price for this line item (unitPrice × quantity).
  double get lineTotal => unitPrice * quantity;

  // --- Firebase-ready serialization ---

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'imagePath': imagePath,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        imagePath: map['imagePath'] as String,
        unitPrice: (map['unitPrice'] as num).toDouble(),
        quantity: (map['quantity'] as num).toInt(),
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
class Coupon {
  final String code;

  /// A value between 0.0 and 1.0 representing the discount fraction.
  /// e.g., 0.10 means 10% off.
  final double discountFraction;

  /// Human-readable label, e.g., "10% OFF".
  final String label;

  const Coupon({
    required this.code,
    required this.discountFraction,
    required this.label,
  });

  Map<String, dynamic> toMap() => {
        'code': code,
        'discountFraction': discountFraction,
        'label': label,
      };

  factory Coupon.fromMap(Map<String, dynamic> map) => Coupon(
        code: map['code'] as String,
        discountFraction: (map['discountFraction'] as num).toDouble(),
        label: map['label'] as String,
      );
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