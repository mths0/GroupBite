import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String id;
  final String customerId;
  final GeoPoint customerLocation;
  final String restaurantId;
  final GeoPoint restaurantLocation;
  final String? driverId;
  final List<OrderItem> items;
  final String status;
  final DateTime createdAt;
  final double totalPrice;
  final String? paymentId; // can be null until payment is processed

  Order({
    required this.id,
    required this.customerId,
    required this.customerLocation,
    required this.restaurantId,
    required this.restaurantLocation,
    required this.status,
    required this.totalPrice,
    required this.items,
    required this.createdAt,
    this.driverId,
    this.paymentId,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    // Use 'as Map?' and fallback to empty map to avoid null errors on 'data'
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Order(
      id: doc.id,
      // Use the ?? operator to provide defaults if the DB field is null
      customerId: (data['customerId'] ?? '').toString(),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      driverId: data['driverId']
          ?.toString(), // This is nullable, so this is safe
      status: data['status']?.toString() ?? 'pending',
      restaurantLocation: data['restaurantLocation'] as GeoPoint,
      customerLocation: data['customerLocation'] as GeoPoint,
      // Handle the number conversion safely
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrderItem {
  final String menuId;
  final String name;
  final int quantity;
  final double
  priceAtPurchase; //? do we need this? we can get the price from the menu item.

  OrderItem({
    required this.menuId,
    required this.name,
    required this.quantity,
    required this.priceAtPurchase,
  });

  Map<String, dynamic> toJson() => {
    'menuId': menuId,
    'name': name,
    'quantity': quantity,
    'priceAtPurchase': priceAtPurchase,
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuId: map['menuId'],
      name: map['name'],
      quantity: map['quantity'],
      priceAtPurchase: map['priceAtPurchase'].toDouble(),
    );
  }
}
