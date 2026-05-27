import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yjeek/models/selected_option_choice.dart';

enum OrderStatus {
  pending,
  rejected,
  accepted,
  assigned,
  pickedUp,
  delivered,
  cancelled,
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
  final double? deliveryFee;
  final double? discount;
  final String? paymentId;
  final String? familyWalletId;
  final bool isRated;
  final int? restaurantRating;
  final int? driverRating;
  final DateTime? canCancelUntil;
  final DateTime? restaurantRespondBy;
  final DateTime? driverAcceptBy;
  final DateTime? scheduledFor;
  final bool paymentRefunded;
  final double? refundedAmount;

  Order({
    required this.id,
    required this.customerId,
    required this.customerLocation,
    required this.restaurantId,
    required this.restaurantLocation,
    required this.status,
    required this.totalPrice,
    this.deliveryFee,
    this.discount,
    required this.items,
    required this.createdAt,
    required this.isRated,
    this.restaurantRating,
    this.driverRating,
    this.driverId,
    this.paymentId,
    this.familyWalletId,
    required this.canCancelUntil,
    this.restaurantRespondBy,
    this.driverAcceptBy,
    this.scheduledFor,
    this.paymentRefunded = false,
    this.refundedAmount,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final rawCanCancelUntil = data['canCancelUntil'];
    final rawRestaurantRespondBy = data['restaurantRespondBy'];
    final rawDriverAcceptBy = data['driverAcceptBy'];
    final rawScheduledFor = data['scheduledFor'];
    return Order(
      id: doc.id,
      customerId: (data['customerId'] ?? '').toString(),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      driverId: data['driverId']?.toString(),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending').toString(),
        orElse: () => OrderStatus.pending,
      ),
      isRated: (data['isRated'] ?? false) as bool,
      restaurantRating: (data['restaurantRating'] as num?)?.toInt(),
      driverRating: (data['driverRating'] as num?)?.toInt(),
      restaurantLocation: data['restaurantLocation'] as GeoPoint,
      customerLocation: data['customerLocation'] as GeoPoint,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble(),
      discount: (data['discount'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentId: data['paymentId']?.toString(),
      familyWalletId: data['familyWalletId']?.toString(),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      canCancelUntil: rawCanCancelUntil is Timestamp
          ? rawCanCancelUntil.toDate()
          : null,
      restaurantRespondBy: rawRestaurantRespondBy is Timestamp
          ? rawRestaurantRespondBy.toDate()
          : null,
      driverAcceptBy: rawDriverAcceptBy is Timestamp
          ? rawDriverAcceptBy.toDate()
          : null,
      scheduledFor: rawScheduledFor is Timestamp
          ? rawScheduledFor.toDate()
          : null,
      paymentRefunded: (data['paymentRefunded'] ?? false) == true,
      refundedAmount: (data['refundedAmount'] as num?)?.toDouble(),
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
    'isRated': isRated,
    'restaurantRating': restaurantRating,
    'driverRating': driverRating,
    'createdAt': Timestamp.fromDate(createdAt),
    'totalPrice': totalPrice,
    'deliveryFee': deliveryFee,
    'discount': discount,
    'paymentId': paymentId,
    'familyWalletId': familyWalletId,
    'scheduledFor': scheduledFor != null
        ? Timestamp.fromDate(scheduledFor!)
        : null,
  };
}

class OrderItem {
  final String menuId;
  final String name;
  final int quantity;
  final double priceAtPurchase;
  final List<SelectedOptionChoice> selectedOptions;

  OrderItem({
    required this.menuId,
    required this.name,
    required this.quantity,
    required this.priceAtPurchase,
    this.selectedOptions = const [],
  });

  String get customizationSummary {
    if (selectedOptions.isEmpty) return '';
    final groups = <String, List<String>>{};
    for (final o in selectedOptions) {
      groups.putIfAbsent(o.groupTitle, () => []).add(o.choiceName);
    }
    return groups.entries
        .map((e) => '${e.key}: ${e.value.join(', ')}')
        .join('\n');
  }

  Map<String, dynamic> toJson() => {
    'menuId': menuId,
    'name': name,
    'quantity': quantity,
    'priceAtPurchase': priceAtPurchase,
    'selectedOptions': selectedOptions.map((e) => e.toJson()).toList(),
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuId: (map['menuId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      priceAtPurchase: (map['priceAtPurchase'] as num?)?.toDouble() ?? 0.0,
      selectedOptions: (map['selectedOptions'] as List<dynamic>? ?? [])
          .map((e) => SelectedOptionChoice.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
