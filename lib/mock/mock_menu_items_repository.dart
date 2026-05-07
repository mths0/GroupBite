// import 'package:food_delivery_platform/models/menu_item.dart';

// abstract class MenuRepository {
//   Future<List<MenuItem>> getMenuForRestaurant(String restaurantId);
// }

// class StaticMenuRepository implements MenuRepository {
//   @override
//   Future<List<MenuItem>> getMenuForRestaurant(String restaurantId) async {
//     // تقدر لاحقاً تخلي القائمة تختلف حسب restaurantId
//     return _items.where((item) => item.restaurantId == restaurantId).toList();
//   }

//   static const List<MenuItem> _items = [
//     // ===================== r1 =====================

//     // Appetizers
//     MenuItem(
//       id: 'r1_a1',
//       restaurantId: 'r1',
//       name: 'Bruschetta',
//       description: 'Toasted bread with fresh tomatoes and basil',
//       price: 25.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1594978583693-8dfdfc93f052?w=900',
//       category: 'Appetizers',
//       isAvailable: true,
//       calories: 150,
//       optionGroups: ['Bread', 'Tomatoes', 'Basil'],
//     ),
//     MenuItem(
//       id: 'r1_a2',
//       restaurantId: 'r1',
//       name: 'Mozzarella Sticks',
//       description: 'Crispy fried mozzarella with marinara sauce',
//       price: 28.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1734774924912-dcbb467f8599?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8TW96emFyZWxsYSUyMFN0aWNrc3xlbnwwfHwwfHx8MA%3D%3D',
//       category: 'Appetizers',
//       isAvailable: true,
//       calories: 200,
//     ),

//     // Desserts
//     MenuItem(
//       id: 'r1_d1',
//       restaurantId: 'r1',
//       name: 'Cheesecake',
//       description: 'Creamy cheesecake with strawberry topping',
//       price: 24.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1695088957420-c3b97d1f1138?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8N3x8Q2hlZXNlY2FrZXxlbnwwfHwwfHx8MA%3D%3D',
//       category: 'Desserts',
//       isAvailable: true,
//       calories: 350,
//     ),
//     MenuItem(
//       id: 'r1_d2',
//       restaurantId: 'r1',
//       name: 'Chocolate Cake',
//       description: 'Rich chocolate cake slice',
//       price: 22.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8M3x8Q2hvY29sYXRlJTIwQ2FrZXxlbnwwfHwwfHx8MA%3D%3D',
//       category: 'Desserts',
//       isAvailable: true,
//       calories: 400,
//     ),

//     // Drinks
//     MenuItem(
//       id: 'r1_dr1',
//       restaurantId: 'r1',
//       name: 'Iced Latte',
//       description: 'Cold coffee with milk and ice',
//       price: 18.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?w=900',
//       category: 'Drinks',
//       isAvailable: true,
//       calories: 120,
//     ),
//     MenuItem(
//       id: 'r1_dr2',
//       restaurantId: 'r1',
//       name: 'Mint Lemonade',
//       description: 'Refreshing lemonade with fresh mint',
//       price: 16.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1560351520-48e05f3d7d16?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTh8fE1pbnQlMjBMZW1vbmFkZXxlbnwwfHwwfHx8MA%3D%3D',
//       category: 'Drinks',
//       isAvailable: true,
//       calories: 80,
//     ),

//     // Mains
//     MenuItem(
//       id: 'r1_m1',
//       restaurantId: 'r1',
//       name: 'Beef Burger',
//       description: 'Juicy grilled beef burger with cheddar cheese',
//       price: 48.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1550547660-d9450f859349?w=900',
//       category: 'Mains',
//       isAvailable: true,
//       calories: 820,
//     ),
//     MenuItem(
//       id: 'r1_m2',
//       restaurantId: 'r1',
//       name: 'Margherita Pizza',
//       description: 'Classic pizza with tomato, mozzarella, and basil',
//       price: 45.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1598023696416-0193a0bcd302?w=900',
//       category: 'Mains',
//       isAvailable: true,
//       calories: 700,
//     ),

//     // ===================== r2 =====================

//     // Appetizers
//     MenuItem(
//       id: 'r2_a1',
//       restaurantId: 'r2',
//       name: 'Caesar Salad',
//       description: 'Fresh romaine lettuce with parmesan and croutons',
//       price: 30.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?w=900',
//       category: 'Appetizers',
//       isAvailable: true,
//       calories: 220,
//     ),
//     MenuItem(
//       id: 'r2_a2',
//       restaurantId: 'r2',
//       name: 'Sushi Platter',
//       description: 'Baked mushrooms filled with cheese and herbs',
//       price: 32.0,
//       imageUrl:
//           'https://plus.unsplash.com/premium_photo-1668146927669-f2edf6e86f6f?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8c3VzaGl8ZW58MHx8MHx8fDA%3D',
//       category: 'Appetizers',
//       isAvailable: true,
//       calories: 300,
//     ),

//     // Desserts
//     MenuItem(
//       id: 'r2_d1',
//       restaurantId: 'r2',
//       name: 'Ice Cream Sundae',
//       description: 'Vanilla ice cream with chocolate syrup and nuts',
//       price: 20.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=900',
//       category: 'Desserts',
//       isAvailable: true,
//       calories: 420,
//     ),
//     MenuItem(
//       id: 'r2_d2',
//       restaurantId: 'r2',
//       name: 'Tiramisu',
//       description: 'Classic Italian dessert with espresso flavor',
//       price: 26.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=900',
//       category: 'Desserts',
//       isAvailable: true,
//       calories: 360,
//     ),

//     // Drinks
//     MenuItem(
//       id: 'r2_dr1',
//       restaurantId: 'r2',
//       name: 'Fresh Orange Juice',
//       description: 'Freshly squeezed orange juice',
//       price: 15.0,
//       imageUrl:
//           'https://plus.unsplash.com/premium_photo-1667543228378-ec4478ab2845?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NXx8RnJlc2glMjBPcmFuZ2UlMjBKdWljZXxlbnwwfHwwfHx8MA%3D%3D',
//       category: 'Drinks',
//       isAvailable: true,
//       calories: 110,
//     ),
//     MenuItem(
//       id: 'r2_dr2',
//       restaurantId: 'r2',
//       name: 'Strawberry Smoothie',
//       description: 'Creamy strawberry smoothie with yogurt',
//       price: 19.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8U3RyYXdiZXJyeSUyMFNtb290aGllfGVufDB8fDB8fHww',
//       category: 'Drinks',
//       isAvailable: true,
//       calories: 210,
//     ),

//     // Mains
//     MenuItem(
//       id: 'r2_m1',
//       restaurantId: 'r2',
//       name: 'Chicken Pasta',
//       description: 'Creamy sauce pasta with grilled chicken',
//       price: 55.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1638890763825-e20495f6b819?w=900',
//       category: 'Mains',
//       isAvailable: true,
//       calories: 650,
//     ),
//     MenuItem(
//       id: 'r2_m2',
//       restaurantId: 'r2',
//       name: 'Grilled Salmon',
//       description: 'Fresh salmon fillet with lemon butter sauce',
//       price: 70.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1544025162-d76694265947?w=900',
//       category: 'Mains',
//       isAvailable: true,
//       calories: 540,
//     ),

//     // ===================== r3 =====================

//     // Appetizers
//     MenuItem(
//       id: 'r3_a1',
//       restaurantId: 'r3',
//       name: 'Garlic Bread',
//       description: 'Toasted bread with garlic butter',
//       price: 20.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1573140401552-3fab0b24306f?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8R2FybGljJTIwQnJlYWR8ZW58MHx8MHx8fDA%3D',
//       category: 'Appetizers',
//       isAvailable: true,
//       calories: 240,
//     ),
//     MenuItem(
//       id: 'r3_a2',
//       restaurantId: 'r3',
//       name: 'Onion Rings',
//       description: 'Crispy fried onion rings',
//       price: 22.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1639024471283-03518883512d?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8T25pb24lMjBSaW5nc3xlbnwwfHwwfHx8MA%3D%3D',
//       category: 'Appetizers',
//       isAvailable: true,
//       calories: 320,
//     ),

//     // Desserts
//     MenuItem(
//       id: 'r3_d1',
//       restaurantId: 'r3',
//       name: 'Brownie',
//       description: 'Warm chocolate brownie with vanilla ice cream',
//       price: 23.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1636743715220-d8f8dd900b87?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8QnJvd25pZXxlbnwwfHwwfHx8MA%3D%3D',
//       category: 'Desserts',
//       isAvailable: true,
//       calories: 450,
//     ),
//     MenuItem(
//       id: 'r3_d2',
//       restaurantId: 'r3',
//       name: 'Pancakes',
//       description: 'Fluffy pancakes with maple syrup',
//       price: 27.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8UGFuY2FrZXN8ZW58MHx8MHx8fDA%3D',
//       category: 'Desserts',
//       isAvailable: true,
//       calories: 520,
//     ),

//     // Drinks
//     MenuItem(
//       id: 'r3_dr1',
//       restaurantId: 'r3',
//       name: 'Cappuccino',
//       description: 'Hot espresso with steamed milk foam',
//       price: 17.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=900',
//       category: 'Drinks',
//       isAvailable: true,
//       calories: 110,
//     ),
//     MenuItem(
//       id: 'r3_dr2',
//       restaurantId: 'r3',
//       name: 'Mango Smoothie',
//       description: 'Fresh mango blended smoothie',
//       price: 20.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1497534446932-c925b458314e?w=900',
//       category: 'Drinks',
//       isAvailable: true,
//       calories: 200,
//     ),

//     // Mains
//     MenuItem(
//       id: 'r3_m1',
//       restaurantId: 'r3',
//       name: 'BBQ Chicken Wings',
//       description: 'Smoky BBQ wings with house sauce',
//       price: 40.0,
//       imageUrl:
//           'https://plus.unsplash.com/premium_photo-1672498193267-4f0e8c819bc8?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8QkJRJTIwQ2hpY2tlbiUyMFdpbmdzfGVufDB8fDB8fHww',
//       category: 'Mains',
//       isAvailable: true,
//       calories: 680,
//     ),
//     MenuItem(
//       id: 'r3_m2',
//       restaurantId: 'r3',
//       name: 'Steak Sandwich',
//       description: 'Grilled steak sandwich with caramelized onions',
//       price: 60.0,
//       imageUrl:
//           'https://images.unsplash.com/photo-1667055251919-88fd6ff02e86?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8U3RlYWslMjBTYW5kd2ljaHxlbnwwfHwwfHx8MA%3D%3D',
//       category: 'Mains',
//       isAvailable: true,
//       calories: 760,
//     ),
//   ];
// }
