import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/models/restaurant_tag.dart';

final List<User> mockUsers = [
  Customer(
    id: 'c1',
    name: 'Mohannad',
    phone: '512345678',
    createdAt: DateTime.now().toIso8601String(),
    email: 'mohannad@email.com',
    location: GeoPoint(24.7136, 46.6753),
  ),
  Driver(
    id: 'd1',
    name: 'Ahmed',
    phone: '598765432',
    nationalId: '1234567890',
    createdAt: DateTime.now().toIso8601String(),
    email: 'ahmed@email.com',
    rating: 4,
    ratingCount: 4,
  ),
  Restaurant(
    id: 'r1',
    name: 'Burger House',
    phone: '511111111',
    createdAt: DateTime.now().toIso8601String(),
    email: 'burger@restaurant.com',
    location: GeoPoint(24.7136, 46.6753),
    imageUrl: 'https://images.unsplash.com/photo-1550547660-d9450f859349',
    rating: 4.5,
    deliveryFee: 5.0,
    tags: [RestaurantTag.burger, RestaurantTag.fastFood],
    isOpen: true,
    hasOffer: true,
    ratingCount: 2,
  ),
];
