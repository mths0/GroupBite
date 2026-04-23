import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/pages/customer/customer_register_screen.dart';
import 'package:food_delivery_platform/pages/driver/driver_register_screen.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_register_screen.dart';
import 'package:food_delivery_platform/utils/validators.dart';

enum UserRole {
  customer,
  restaurant,
  driver,
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();

  UserRole selectedRole = UserRole.customer;
  String? errorText;
  bool isLoading = false;

  Future<void> continueRegistration() async {
    final email = emailController.text.trim();

    final validationError = Validators.validateEmail(email);
    if (validationError != null) {
      setState(() {
        errorText = validationError;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final db = DatabaseService();
      final existingUser = await db.getUserByEmail(email);

      if (existingUser != null) {
        setState(() {
          errorText = 'This email is already registered. Please login.';
          isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      switch (selectedRole) {
        case UserRole.customer:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerRegisterScreen(email: email),
            ),
          );
          break;

        case UserRole.restaurant:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantRegisterScreen(email: email),
            ),
          );
          break;

        case UserRole.driver:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverRegisterScreen(email: email),
            ),
          );
          break;
      }
    } catch (e) {
      setState(() {
        errorText = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String roleLabel(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.restaurant:
        return 'Restaurant';
      case UserRole.driver:
        return 'Driver';
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Icon(
                  Icons.food_bank,
                  size: 100,
                ),
                const SizedBox(height: 16),

                const Text(
                  "Create your account",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  "Enter your email and choose your role",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'example@gmail.com',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: UserRole.values.map((role) {
                    IconData icon;

                    switch (role) {
                      case UserRole.customer:
                        icon = Icons.person_outline;
                        break;
                      case UserRole.restaurant:
                        icon = Icons.storefront_outlined;
                        break;
                      case UserRole.driver:
                        icon = Icons.local_shipping_outlined;
                        break;
                    }

                    return DropdownMenuItem<UserRole>(
                      value: role,
                      child: Row(
                        children: [
                          Icon(icon, size: 20),
                          const SizedBox(width: 10),
                          Text(roleLabel(role)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedRole = value;
                    });
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: isLoading ? null : continueRegistration,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Continue',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
