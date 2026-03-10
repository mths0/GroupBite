import 'package:flutter/material.dart';
import 'package:food_delivery_platform/models/customer.dart';

import 'package:food_delivery_platform/pages/customer/customer_home_screen.dart';
import 'package:food_delivery_platform/pages/customer/customer_orders_screen.dart';
import 'package:food_delivery_platform/pages/customer/customer_profile_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key, required this.customer});
  final Customer customer;

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  
  int _navIndex = 0;
  final PageController _pageController = PageController();

  late final List<Widget> _screens = [
    CustomerHomeScreen(customer: widget.customer),
    const CustomerOrdersScreen(),
    const CustomerProfileScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.customer.name}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Riyadh, Al Olaya',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              child: Text(
                'A',
                style: TextStyle(color: scheme.onPrimary),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _navIndex = index),
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (index) {
          setState(() {
            _navIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  
}

//Todo Add distance from user to restaurant and add sorting by distance and rating and by offers
class RestaurantItem {
  final String id;
  final String name;
  final double rating;
  final String deliveryTime;
  final String deliveryFee;
  final List<String> tags;
  final String imageUrl;
  final bool isOpen;
  final bool hasOffer;

  const RestaurantItem({
    required this.id,
    required this.name,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.tags,
    required this.imageUrl,
    required this.isOpen,
    required this.hasOffer,
  });
}
