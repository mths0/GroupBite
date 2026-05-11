import 'package:flutter/material.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/restaurant/menu_management_screen.dart';
import 'package:food_delivery_platform/pages/restaurant/promotions_screen.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_orders_dashboard.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_profile.dart';

class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  int _navIndex = 0;
  final PageController _pageController = PageController();

  late final List<Widget> _screens = [
    MenuManagementScreen(restaurant: widget.restaurant),
    PromotionsScreen(restaurantId: widget.restaurant.id),
    RestaurantOrdersDashboard(restaurantId: widget.restaurant.id),
    RestaurantProfile(restaurant: widget.restaurant),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    setState(() {
      _navIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          widget.restaurant.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _navIndex = index),
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _goToPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Promotions',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}


