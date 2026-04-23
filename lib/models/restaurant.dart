import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';

class Restaurant extends User {
  final String createdAt;
  final GeoPoint? location;
  final String imageUrl;
  final double rating;
  final double deliveryFee;
  final String type;
  //Todo tags will replace type
  final List<String> tags;
  final bool isOpen;
  final bool hasOffer;

  Restaurant({
    required super.id,
    required super.name,
    required super.phone,
    required super.email,
    required this.createdAt,
    required this.type,
    required this.location,
    required this.imageUrl,
    required this.rating,
    required this.deliveryFee,
    required this.tags,
    required this.isOpen,
    required this.hasOffer,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    final locationValue = map['location'];

    return Restaurant(
      id: (map['id'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      createdAt: (map['createdAt'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      location: locationValue is GeoPoint ? locationValue : null,
      imageUrl: (map['imageUrl'] ?? '').toString(),
      rating: (map['rating'] ?? 0).toDouble(),
      deliveryFee: (map['deliveryFee'] ?? 0).toDouble(),
      tags: List<String>.from(map['tags'] ?? []),
      isOpen: (map['isOpen'] ?? false) as bool,
      hasOffer: (map['hasOffer'] ?? false) as bool,
    );
  }

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant.fromMap(json);
  }

  // Convert Restaurant to JSON for Firestore
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'role': 'restaurant',
    'createdAt': createdAt,
    'email': email,
    'type': type,
    'location': location,
    'imageUrl': imageUrl,
    'rating': rating,
    'deliveryFee': deliveryFee,
    'tags': tags,
    'isOpen': isOpen,
    'hasOffer': hasOffer,
  };

  @override
  UserRole get role => UserRole.restaurant;

  @override
  Function login() =>
      () => throw UnimplementedError();

  @override
  Function logout() =>
      () => throw UnimplementedError();

  @override
  Function updateProfile() =>
      () => throw UnimplementedError();
}

