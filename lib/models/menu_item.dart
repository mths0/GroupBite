import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery_platform/models/menu_item_option.dart';

enum MenuCategory {
  appetizers,
  mains,
  desserts,
  drinks,
}

class MenuItem {
  final String id;
  final String restaurantId;
  final String description;
  final String name;
  final double price;
  final String category;
  final bool isAvailable;
  final String imageUrl;
  final int calories;
  final List<MenuItemOptionGroup> optionGroups;

  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.price,
    required this.category,
    required this.isAvailable,
    required this.imageUrl,
    required this.description,
    required this.calories,
    required this.optionGroups,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "restaurantId": restaurantId,
    "name": name,
    "price": price,
    "description": description,
    "category": category,
    "isAvailable": isAvailable,
    "imageUrl": imageUrl,
    "calories": calories,
    'optionGroups': optionGroups.map((e) => e.toJson()).toList(),
  };

  factory MenuItem.fromMap(Map<dynamic, dynamic> map) {
    return MenuItem(
      id: (map["id"] ?? "").toString(),
      restaurantId: (map["restaurantId"] ?? "").toString(),
      name: (map["name"] ?? "").toString(),
      price: (map["price"] is num)
          ? (map["price"] as num).toDouble()
          : double.tryParse("${map["price"]}") ?? 0.0,
      category: (map["category"] ?? "Appetizers").toString(),
      isAvailable: (map["isAvailable"] ?? true) == true,
      description: (map['description'] ?? '').toString(),
      imageUrl: (map["imageUrl"] ?? "").toString(),
      calories: (map["calories"] is num)
          ? (map["calories"] as num).toInt()
          : int.tryParse("${map["calories"]}") ?? 0,
      optionGroups: (map['optionGroups'] as List<dynamic>? ?? [])
          .map((e) => MenuItemOptionGroup.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory MenuItem.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return MenuItem(
      id: doc.id,
      restaurantId: (data["restaurantId"] ?? "").toString(),
      name: (data["name"] ?? "").toString(),
      description: (data["description"] ?? "").toString(),
      price: (data["price"] is num)
          ? (data["price"] as num).toDouble()
          : double.tryParse("${data["price"]}") ?? 0.0,
      category: (data["category"] ?? "Appetizers").toString(),
      isAvailable: (data["isAvailable"] ?? true) == true,
      imageUrl: (data["imageUrl"] ?? "").toString(),
      calories: (data["calories"] is num)
          ? (data["calories"] as num).toInt()
          : int.tryParse("${data["calories"]}") ?? 0,
      optionGroups: (data['optionGroups'] as List<dynamic>? ?? [])
          .map((e) => MenuItemOptionGroup.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
