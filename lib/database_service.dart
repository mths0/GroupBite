import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/cart_models.dart' as cart_models;
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/customer_address.dart';
import 'package:food_delivery_platform/models/family_wallet.dart';
import 'package:food_delivery_platform/models/family_wallet_invite.dart';
import 'package:food_delivery_platform/models/family_wallet_member.dart';
import 'package:food_delivery_platform/models/group_order.dart';
import 'package:food_delivery_platform/models/menu_item.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/models/saved_card.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';

import 'models/driver.dart';
import 'models/order.dart';

class DatabaseService {
  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;

  // ===========================================================================
  // FCM
  // ===========================================================================

  Future<void> saveUserFcmToken(String userId) async {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();

    if (token == null) return;

    await _db.collection('users').doc(userId).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': firestore.FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // USERS
  // ===========================================================================

  Future<void> createUser(Map<String, dynamic> userData) async {
    await _db.collection('users').doc(userData['id']).set(userData);
  }

  Future<void> updateUser({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('users').doc(userId).update(data);
  }

  Future<User?> getUserByPhone(String phone) async {
    final snapshot = await _db
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return _userFromMap(data);
  }

  Future<User?> getUserByEmail(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return _userFromMap(data);
  }

  Future<User?> getUserById(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return _userFromMap(data);
  }

  Future<Driver?> getDriverById(String driverId) async {
    final doc = await _db.collection('users').doc(driverId).get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return Driver.fromMap(data);
  }

  Future<Restaurant?> getRestaurantById(String restaurantId) async {
    final doc = await _db.collection('users').doc(restaurantId).get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return Restaurant.fromMap(data);
  }

  Future<void> updateDriverStatus(String driverId, DriverStatus status) async {
    await _db.collection('users').doc(driverId).update({
      'status': status.name,
    });
  }

  Stream<List<Restaurant>> getRestaurants() {
    return _db
        .collection('users')
        .where('role', isEqualTo: UserRole.restaurant.name)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Restaurant.fromMap(data);
          }).toList();
        });
  }

  Stream<Driver?> streamDriverById(String driverId) {
    return _db.collection('users').doc(driverId).snapshots().map((doc) {
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      return Driver.fromMap(data);
    });
  }

  User _userFromMap(Map<String, dynamic> map) {
    switch (map['role']) {
      case 'driver':
        return Driver.fromMap(map);
      case 'customer':
        return Customer.fromMap(map);
      case 'restaurant':
        return Restaurant.fromMap(map);
      default:
        throw Exception('Unknown role');
    }
  }

  // ===========================================================================
  // MENU
  // ===========================================================================

  Future<List<MenuItem>> getMenuForRestaurant({
    required String restaurantId,
  }) async {
    final snapshot = await _db
        .collection('users')
        .doc(restaurantId)
        .collection('menu_items')
        .get();

    return snapshot.docs.map((doc) {
      return MenuItem.fromMap(doc.data());
    }).toList();
  }

  // ===========================================================================
  // ORDERS
  // ===========================================================================

  Future<void> createOrder({
    required String customerId,
    required String restaurantId,
    required double totalPrice,
  }) async {
    await _db.collection('orders').add({
      'customerId': customerId,
      'restaurantId': restaurantId,
      'driverId': null,
      'status': OrderStatus.pending.name,
      'totalPrice': totalPrice,
      'createdAt': firestore.FieldValue.serverTimestamp(),
    });
  }

  Future<firestore.GeoPoint> getLocation(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();

    if (!doc.exists) {
      throw Exception("User not found");
    }

    final data = doc.data();
    if (data == null) {
      throw Exception("User data is null");
    }

    final location = data['location'] as firestore.GeoPoint?;

    if (location == null) {
      throw Exception("User location not found");
    }

    return location;
  }

  Future<Order> addOrder({
    required String customerId,
    required String restaurantId,
    required double totalPrice,
    required List<OrderItem> items,
  }) async {
    final orderId = IdGenerator.generateOrderId();
    final docRef = _db.collection('orders').doc(orderId);

    final customerLocation = await getLocation(customerId);
    final restaurantLocation = await getLocation(restaurantId);

    await docRef.set({
      'id': orderId,
      'customerId': customerId,
      'restaurantId': restaurantId,
      'driverId': null,
      'status': OrderStatus.pending.name,
      'totalPrice': totalPrice,
      'createdAt': firestore.FieldValue.serverTimestamp(),
      'canCancelUntil': firestore.Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 2)),
      ),
      'cancelledAt': null,
      'cancelledBy': null,
      'items': items.map((item) => item.toJson()).toList(),
      'customerLocation': customerLocation,
      'restaurantLocation': restaurantLocation,
      'isRated': false,
      'restaurantRating': null,
      'driverRating': null,
    });

    final snapshot = await docRef.get();
    return Order.fromFirestore(snapshot);
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    await _db.collection('orders').doc(orderId).update({
      'status': status.name,
    });
  }

  Future<void> restaurantAcceptOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': OrderStatus.accepted.name,
    });
  }

  Future<void> restaurantRejectOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': OrderStatus.rejected.name,
    });
  }

  Future<void> assignOrderToDriver({
    required String orderId,
    required String driverId,
  }) async {
    final docRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception("Order not found");
      }

      final data = snapshot.data() as Map<String, dynamic>;

      if (data['status'] != OrderStatus.accepted.name) {
        throw Exception("Order is not available for driver assignment.");
      }

      if (data['driverId'] != null && data['driverId'].toString().isNotEmpty) {
        throw Exception("Another driver has already taken this order.");
      }

      transaction.update(docRef, {
        'driverId': driverId,
        'status': OrderStatus.assigned.name,
      });
    });
  }

  Future<void> markOrderPickedUp(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': OrderStatus.pickedUp.name,
    });
  }

  Future<void> markOrderDelivered(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': OrderStatus.delivered.name,
    });
  }

  Future<void> completeOrderAndFreeDriver({
    required String orderId,
    required String driverId,
  }) async {
    await _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final driverRef = _db.collection('users').doc(driverId);

      transaction.update(orderRef, {
        'status': OrderStatus.delivered.name,
      });

      transaction.update(driverRef, {
        'status': DriverStatus.available.name,
      });
    });
  }

  Future<void> cancelOrderByCustomer({
    required String orderId,
    required String customerId,
  }) async {
    final orderRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);

      if (!snapshot.exists) {
        throw Exception('Order not found.');
      }

      final data = snapshot.data() as Map<String, dynamic>;

      if (data['customerId'] != customerId) {
        throw Exception('You cannot cancel this order.');
      }

      final status = data['status'] as String? ?? '';

      if (status != OrderStatus.pending.name) {
        throw Exception('This order can no longer be cancelled.');
      }

      final canCancelUntil = data['canCancelUntil'];

      if (canCancelUntil is! firestore.Timestamp) {
        throw Exception('Cancellation time not found.');
      }

      final now = DateTime.now();
      final expiry = canCancelUntil.toDate();

      if (now.isAfter(expiry)) {
        throw Exception('Cancellation time has expired.');
      }

      transaction.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'cancelledAt': firestore.FieldValue.serverTimestamp(),
        'cancelledBy': customerId,
      });
    });
  }

  Future<void> submitOrderRating({
    required String orderId,
    required String restaurantId,
    required String driverId,
    required int restaurantRating,
    required int driverRating,
  }) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final restaurantRef = _db.collection('users').doc(restaurantId);
    final driverRef = _db.collection('users').doc(driverId);

    await _db.runTransaction((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      final restaurantSnap = await transaction.get(restaurantRef);
      final driverSnap = await transaction.get(driverRef);

      if (!orderSnap.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderSnap.data() as Map<String, dynamic>;
      if ((orderData['isRated'] ?? false) == true) {
        throw Exception('This order has already been rated.');
      }

      if (!restaurantSnap.exists) {
        throw Exception('Restaurant not found');
      }

      if (!driverSnap.exists) {
        throw Exception('Driver not found');
      }

      final restaurantData = restaurantSnap.data() as Map<String, dynamic>;
      final driverData = driverSnap.data() as Map<String, dynamic>;

      final oldRestaurantRating =
          (restaurantData['rating'] as num?)?.toDouble() ?? 0.0;
      final oldRestaurantCount =
          (restaurantData['ratingCount'] as num?)?.toInt() ?? 0;

      final oldDriverRating = (driverData['rating'] as num?)?.toDouble() ?? 0.0;
      final oldDriverCount = (driverData['ratingCount'] as num?)?.toInt() ?? 0;

      final newRestaurantCount = oldRestaurantCount + 1;
      final newRestaurantAverage =
          ((oldRestaurantRating * oldRestaurantCount) + restaurantRating) /
          newRestaurantCount;

      final newDriverCount = oldDriverCount + 1;
      final newDriverAverage =
          ((oldDriverRating * oldDriverCount) + driverRating) / newDriverCount;

      transaction.update(orderRef, {
        'isRated': true,
        'restaurantRating': restaurantRating,
        'driverRating': driverRating,
        'ratedAt': firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(restaurantRef, {
        'rating': newRestaurantAverage,
        'ratingCount': newRestaurantCount,
      });

      transaction.update(driverRef, {
        'rating': newDriverAverage,
        'ratingCount': newDriverCount,
      });
    });
  }

  Stream<List<Order>> getOrdersForRestaurant(String restaurantId) {
    return _db
        .collection('orders')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
        });
  }

  Stream<List<Order>> getOrdersForCustomer(String customerId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
        });
  }

  Stream<List<Order>> getOrdersForDriver(String driverId) {
    return _db
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
        });
  }

  Stream<List<Order>> getAvailableOrdersForDrivers() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.accepted.name)
        .where('driverId', isNull: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
        });
  }

  Stream<Order?> streamOrderById(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Order.fromFirestore(doc);
    });
  }

  // ===========================================================================
  // GROUP ORDERS
  // ===========================================================================

  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();

    return List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<String> createGroupOrder({
    required String hostCustomerId,
    required String hostName,
    required String restaurantId,
  }) async {
    final groupRef = _db.collection('groupOrders').doc();
    final joinCode = _generateJoinCode();

    await groupRef.set({
      'hostCustomerId': hostCustomerId,
      'restaurantId': restaurantId,
      'joinCode': joinCode,
      'status': GroupOrderStatus.open.name,
      'createdAt': firestore.FieldValue.serverTimestamp(),
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    });

    await groupRef.collection('members').doc(hostCustomerId).set({
      'customerId': hostCustomerId,
      'name': hostName,
      'status': GroupMemberStatus.ordering.name,
      'joinedAt': firestore.FieldValue.serverTimestamp(),
    });

    return groupRef.id;
  }

  Future<GroupOrder?> getGroupOrderById(String groupOrderId) async {
    final doc = await _db.collection('groupOrders').doc(groupOrderId).get();

    if (!doc.exists) return null;

    return GroupOrder.fromFirestore(doc);
  }

  Future<String?> findGroupOrderIdByJoinCode(String joinCode) async {
    final snapshot = await firestore.FirebaseFirestore.instance
        .collection('groupOrders')
        .where('joinCode', isEqualTo: joinCode.trim().toUpperCase())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return snapshot.docs.first.id;
  }

  Future<void> joinGroupOrder({
    required String groupOrderId,
    required String customerId,
    required String customerName,
  }) async {
    final groupRef = _db.collection('groupOrders').doc(groupOrderId);
    final groupSnap = await groupRef.get();

    if (!groupSnap.exists) {
      throw Exception('Group order not found.');
    }

    final data = groupSnap.data() ?? {};
    if (data['status'] != GroupOrderStatus.open.name) {
      throw Exception('This group order is not open anymore.');
    }

    await groupRef.collection('members').doc(customerId).set({
      'customerId': customerId,
      'name': customerName,
      'status': GroupMemberStatus.ordering.name,
      'joinedAt': firestore.FieldValue.serverTimestamp(),
    });
  }

  Future<GroupOrderMember?> getGroupMember({
    required String groupOrderId,
    required String customerId,
  }) async {
    final doc = await _db
        .collection('groupOrders')
        .doc(groupOrderId)
        .collection('members')
        .doc(customerId)
        .get();

    if (!doc.exists) return null;

    return GroupOrderMember.fromFirestore(doc);
  }

  Future<void> markGroupMemberReady({
    required String groupOrderId,
    required String customerId,
  }) async {
    await _db
        .collection('groupOrders')
        .doc(groupOrderId)
        .collection('members')
        .doc(customerId)
        .update({
          'status': GroupMemberStatus.ready.name,
          'updatedAt': firestore.FieldValue.serverTimestamp(),
        });
  }

  Future<void> markGroupMemberPaid({
    required String groupOrderId,
    required String customerId,
  }) async {
    await _db
        .collection('groupOrders')
        .doc(groupOrderId)
        .collection('members')
        .doc(customerId)
        .update({
          'status': GroupMemberStatus.paid.name,
          'paidAt': firestore.FieldValue.serverTimestamp(),
          'updatedAt': firestore.FieldValue.serverTimestamp(),
        });
  }

  Future<void> addItemToGroupOrder({
    required String groupOrderId,
    required String memberId,
    required MenuItem menuItem,
  }) async {
    final groupRef = _db.collection('groupOrders').doc(groupOrderId);
    final itemRef = groupRef
        .collection('items')
        .doc('${memberId}_${menuItem.id}');
    final itemSnap = await itemRef.get();

    if (itemSnap.exists) {
      final data = itemSnap.data() ?? {};
      final oldQuantity = (data['quantity'] as num?)?.toInt() ?? 1;
      final newQuantity = oldQuantity + 1;
      final unitPrice =
          (data['unitPrice'] as num?)?.toDouble() ?? menuItem.price;

      await itemRef.update({
        'quantity': newQuantity,
        'lineTotal': newQuantity * unitPrice,
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await itemRef.set({
        'menuItemId': menuItem.id,
        'memberId': memberId,
        'name': menuItem.name,
        'description': menuItem.description,
        'imageUrl': menuItem.imageUrl,
        'unitPrice': menuItem.price,
        'quantity': 1,
        'lineTotal': menuItem.price,
        'createdAt': firestore.FieldValue.serverTimestamp(),
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
    }

    await groupRef.update({
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementGroupOrderItem({
    required String groupOrderId,
    required String memberId,
    required String itemId,
  }) async {
    final itemRef = _db
        .collection('groupOrders')
        .doc(groupOrderId)
        .collection('items')
        .doc(itemId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);

      if (!snapshot.exists) {
        throw Exception('Group order item not found.');
      }

      final data = snapshot.data() as Map<String, dynamic>;

      if ((data['memberId'] ?? '').toString() != memberId) {
        throw Exception('You can only edit your own items.');
      }

      final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
      final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;

      final newQuantity = quantity + 1;
      final newLineTotal = newQuantity * unitPrice;

      transaction.update(itemRef, {
        'quantity': newQuantity,
        'lineTotal': newLineTotal,
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> decrementGroupOrderItem({
    required String groupOrderId,
    required String memberId,
    required String itemId,
  }) async {
    final itemRef = _db
        .collection('groupOrders')
        .doc(groupOrderId)
        .collection('items')
        .doc(itemId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);

      if (!snapshot.exists) {
        throw Exception('Group order item not found.');
      }

      final data = snapshot.data() as Map<String, dynamic>;

      if ((data['memberId'] ?? '').toString() != memberId) {
        throw Exception('You can only edit your own items.');
      }

      final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
      final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;

      if (quantity <= 1) {
        transaction.delete(itemRef);
        return;
      }

      final newQuantity = quantity - 1;
      final newLineTotal = newQuantity * unitPrice;

      transaction.update(itemRef, {
        'quantity': newQuantity,
        'lineTotal': newLineTotal,
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> decreaseGroupOrderItem({
    required String groupOrderId,
    required String memberId,
    required String menuItemId,
  }) async {
    final itemRef = _db
        .collection('groupOrders')
        .doc(groupOrderId)
        .collection('items')
        .doc('${memberId}_$menuItemId');

    final itemSnap = await itemRef.get();

    if (!itemSnap.exists) return;

    final data = itemSnap.data() ?? {};
    final quantity = data['quantity'] ?? 1;

    if (quantity <= 1) {
      await itemRef.delete();
    } else {
      await itemRef.update({
        'quantity': firestore.FieldValue.increment(-1),
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> removeGroupOrderItem({
    required String groupOrderId,
    required String memberId,
    required String itemId,
  }) async {
    final itemRef = _db
        .collection('groupOrders')
        .doc(groupOrderId)
        .collection('items')
        .doc(itemId);

    final snapshot = await itemRef.get();

    if (!snapshot.exists) {
      throw Exception('Group order item not found.');
    }

    final data = snapshot.data() as Map<String, dynamic>;

    if ((data['memberId'] ?? '').toString() != memberId) {
      throw Exception('You can only remove your own items.');
    }

    await itemRef.delete();
  }

  Future<void> lockGroupOrder({
    required String groupOrderId,
  }) async {
    await _db.collection('groupOrders').doc(groupOrderId).update({
      'status': GroupOrderStatus.locked.name,
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeGroupOrder({
    required String groupOrderId,
  }) async {
    await _db.collection('groupOrders').doc(groupOrderId).update({
      'status': GroupOrderStatus.completed.name,
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelGroupOrder({
    required String groupOrderId,
  }) async {
    await _db.collection('groupOrders').doc(groupOrderId).update({
      'status': GroupOrderStatus.cancelled.name,
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    });
  }

  Future<void> placeFinalGroupOrder({
    required String groupOrderId,
    required String customerId,
    required String restaurantId,
  }) async {
    final groupRef = _db.collection('groupOrders').doc(groupOrderId);

    final membersSnapshot = await groupRef.collection('members').get();
    final itemsSnapshot = await groupRef.collection('items').get();

    if (membersSnapshot.docs.isEmpty) {
      throw Exception('No members in this group order.');
    }

    if (itemsSnapshot.docs.isEmpty) {
      throw Exception('No items in this group order.');
    }

    final allPaid = membersSnapshot.docs.every((doc) {
      final data = doc.data();
      return data['status'] == GroupMemberStatus.paid.name;
    });

    if (!allPaid) {
      throw Exception('Not all members have paid yet.');
    }

    final orderItems = itemsSnapshot.docs.map((doc) {
      final item = GroupOrderItem.fromFirestore(doc);

      return OrderItem(
        menuId: item.menuItemId,
        name: item.name,
        quantity: item.quantity,
        priceAtPurchase: item.unitPrice,
      );
    }).toList();

    final subtotal = itemsSnapshot.docs.fold<double>(0.0, (sum, doc) {
      final item = GroupOrderItem.fromFirestore(doc);
      return sum + item.lineTotal;
    });

    final restaurant = await getRestaurantById(restaurantId);
    final deliveryFee = restaurant?.deliveryFee ?? 0.0;

    final tax = subtotal * 0.15;
    final total = subtotal + deliveryFee + tax;

    await addOrder(
      customerId: customerId,
      restaurantId: restaurantId,
      totalPrice: total,
      items: orderItems,
    );

    await groupRef.update({
      'status': GroupOrderStatus.completed.name,
      'finalSubtotal': subtotal,
      'finalDeliveryFee': deliveryFee,
      'finalTax': tax,
      'finalTotal': total,
      'completedAt': firestore.FieldValue.serverTimestamp(),
      'updatedAt': firestore.FieldValue.serverTimestamp(),
      'canCancelUntil': firestore.Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 2)),
      ),
      'cancelledAt': null,
      'cancelledBy': null,
    });
  }

  Future<bool> payGroupMemberAndMaybePlaceOrder({
    required String groupOrderId,
    required String customerId,
    required String restaurantId,
  }) async {
    final groupRef = _db.collection('groupOrders').doc(groupOrderId);

    final groupSnapshot = await groupRef.get();
    final groupData = groupSnapshot.data();

    if (groupData == null) {
      throw Exception('Group order not found.');
    }

    final hostCustomerId = groupData['hostCustomerId'] as String?;

    if (hostCustomerId == null || hostCustomerId.isEmpty) {
      throw Exception('Host customer ID not found.');
    }

    final membersSnapshot = await groupRef.collection('members').get();

    if (membersSnapshot.docs.isEmpty) {
      throw Exception('No members found in this group order.');
    }

    final currentMemberDoc = membersSnapshot.docs
        .where((doc) => doc.id == customerId)
        .toList();

    if (currentMemberDoc.isEmpty) {
      throw Exception('You are not a member of this group order.');
    }

    final isHost = customerId == hostCustomerId;

    final otherMembersNotPaid = membersSnapshot.docs.where((doc) {
      if (doc.id == hostCustomerId) return false;

      final data = doc.data();
      return data['status'] != GroupMemberStatus.paid.name;
    }).toList();

    if (isHost && otherMembersNotPaid.isNotEmpty) {
      throw Exception('Host must pay last. Wait until all members pay first.');
    }

    await groupRef.collection('members').doc(customerId).update({
      'status': GroupMemberStatus.paid.name,
      'paidAt': firestore.FieldValue.serverTimestamp(),
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    });

    if (!isHost) {
      return false;
    }

    final updatedMembersSnapshot = await groupRef.collection('members').get();

    final allPaid = updatedMembersSnapshot.docs.every((doc) {
      final data = doc.data();
      return data['status'] == GroupMemberStatus.paid.name;
    });

    if (!allPaid) {
      return false;
    }

    await placeFinalGroupOrder(
      groupOrderId: groupOrderId,
      customerId: hostCustomerId,
      restaurantId: restaurantId,
    );

    return true;
  }

  Stream<GroupOrder?> watchGroupOrder(String groupOrderId) {
    return _db.collection('groupOrders').doc(groupOrderId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return GroupOrder.fromFirestore(doc);
    });
  }

  Stream<List<GroupOrderMember>> watchGroupMembers(String groupOrderId) {
    return _db
        .collection('groupOrders')
        .doc(groupOrderId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(GroupOrderMember.fromFirestore).toList();
        });
  }

  Stream<List<GroupOrderItem>> watchGroupItems(String groupOrderId) {
    return _db
        .collection('groupOrders')
        .doc(groupOrderId)
        .collection('items')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(GroupOrderItem.fromFirestore).toList();
        });
  }

  // ===========================================================================
  // CUSTOMER ADDRESSES
  // ===========================================================================

  Future<List<CustomerAddress>> getCustomerAddresses(String customerId) async {
    final snapshot = await _db
        .collection('users')
        .doc(customerId)
        .collection('addresses')
        .get();

    return snapshot.docs
        .map((doc) => CustomerAddress.fromMap(doc.data()))
        .toList();
  }

  Stream<List<CustomerAddress>> streamCustomerAddresses(String customerId) {
    return _db
        .collection('users')
        .doc(customerId)
        .collection('addresses')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CustomerAddress.fromMap(doc.data()))
              .toList();
        });
  }

  Future<void> addCustomerAddress({
    required String customerId,
    required CustomerAddress address,
  }) async {
    await _db
        .collection('users')
        .doc(customerId)
        .collection('addresses')
        .doc(address.id)
        .set(address.toJson());
  }

  Future<void> updateCustomerAddress({
    required String customerId,
    required CustomerAddress address,
  }) async {
    await _db
        .collection('users')
        .doc(customerId)
        .collection('addresses')
        .doc(address.id)
        .update(address.toJson());
  }

  Future<void> deleteCustomerAddress({
    required String customerId,
    required String addressId,
  }) async {
    await _db
        .collection('users')
        .doc(customerId)
        .collection('addresses')
        .doc(addressId)
        .delete();
  }

  Future<void> setDefaultCustomerAddress({
    required String customerId,
    required String addressId,
  }) async {
    final col = _db.collection('users').doc(customerId).collection('addresses');

    final snapshot = await col.get();

    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isDefault': doc.id == addressId,
      });
    }

    await batch.commit();
  }

  Future<CustomerAddress?> getDefaultCustomerAddress(String customerId) async {
    final snapshot = await _db
        .collection('users')
        .doc(customerId)
        .collection('addresses')
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return CustomerAddress.fromMap(snapshot.docs.first.data());
  }

  // ===========================================================================
  // COUPONS
  // ===========================================================================

  Future<cart_models.Coupon?> validateCoupon({
    required String restaurantId,
    required String code,
  }) async {
    final normalizedCode = code.trim().toUpperCase();

    final snapshot = await _db
        .collection('users')
        .doc(restaurantId)
        .collection('promotions')
        .where('code', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();

    if ((data['enabled'] ?? false) != true) return null;

    final now = DateTime.now();
    final startAt = DateTime.tryParse((data['startAt'] ?? '').toString());
    final endAt = DateTime.tryParse((data['endAt'] ?? '').toString());

    if (startAt != null && now.isBefore(startAt)) return null;
    if (endAt != null && now.isAfter(endAt)) return null;

    final discountType = (data['discountType'] ?? '').toString();
    final discountValue = (data['discountValue'] is num)
        ? (data['discountValue'] as num).toDouble()
        : double.tryParse('${data['discountValue']}') ?? 0.0;

    return cart_models.Coupon(
      code: (data['code'] ?? '').toString(),
      label: (data['title'] ?? '').toString(),
      discountType: discountType == 'fixed'
          ? cart_models.CouponDiscountType.fixed
          : cart_models.CouponDiscountType.percentage,
      discountValue: discountType == 'free_delivery' ? 0.0 : discountValue,
    );
  }

  // ===========================================================================
  // CUSTOMER CARDS
  // ===========================================================================

  firestore.CollectionReference<Map<String, dynamic>> _cardsCollection(
    String customerId,
  ) => _db.collection('users').doc(customerId).collection('cards');

  Stream<List<SavedCard>> streamCustomerCards(String customerId) {
    return _cardsCollection(customerId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SavedCard.fromMap(doc.data())).toList();
    });
  }

  Future<void> addCustomerCard({
    required String customerId,
    required SavedCard card,
  }) async {
    await _cardsCollection(customerId).doc(card.id).set(card.toJson());
  }

  Future<void> deleteCustomerCard({
    required String customerId,
    required String cardId,
  }) async {
    await _cardsCollection(customerId).doc(cardId).delete();
  }

  // ===========================================================================
  // WALLET
  // ===========================================================================

  firestore.DocumentReference<Map<String, dynamic>> _walletDoc(
    String customerId,
  ) => _db.collection('users').doc(customerId).collection('wallet').doc('main');

  Stream<double> streamWalletBalance(String customerId) {
    return _walletDoc(customerId).snapshots().map((doc) {
      if (!doc.exists) return 0.0;
      final data = doc.data();
      final raw = data?['balance'];
      if (raw is num) return raw.toDouble();
      return double.tryParse('$raw') ?? 0.0;
    });
  }

  Future<void> addFundsToWallet({
    required String customerId,
    required double amount,
  }) async {
    if (amount <= 0) return;
    final ref = _walletDoc(customerId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) {
        transaction.set(ref, {
          'balance': amount,
          'updatedAt': firestore.FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(ref, {
          'balance': firestore.FieldValue.increment(amount),
          'updatedAt': firestore.FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> deductFromWallet({
    required String customerId,
    required double amount,
  }) async {
    if (amount <= 0) return;
    final ref = _walletDoc(customerId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final balance = !snap.exists
          ? 0.0
          : ((snap.data()?['balance'] as num?)?.toDouble() ?? 0.0);

      if (balance < amount) {
        throw Exception('Insufficient wallet balance');
      }

      transaction.update(ref, {
        'balance': firestore.FieldValue.increment(-amount),
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
    });
  }

  // ===========================================================================
  // FAMILY WALLET
  // ===========================================================================

  firestore.CollectionReference<Map<String, dynamic>>
  get _familyWalletsCollection => _db.collection('family_wallets');

  firestore.CollectionReference<Map<String, dynamic>>
  get _familyWalletInvitesCollection => _db.collection('family_wallet_invites');

  firestore.CollectionReference<Map<String, dynamic>> _familyMembersCollection(
    String walletId,
  ) => _familyWalletsCollection.doc(walletId).collection('members');

  Stream<List<FamilyWalletMember>> streamFamilyWalletMembers(String walletId) {
    return _familyMembersCollection(walletId).snapshots().map(
      (snap) =>
          snap.docs.map((d) => FamilyWalletMember.fromMap(d.data())).toList(),
    );
  }

  Stream<FamilyWalletMember?> streamFamilyWalletMember({
    required String walletId,
    required String userId,
  }) {
    return _familyMembersCollection(walletId).doc(userId).snapshots().map((d) {
      if (!d.exists) return null;
      final data = d.data();
      if (data == null) return null;
      return FamilyWalletMember.fromMap(data);
    });
  }

  Future<void> setMemberLimit({
    required String walletId,
    required String userId,
    required double? limit,
    required LimitPeriod period,
  }) async {
    final ref = _familyMembersCollection(walletId).doc(userId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final now = DateTime.now();

      if (!snap.exists) {
        tx.set(ref, {
          'userId': userId,
          'limit': limit,
          'period': period.name,
          'spentInPeriod': 0.0,
          'periodStartedAt': firestore.Timestamp.fromDate(
            currentPeriodStart(period, now),
          ),
          'joinedAt': firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      final existing = FamilyWalletMember.fromMap(snap.data()!);
      final periodChanged = existing.period != period;

      final update = <String, dynamic>{
        'limit': limit,
        'period': period.name,
      };
      if (periodChanged) {
        update['spentInPeriod'] = 0.0;
        update['periodStartedAt'] = firestore.Timestamp.fromDate(
          currentPeriodStart(period, now),
        );
      }
      tx.update(ref, update);
    });
  }

  Future<void> resetMemberSpend({
    required String walletId,
    required String userId,
  }) async {
    await _familyMembersCollection(walletId).doc(userId).update({
      'spentInPeriod': 0.0,
      'periodStartedAt': firestore.Timestamp.fromDate(DateTime.now()),
    });
  }

  Stream<FamilyWallet?> streamFamilyWalletForUser(String userId) {
    FamilyWallet? extractFirst(
      firestore.QuerySnapshot<Map<String, dynamic>> snap,
    ) {
      if (snap.docs.isEmpty) return null;
      return FamilyWallet.fromMap(snap.docs.first.data());
    }

    final controller = StreamController<FamilyWallet?>();
    FamilyWallet? asOwner;
    FamilyWallet? asMember;

    void emit() {
      if (controller.isClosed) return;
      controller.add(asOwner ?? asMember);
    }

    final ownerSub = _familyWalletsCollection
        .where('ownerId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .listen((snap) {
          asOwner = extractFirst(snap);
          emit();
        }, onError: controller.addError);

    final memberSub = _familyWalletsCollection
        .where('memberIds', arrayContains: userId)
        .limit(1)
        .snapshots()
        .listen((snap) {
          asMember = extractFirst(snap);
          emit();
        }, onError: controller.addError);

    controller.onCancel = () async {
      await ownerSub.cancel();
      await memberSub.cancel();
    };

    return controller.stream;
  }

  Stream<List<FamilyWalletInvite>> streamPendingInvites(String userId) {
    return _familyWalletInvitesCollection
        .where('inviteeId', isEqualTo: userId)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => FamilyWalletInvite.fromMap(doc.data()))
              .toList(),
        );
  }

  Stream<List<FamilyWalletInvite>> streamWalletPendingInvites(String walletId) {
    return _familyWalletInvitesCollection
        .where('walletId', isEqualTo: walletId)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => FamilyWalletInvite.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<bool> _userIsInAnyWallet(
    firestore.Transaction tx,
    String userId,
  ) async {
    final asOwner = await _familyWalletsCollection
        .where('ownerId', isEqualTo: userId)
        .limit(1)
        .get();
    if (asOwner.docs.isNotEmpty) return true;

    final asMember = await _familyWalletsCollection
        .where('memberIds', arrayContains: userId)
        .limit(1)
        .get();
    return asMember.docs.isNotEmpty;
  }

  Future<FamilyWallet> createFamilyWallet({
    required String ownerId,
    required String ownerName,
  }) async {
    return _db.runTransaction<FamilyWallet>((tx) async {
      if (await _userIsInAnyWallet(tx, ownerId)) {
        throw Exception('You are already in a family wallet');
      }

      final id = IdGenerator.generateFamilyWalletId();
      final ref = _familyWalletsCollection.doc(id);

      final data = {
        'id': id,
        'name': 'Family Wallet',
        'ownerId': ownerId,
        'ownerName': ownerName,
        'balance': 0.0,
        'memberIds': <String>[],
        'createdAt': firestore.FieldValue.serverTimestamp(),
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      };
      tx.set(ref, data);

      return FamilyWallet(
        id: id,
        name: 'Family Wallet',
        ownerId: ownerId,
        ownerName: ownerName,
        balance: 0.0,
        memberIds: const [],
      );
    });
  }

  Future<FamilyWalletInviteResult> inviteToFamilyWallet({
    required String walletId,
    required String ownerId,
    required String ownerName,
    required String phone,
    double? limit,
    LimitPeriod period = LimitPeriod.manual,
  }) async {
    final invitee = await getUserByPhone(phone);
    if (invitee == null) return FamilyWalletInviteResult.notFound;
    if (invitee.role != UserRole.customer) {
      return FamilyWalletInviteResult.notCustomer;
    }
    if (invitee.id == ownerId) return FamilyWalletInviteResult.self;

    final inAnyWallet = await _familyWalletsCollection
        .where('memberIds', arrayContains: invitee.id)
        .limit(1)
        .get();
    if (inAnyWallet.docs.isNotEmpty) {
      return FamilyWalletInviteResult.alreadyInWallet;
    }
    final asOwner = await _familyWalletsCollection
        .where('ownerId', isEqualTo: invitee.id)
        .limit(1)
        .get();
    if (asOwner.docs.isNotEmpty) {
      return FamilyWalletInviteResult.alreadyInWallet;
    }

    final existing = await _familyWalletInvitesCollection
        .where('walletId', isEqualTo: walletId)
        .where('inviteeId', isEqualTo: invitee.id)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return FamilyWalletInviteResult.alreadyInvited;
    }

    final id = IdGenerator.generateInviteId();
    await _familyWalletInvitesCollection.doc(id).set({
      'id': id,
      'walletId': walletId,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'inviteeId': invitee.id,
      'inviteePhone': phone,
      'status': InviteStatus.pending.name,
      'inviteeLimit': limit,
      'inviteePeriod': period.name,
      'createdAt': firestore.FieldValue.serverTimestamp(),
    });

    return FamilyWalletInviteResult.ok;
  }

  Future<void> acceptFamilyWalletInvite(String inviteId) async {
    await _db.runTransaction((tx) async {
      final inviteRef = _familyWalletInvitesCollection.doc(inviteId);
      final inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) throw Exception('Invite not found');

      final invite = FamilyWalletInvite.fromMap(inviteSnap.data()!);
      if (invite.status != InviteStatus.pending) {
        throw Exception('Invite no longer pending');
      }

      if (await _userIsInAnyWallet(tx, invite.inviteeId)) {
        throw Exception('You are already in a family wallet');
      }

      final walletRef = _familyWalletsCollection.doc(invite.walletId);
      final walletSnap = await tx.get(walletRef);
      if (!walletSnap.exists) throw Exception('Family wallet not found');

      final memberRef = _familyMembersCollection(
        invite.walletId,
      ).doc(invite.inviteeId);
      final now = DateTime.now();
      tx.set(memberRef, {
        'userId': invite.inviteeId,
        'limit': invite.inviteeLimit,
        'period': invite.inviteePeriod.name,
        'spentInPeriod': 0.0,
        'periodStartedAt': firestore.Timestamp.fromDate(
          currentPeriodStart(invite.inviteePeriod, now),
        ),
        'joinedAt': firestore.FieldValue.serverTimestamp(),
      });

      tx.update(walletRef, {
        'memberIds': firestore.FieldValue.arrayUnion([invite.inviteeId]),
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
      tx.update(inviteRef, {'status': InviteStatus.accepted.name});
    });
  }

  Future<void> rejectFamilyWalletInvite(String inviteId) async {
    await _familyWalletInvitesCollection.doc(inviteId).update({
      'status': InviteStatus.rejected.name,
    });
  }

  Future<void> removeFamilyWalletMember({
    required String walletId,
    required String memberId,
  }) async {
    final batch = _db.batch();
    batch.update(_familyWalletsCollection.doc(walletId), {
      'memberIds': firestore.FieldValue.arrayRemove([memberId]),
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    });
    batch.delete(_familyMembersCollection(walletId).doc(memberId));
    await batch.commit();
  }

  Future<void> leaveFamilyWallet({
    required String walletId,
    required String userId,
  }) async {
    await removeFamilyWalletMember(walletId: walletId, memberId: userId);
  }

  Future<void> addFundsToFamilyWallet({
    required String walletId,
    required double amount,
  }) async {
    if (amount <= 0) return;
    await _familyWalletsCollection.doc(walletId).update({
      'balance': firestore.FieldValue.increment(amount),
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    });
  }

  Future<void> deductFromFamilyWallet({
    required String walletId,
    required String userId,
    required double amount,
  }) async {
    if (amount <= 0) return;
    final walletRef = _familyWalletsCollection.doc(walletId);
    final memberRef = _familyMembersCollection(walletId).doc(userId);

    await _db.runTransaction((tx) async {
      final walletSnap = await tx.get(walletRef);
      if (!walletSnap.exists) throw Exception('Family wallet not found');

      final balance =
          ((walletSnap.data()?['balance'] as num?)?.toDouble()) ?? 0.0;
      if (balance < amount) {
        throw Exception('Insufficient family wallet balance');
      }

      final isOwner = walletSnap.data()?['ownerId'] == userId;

      if (!isOwner) {
        final memberSnap = await tx.get(memberRef);

        final FamilyWalletMember member = memberSnap.exists
            ? FamilyWalletMember.fromMap(memberSnap.data()!)
            : FamilyWalletMember(
                userId: userId,
                limit: null,
                period: LimitPeriod.manual,
                spentInPeriod: 0.0,
                periodStartedAt: DateTime.fromMillisecondsSinceEpoch(0),
              );

        final now = DateTime.now();
        final boundary = currentPeriodStart(member.period, now);
        final effectiveSpent = member.periodStartedAt.isBefore(boundary)
            ? 0.0
            : member.spentInPeriod;

        if (member.limit != null && effectiveSpent + amount > member.limit!) {
          throw Exception('Spending limit reached');
        }

        final newSpent = effectiveSpent + amount;
        final newPeriodStart = member.periodStartedAt.isBefore(boundary)
            ? boundary
            : member.periodStartedAt;

        final update = <String, dynamic>{
          'userId': userId,
          'limit': member.limit,
          'period': member.period.name,
          'spentInPeriod': newSpent,
          'periodStartedAt': firestore.Timestamp.fromDate(newPeriodStart),
        };
        if (!memberSnap.exists) {
          update['joinedAt'] = firestore.FieldValue.serverTimestamp();
          tx.set(memberRef, update);
        } else {
          tx.update(memberRef, update);
        }
      }

      tx.update(walletRef, {
        'balance': firestore.FieldValue.increment(-amount),
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteFamilyWallet({
    required String walletId,
    required String ownerId,
  }) async {
    await _db.runTransaction((tx) async {
      final walletRef = _familyWalletsCollection.doc(walletId);
      final personalRef = _walletDoc(ownerId);

      final walletSnap = await tx.get(walletRef);
      if (!walletSnap.exists) return;

      final balance =
          ((walletSnap.data()?['balance'] as num?)?.toDouble()) ?? 0.0;

      final personalSnap = await tx.get(personalRef);

      if (balance > 0) {
        if (!personalSnap.exists) {
          tx.set(personalRef, {
            'balance': balance,
            'updatedAt': firestore.FieldValue.serverTimestamp(),
          });
        } else {
          tx.update(personalRef, {
            'balance': firestore.FieldValue.increment(balance),
            'updatedAt': firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      tx.delete(walletRef);
    });

    final pending = await _familyWalletInvitesCollection
        .where('walletId', isEqualTo: walletId)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .get();
    final batch = _db.batch();
    for (final doc in pending.docs) {
      batch.update(doc.reference, {'status': InviteStatus.rejected.name});
    }
    if (pending.docs.isNotEmpty) await batch.commit();
  }

  // ===========================================================================
  // GENERIC HELPERS
  // ===========================================================================

  Future<void> deleteDocument({
    required String collection,
    required String docId,
  }) async {
    await _db.collection(collection).doc(docId).delete();
  }
}
