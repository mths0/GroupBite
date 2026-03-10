import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';

enum DriverStatus { available, busy, offline }

class Driver extends User {
  final String nationalId;
  final String createdAt;
  final GeoPoint? location;
  DriverStatus _status;

  Driver({
    required super.id,
    required super.name,
    required super.phone,
    required this.nationalId,
    required this.createdAt,
    DriverStatus status = DriverStatus.offline,
    this.location,
  }) : _status = status;

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'],
      phone: map['phone'],
      name: map['name'],
      nationalId: map['nationalId'],
      createdAt: map['createdAt'],
      status: DriverStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DriverStatus.offline,
      ),
      location: map['location'] as GeoPoint?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'nationalId': nationalId,
    'role': 'driver',
    'createdAt': createdAt,
    'status': _status.name,
    'location': location,
  };

  DriverStatus get status => _status;

  void updateStatus(DriverStatus newState) {
    _status = newState;
  }

  @override
  UserRole get role => UserRole.driver;

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
