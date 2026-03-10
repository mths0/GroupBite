import 'package:flutter/material.dart';

import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/restaurant/menu_management_screen.dart';
import 'package:food_delivery_platform/pages/restaurant/promotions_screen.dart';

//Todo change to be like customer dashboard with bottom nav and more sections like orders and profile
class RestaurantDashboard extends StatelessWidget {
  const RestaurantDashboard({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(restaurant.name),
            Text(
              "ID: ${restaurant.id}",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔹 Menu Management
          _DashboardCard(
            title: "Menu Management",
            subtitle: "Add, edit, or delete menu items",
            icon: Icons.restaurant_menu,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MenuManagementScreen(restaurant: restaurant),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 🔥 Promotions & Coupons
          _DashboardCard(
            title: "Promotions & Coupons",
            subtitle: "Create and manage discount offers",
            icon: Icons.local_offer,
            iconColor: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PromotionsScreen(restaurantId: restaurant.id),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 🔹 Orders
          _DashboardCard(
            title: "Orders",
            subtitle: "View and manage incoming orders (later)",
            icon: Icons.receipt_long,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Orders page (coming soon)")),
              );
            },
          ),

          const SizedBox(height: 12),

          // 🔹 Profile
          _DashboardCard(
            title: "Profile",
            subtitle: "Restaurant info and settings (later)",
            icon: Icons.store,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Profile page (coming soon)")),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: (iconColor ?? Theme.of(context).primaryColor)
              .withOpacity(0.1),
          child: Icon(icon, color: iconColor ?? Theme.of(context).primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}