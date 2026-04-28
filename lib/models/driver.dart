import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';

enum DriverStatus { available, busy, offline }

class Driver extends User {
  final String nationalId;
  final String createdAt;
  final GeoPoint? location;
  final double rating;
  final int ratingCount;
  DriverStatus _status;

  Driver({
    required super.id,
    required super.name,
    required super.phone,
    required super.email,
    required this.nationalId,
    required this.createdAt,
    required this.rating,
    required this.ratingCount,
    DriverStatus status = DriverStatus.offline,
    this.location,
  }) : _status = status;

  factory Driver.fromMap(Map<String, dynamic> map) {
    final locationValue = map['location'];

    return Driver(
      id: (map['id'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      nationalId: (map['nationalId'] ?? '').toString(),
      createdAt: (map['createdAt'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      status: DriverStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DriverStatus.offline,
      ),
      location: locationValue is GeoPoint ? locationValue : null,
      rating: (map['rating'] ?? 0).toDouble(),
      ratingCount: (map['ratingCount'] ?? 0) as int,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'nationalId': nationalId,
    'role': UserRole.driver.name,
    'createdAt': createdAt,
    'status': _status.name,
    'location': location,
    'email': email,
    'rating': rating,
    'ratingCount': ratingCount,
  };

  DriverStatus get status => _status;

  void updateStatus(DriverStatus newState) {
    _status = newState;
  }

  @override
  UserRole get role => UserRole.driver;

  @override
  Function login() {
    throw UnimplementedError();
  }

  @override
  Function logout() {
    throw UnimplementedError();
  }

  @override
  Function updateProfile() {
    throw UnimplementedError();
  }
}
