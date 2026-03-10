import 'package:flutter/material.dart';

import 'package:food_delivery_platform/components/role_button_widget.dart';
import 'package:food_delivery_platform/pages/customer/customer_register_screen.dart';
import 'package:food_delivery_platform/pages/driver/driver_register_screen.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_register_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.food_bank,
                size: 100,
              ),
              SizedBox(
                height: 16,
              ),

              Text(
                "Choose how you want to use FoodFlow",
                style: TextStyle(fontSize: 15),
              ),
              SizedBox(
                height: 16,
              ),
              RoleButton(
                icon: Icons.person_outlined,
                iconBgColor: const Color.fromRGBO(255, 205, 210, 1),
                iconColor: Colors.red,
                title: "Customer",
                subtitle: "Order food from your favorite restaurants",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerRegisterScreen(),
                    ),
                  );
                },
              ),
              RoleButton(
                icon: Icons.food_bank_outlined,
                iconBgColor: Colors.green.shade100,
                iconColor: Colors.green,
                title: "Restaurant",
                subtitle: "Manage your restaurant and receive orders",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantRegisterScreen(),
                    ),
                  );
                },
              ),
              RoleButton(
                icon: Icons.local_shipping_outlined,
                iconBgColor: Colors.blue.shade50,
                iconColor: Colors.blue,
                title: 'Driver',
                subtitle: 'Deliver orders and earn money',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverRegisterScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
