import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';
import 'models/driver.dart';
import 'models/order.dart';

class DatabaseService {
  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;

  // ---------------- USERS ----------------

  Future<void> createUser(Map<String, dynamic> userData) async {
    await _db.collection('users').doc(userData['id']).set(userData);
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

  Future<void> updateUser({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('users').doc(userId).update(data);
  }

  // ---------------- ORDERS ----------------

  Future<void> createOrder({
    required String customerId,
    required String restaurantId,
    required double totalPrice,
  }) async {
    await _db.collection('orders').add({
      'customerId': customerId,
      'restaurantId': restaurantId,
      'driverId': null,
      'status': 'pending',
      'totalPrice': totalPrice,
      'createdAt': firestore.FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Order>> listenForPendingOrders() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList(),
        );
  }
  Future<Order> addOrder({
    required String customerId,
    required String restaurantId,
    required double totalPrice,
    required List<OrderItem> items,
  }) async {
    final orderId = IdGenerator.generateOrderId();
    final docRef = _db.collection('orders').doc(orderId);

    await docRef.set({
      'id': orderId,
      'customerId': customerId,
      'restaurantId': restaurantId,
      'driverId': null,
      'status': 'pending',
      'totalPrice': totalPrice,
      'createdAt': firestore.FieldValue.serverTimestamp(),
      'items': items.map((item) => item.toJson()).toList(),
      'customerLocation': const firestore.GeoPoint(2, 44),
      'restaurantLocation': const firestore.GeoPoint(2, 24),
    });

    final snapshot = await docRef.get();
    return Order.fromFirestore(snapshot);
  }
  
  Future<void> acceptOrder({
    required String orderId,
    required String driverId,
  }) async {
    final docRef = _db.collection("orders").doc(orderId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception("Order not found");
      }

      final data = snapshot.data() as Map<String, dynamic>;

      // check if order is already taken
      if (data['status'] != 'pending') {
        throw Exception(
          "Sorry! Another driver has already accepted this order.",
        );
      }
      transaction.update(docRef, {'driverId': driverId, 'status': 'accepted'});
    });
  }

  // ---------------- DELETE ----------------

  Future<void> deleteDocument({
    required String collection,
    required String docId,
  }) async {
    await _db.collection(collection).doc(docId).delete();
  }

  // ---------------- MAPPING ----------------

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


}
