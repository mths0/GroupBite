import 'package:flutter/material.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/restaurant/menu_management_screen.dart';
import 'package:food_delivery_platform/pages/restaurant/promotions_screen.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_orders_dashboard.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_profile.dart';

/// Inline "Restaurant Name | GroupBite" header used at the top of every
/// restaurant dashboard tab. Mirrors the customer dashboard's per-tab headers.
class RestaurantPageHeader extends StatelessWidget {
  const RestaurantPageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'GroupBite',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
      ],
    );
  }
}

class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  int _navIndex = 0;
  final PageController _pageController = PageController();
  bool _isProgrammaticNav = false;

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

  void _goToPage(int index) async {
    setState(() {
      _navIndex = index;
      _isProgrammaticNav = true;
    });

    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    setState(() => _isProgrammaticNav = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (_isProgrammaticNav) return;
          setState(() => _navIndex = index);
        },
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          NavigationBar(
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
                label: 'Account',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
