import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/models/restaurant_tag.dart';

class MockRestaurantRepository {
  Stream<List<Restaurant>> get restaurantSnapshot async* {
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simulate network delay
    yield _dummyData;
  }

  final List<Restaurant> _dummyData = [
    Restaurant(
      id: 'r1',
      name: 'The Burger Joint',
      imageUrl:
          'https://images.unsplash.com/photo-1527025047-354c31c26312?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NHx8cmVzdGF1cmFudCUyMGxvZ298ZW58MHx8MHx8fDA%3D',
      rating: 4.5,

      deliveryFee: 0,
      tags: [RestaurantTag.burger, RestaurantTag.fastFood],
      isOpen: true,
      hasOffer: false,
      phone: '',
      createdAt: '',
      email: '',
      location: GeoPoint(24.7136, 46.6753),
      ratingCount: 3,
    ),
    Restaurant(
      id: 'r2',
      name: 'Sushi Zen',
      imageUrl:
          'https://plus.unsplash.com/premium_photo-1668902224065-2fa295ec3a21?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OXx8cmVzdGF1cmFudCUyMGxvZ298ZW58MHx8MHx8fDA%3D',
      rating: 3.5,
      deliveryFee: 10,
      tags: [RestaurantTag.breakfast, RestaurantTag.healthy],
      isOpen: true,
      hasOffer: false,
      phone: '',
      createdAt: '',
      email: '',
      ratingCount: 3,

      location: GeoPoint(24.7136, 46.6753),
    ),
    Restaurant(
      id: 'r2',
      name: 'Sushi Zen',
      imageUrl: 'https://via.placeholder.com/300x200?text=Sushi+Zen',
      rating: 3.5,
      ratingCount: 3,
      deliveryFee: 10,
      tags: [RestaurantTag.sushi, RestaurantTag.japanese],
      isOpen: false,
      hasOffer: false,
      phone: '',
      createdAt: '',
      email: '',
      location: GeoPoint(24.7136, 46.6753),
    ),
    Restaurant(
      id: 'r2',
      name: 'Sushi Zen',
      imageUrl: 'https://via.placeholder.com/300x200?text=Sushi+Zen',
      rating: 3.5,
      deliveryFee: 10,
      tags: [RestaurantTag.sushi, RestaurantTag.japanese, RestaurantTag.other],
      isOpen: true,
      hasOffer: false,
      phone: '',
      ratingCount: 3,
      createdAt: '',
      email: '',
      location: GeoPoint(24.7136, 46.6753),
    ),
    Restaurant(
      id: 'r2',
      name: 'Sushi Zen',
      imageUrl: 'https://via.placeholder.com/300x200?text=Sushi+Zen',
      rating: 3.5,
      ratingCount: 3,
      deliveryFee: 10,
      tags: [RestaurantTag.sushi, RestaurantTag.japanese],
      isOpen: true,
      hasOffer: false,
      phone: '',
      createdAt: '',
      email: '',
      location: GeoPoint(24.7136, 46.6753),
    ),
  ];
}
