import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  rejected,
  accepted,
  pickedUp,
  delivered,
}

class Order {
  final String id;
  final String customerId;
  final GeoPoint customerLocation;
  final String restaurantId;
  final GeoPoint restaurantLocation;
  final String? driverId;
  final List<OrderItem> items;
  final OrderStatus status;
  final DateTime createdAt;
  final double totalPrice;
  final String? paymentId;

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
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Order(
      id: doc.id,
      customerId: (data['customerId'] ?? '').toString(),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      driverId: data['driverId']?.toString(),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending').toString(),
        orElse: () => OrderStatus.pending,
      ),
      restaurantLocation: data['restaurantLocation'] as GeoPoint,
      customerLocation: data['customerLocation'] as GeoPoint,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentId: data['paymentId']?.toString(),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'customerLocation': customerLocation,
        'restaurantId': restaurantId,
        'restaurantLocation': restaurantLocation,
        'driverId': driverId,
        'items': items.map((e) => e.toJson()).toList(),
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'totalPrice': totalPrice,
        'paymentId': paymentId,
      };
}

class OrderItem {
  final String menuId;
  final String name;
  final int quantity;
  final double priceAtPurchase;

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
      menuId: (map['menuId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      priceAtPurchase: (map['priceAtPurchase'] as num?)?.toDouble() ?? 0.0,
    );
  }
}