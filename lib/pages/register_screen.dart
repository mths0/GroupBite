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

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sign Up',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Text(
                'Create your account',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your role and enter your email.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'I am a',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.person_outline,
                      label: 'Customer',
                      selected: selectedRole == UserRole.customer,
                      onTap: () => setState(() {
                        selectedRole = UserRole.customer;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.storefront_outlined,
                      label: 'Restaurant',
                      selected: selectedRole == UserRole.restaurant,
                      onTap: () => setState(() {
                        selectedRole = UserRole.restaurant;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.local_shipping_outlined,
                      label: 'Driver',
                      selected: selectedRole == UserRole.driver,
                      onTap: () => setState(() {
                        selectedRole = UserRole.driver;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Email',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (_) {
                  if (errorText != null) {
                    setState(() => errorText = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: isLoading ? null : continueRegistration,
                  child: isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? Colors.transparent : scheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
