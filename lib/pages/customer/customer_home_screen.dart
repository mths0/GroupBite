import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/mock/mock_restaurant_repository.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/customer/restaurant_menu_page.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, required this.customer});
  final Customer customer;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          buildSearchBar(),
          const SizedBox(height: 16),
          Text(
          //Todo : Get user location and show nearby restaurants (later)
            'Restaurants Near You',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Restaurant>>(
            stream: DatabaseService().getRestaurants(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text("No Data found"),
                );
              }

              final query = _searchController.text.toLowerCase();
              // Filter restaurants based on name or tags
              final filteredRestaurants = snapshot.data!.where((r) {
                final nameMatch = r.name.toLowerCase().contains(query);
                final tagMatch = r.tags.any(
                  (food) => food.toLowerCase().contains(query),
                );
                return nameMatch || tagMatch;
              }).toList();

              if (filteredRestaurants.isEmpty) {
                return Center(
                  child: Text("No restaurants match your search."),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRestaurants.length,
                itemBuilder: (context, index) {
                  return buildRestaurantCard(
                    filteredRestaurants[index],
                    scheme,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search for restaurants or food...',
      ),
    );
  }

  Widget buildRestaurantCard(Restaurant restaurant, ColorScheme scheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final cart = CartScope.of(context);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CartScope(
              notifier: cart,
              child: RestaurantMenuPage(restaurant: restaurant),
            ),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    restaurant.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 160,
                      color: scheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Row(
                    children: [
                      if (restaurant.hasOffer)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Offer',
                            style: TextStyle(color: scheme.onSecondary),
                          ),
                        ),
                      if (restaurant.hasOffer) const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: restaurant.isOpen
                              ? Colors.green
                              : scheme.outline,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          restaurant.isOpen ? 'Open' : 'Closed',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(restaurant.rating.toStringAsFixed(1)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text(_estimateDeliveryTime(restaurant)),
                      const SizedBox(width: 12),
                      const Icon(Icons.attach_money, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.deliveryFee == 0
                            ? 'Free'
                            : '${restaurant.deliveryFee.toStringAsFixed(0)} SAR',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: restaurant.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(tag),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _estimateDeliveryTime(Restaurant restaurant) {
    if (!restaurant.isOpen) {
      return 'Unavailable';
    }

    if (restaurant.deliveryFee == 0) {
      return '20-25 min';
    }

    if (restaurant.deliveryFee <= 10) {
      return '25-30 min';
    }

    return '30-40 min';
  }
}
