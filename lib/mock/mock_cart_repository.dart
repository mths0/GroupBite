// lib/mock/mock_cart_repository.dart
//
// A mock data source that simulates async network/Firestore calls using
// Future.delayed. When connecting to Firebase, replace the body of each
// method with real Firestore queries — the method signatures stay identical,
// so the UI code requires zero changes.

import 'package:food_delivery_platform/models/cart_models.dart';
import 'package:food_delivery_platform/utils/tax.dart';

class MockCartRepository {
  // ---------------------------------------------------------------------------
  // Cart Items
  // ---------------------------------------------------------------------------

  /// Returns the user's current cart contents.
  ///
  /// Firebase equivalent:
  ///   final snapshot = await FirebaseFirestore.instance
  ///       .collection('carts')
  ///       .doc(userId)
  ///       .collection('items')
  ///       .get();
  ///   return snapshot.docs.map((d) => CartItem.fromMap(d.data())).toList();
  Future<List<CartItem>> getCartItems() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      CartItem(
        id: 'item_01',
        name: 'burger',
        description: 'Medium • Extra Cheese',
        imagePath: 'assets/restaurant_assets/burger.jpg',
        unitPrice: 14.99,
        quantity: 1,
      ),
      CartItem(
        id: 'item_02',
        name: 'strawberry cake',
        description: 'Regular',
        imagePath: 'assets/restaurant_assets/strawberry-cake.jpg',
        unitPrice: 8.99,
        quantity: 1,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Checkout Configuration
  // ---------------------------------------------------------------------------

  /// Returns global checkout values (delivery fee, wallet balance, tax rate).
  ///
  /// Firebase equivalent:
  ///   final doc = await FirebaseFirestore.instance
  ///       .collection('config')
  ///       .doc('checkout')
  ///       .get();
  ///   return CheckoutData.fromMap(doc.data()!);
  Future<CheckoutData> getCheckoutData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const CheckoutData(
      deliveryFee: 15,
      walletBalance: 150,
      taxRate: kTaxRate,
    );
  }

  // ---------------------------------------------------------------------------
  // Addresses
  // ---------------------------------------------------------------------------

  /// Returns the list of saved addresses for the current user.
  ///
  /// Firebase equivalent:
  ///   final snapshot = await FirebaseFirestore.instance
  ///       .collection('users')
  ///       .doc(userId)
  ///       .collection('addresses')
  ///       .get();
  ///   return snapshot.docs.map((d) => Address.fromMap(d.data())).toList();
  Future<List<Address>> getAddresses() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      Address(
        id: 'addr_01',
        label: 'Home',
        fullAddress: '123 Main St, Apt 4B, New York, NY 10001',
      ),
      Address(
        id: 'addr_02',
        label: 'Work',
        fullAddress: '456 Business Ave, Floor 12, New York, NY 10002',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Promo Codes
  // ---------------------------------------------------------------------------

  /// Validates a promo [code] and returns the matching [Coupon] if valid,
  /// or `null` if the code does not exist / has expired.
  ///
  /// Firebase equivalent:
  ///   final doc = await FirebaseFirestore.instance
  ///       .collection('coupons')
  ///       .doc(code.toUpperCase())
  ///       .get();
  ///   if (!doc.exists) return null;
  ///   return Coupon.fromMap(doc.data()!);
  // Future<Coupon?> validateCoupon(String code) async {
  //   await Future.delayed(const Duration(milliseconds: 600));

  //   // Mock coupon database
  //   const validCoupons = {
  //     'SAVE10': Coupon(
  //       code: 'SAVE10',
  //       discountFraction: 0.10,
  //       label: '10% OFF',
  //     ),
  //     'SAVE20': Coupon(
  //       code: 'SAVE20',
  //       discountFraction: 0.20,
  //       label: '20% OFF',
  //     ),
  //     'WELCOME': Coupon(
  //       code: 'WELCOME',
  //       discountFraction: 0.05,
  //       label: '5% OFF',
  //     ),
  //   };

  //   return validCoupons[code.toUpperCase()];
  // }
}