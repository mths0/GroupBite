import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer.dart';

final List<Customer> mockCustomers = [
  Customer(
    id: 'c1',
    name: 'Mohannad Alshahrani',
    phone: '582265991',
    createdAt: DateTime.now().toIso8601String(),
    email: 'mohannad@email.com',
    location: GeoPoint(24.7136, 46.6753),
  ),
  Customer(
    id: 'c2',
    name: 'Majed Alotaibi',
    phone: '569876543',
    createdAt: DateTime.now().toIso8601String(),
    email: 'majed@email.com',
    location: GeoPoint(24.7136, 46.6753),
  ),
  Customer(
    id: 'c3',
    name: 'Khaled Alshehri',
    phone: '541122334',
    createdAt: DateTime.now().toIso8601String(),
    email: 'khaled@email.com',
    location: GeoPoint(24.7136, 46.6753),
  ),
];
