import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerAddress {
  final String id;
  final String label;
  final String fullAddress;
  final String buildingDetails;
  final GeoPoint? location;
  final bool isDefault;

  const CustomerAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.buildingDetails,
    required this.location,
    required this.isDefault,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'fullAddress': fullAddress,
        'buildingDetails': buildingDetails,
        'location': location,
        'isDefault': isDefault,
      };

  factory CustomerAddress.fromMap(Map<String, dynamic> map) {
    return CustomerAddress(
      id: (map['id'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      fullAddress: (map['fullAddress'] ?? '').toString(),
      buildingDetails: (map['buildingDetails'] ?? '').toString(),
      location: map['location'] as GeoPoint?,
      isDefault: (map['isDefault'] ?? false) == true,
    );
  }
}