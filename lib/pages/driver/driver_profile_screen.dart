import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:food_delivery_platform/pages/support/support_screen.dart';
import 'package:food_delivery_platform/widgets/confirm_dialog.dart';

class DriverProfileTab extends StatelessWidget {
  const DriverProfileTab({
    super.key,
    required this.driver,
  });

  final Driver driver;

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut = await showDestructiveConfirmDialog(
      context: context,
      title: 'Sign out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign out',
    );

    if (shouldSignOut != true) return;

    await AuthService().signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartScreen()),
      (route) => false,
    );
  }

  String _statusLabel(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return 'Available';
      case DriverStatus.busy:
        return 'Busy';
      case DriverStatus.offline:
        return 'Offline';
    }
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratingText = driver.ratingCount == 0
        ? 'No ratings yet'
        : '${driver.rating.toStringAsFixed(1)} (${driver.ratingCount} ratings)';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),

        Text(
          '${driver.name} Profile',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),

        _infoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: driver.email,
        ),
        _infoTile(
          icon: Icons.badge_outlined,
          label: 'Driver ID',
          value: driver.id,
        ),
        _infoTile(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: driver.phone,
        ),
        _infoTile(
          icon: Icons.fingerprint,
          label: 'National ID',
          value: driver.nationalId,
        ),
        _infoTile(
          icon: Icons.star_outline,
          label: 'Rating',
          value: ratingText,
        ),
        _infoTile(
          icon: Icons.circle_outlined,
          label: 'Status',
          value: _statusLabel(driver.status),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ),
        SizedBox(
          height: 50,
          child: TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupportScreen(
                    userId: driver.id,
                    userRole: 'driver',
                    userName: driver.name,
                    userEmail: driver.email,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.support_agent),
            label: const Text('Support'),
          ),
        ),
      ],
    );
  }
}
