import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_controller.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/customer/customer_dashboard.dart';
import 'package:food_delivery_platform/pages/driver/driver_location_gate.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_dashboard.dart';

class RoleNavigator {
  static void navigate(BuildContext context, User user) {
    switch (user.role) {
      case UserRole.customer:
        final cartController = CartController();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => CartScope(
              notifier: cartController,
              child: CustomerDashboard(customer: user as Customer),
            ),
          ),
          (_) => false,
        );
        break;

      case UserRole.restaurant:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDashboard(restaurant: user as Restaurant),
          ),
          (_) => false,
        );
        break;

      case UserRole.driver:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DriverLocationGate(driver: user as Driver),
          ),
          (_) => false,
        );
        break;
    }
  }
}
