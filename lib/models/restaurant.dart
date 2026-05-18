import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yjeek/models/abstract_user.dart';
import 'package:yjeek/models/restaurant_tag.dart';

class Restaurant extends User {
  final String createdAt;
  final GeoPoint? location;
  final String imageUrl;
  final double rating;
  final int ratingCount;
  final double deliveryFee;
  final List<RestaurantTag> tags;
  final bool isOpen;
  final bool hasOffer;

  Restaurant({
    required super.id,
    required super.name,
    required super.phone,
    required super.email,
    required this.createdAt,
    required this.location,
    required this.imageUrl,
    required this.rating,
    required this.ratingCount,
    required this.deliveryFee,
    required this.tags,
    required this.isOpen,
    required this.hasOffer,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    final locationValue = map['location'];
    final rawTags = List<String>.from(map['tags'] ?? []);

    return Restaurant(
      id: (map['id'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      createdAt: (map['createdAt'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      location: locationValue is GeoPoint ? locationValue : null,
      imageUrl: (map['imageUrl'] ?? '').toString(),
      rating: (map['rating'] ?? 0).toDouble(),
      ratingCount: (map['ratingCount'] ?? 0) as int,
      deliveryFee: (map['deliveryFee'] ?? 0).toDouble(),
      tags: rawTags
          .map((e) => RestaurantTagX.fromString(e))
          .whereType<RestaurantTag>()
          .toList(),
      isOpen: (map['isOpen'] ?? false) as bool,
      hasOffer: (map['hasOffer'] ?? false) as bool,
    );
  }

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant.fromMap(json);
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'role': role.name,
    'createdAt': createdAt,
    'email': email,
    'location': location,
    'imageUrl': imageUrl,
    'rating': rating,
    'ratingCount': ratingCount,
    'deliveryFee': deliveryFee,
    'tags': tags.map((e) => e.name).toList(),
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
