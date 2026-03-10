import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
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
            stream: MockRestaurantRepository().restaurantSnapshot,
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
            HeaderCard(restaurant: restaurant),
          ],
        ),
      ),
    );
  }
}
