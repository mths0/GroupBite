import 'package:flutter/material.dart';
import 'package:yjeek/cart/cart_controller.dart';
import 'package:yjeek/cart/cart_scope.dart';
import 'package:yjeek/models/abstract_user.dart';
import 'package:yjeek/models/customer.dart';
import 'package:yjeek/models/driver.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/pages/customer/customer_dashboard.dart';
import 'package:yjeek/pages/driver/driver_location_gate.dart';
import 'package:yjeek/pages/restaurant/restaurant_dashboard.dart';

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
