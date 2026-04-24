import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';

class Customer extends User {
  final String createdAt;
  final GeoPoint? location;

  Customer({
    required super.id,
    required super.name,
    required super.phone,
    required super.email,
    required this.createdAt,
    required this.location,

  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    final locationValue = map['location'];

    return Customer(
      id: (map['id'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      createdAt: (map['createdAt'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      location: locationValue is GeoPoint ? locationValue : null,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      phone: json['phone'],
      name: json['name'],
      createdAt: json['createdAt'],
      email: json['email'],
      location: json['location'] as GeoPoint?,
    );
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
  };

  @override
  UserRole get role => UserRole.customer;

  //TODO we will do it later
  @override
  Function login() {
    // TODO: implement login
    throw UnimplementedError();
  }

  @override
  Function logout() {
    // TODO: implement logout
    throw UnimplementedError();
  }

  @override
  Function updateProfile() {
    // TODO: implement updateProfile
    throw UnimplementedError();
  }
}
