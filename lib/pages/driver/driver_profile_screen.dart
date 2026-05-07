import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';

class DriverProfileTab extends StatelessWidget {
  const DriverProfileTab({
    super.key,
    required this.driver,
  });

  final Driver driver;

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Center(child: const Text('Cancel')),
            ),
          ],
        );
      },
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
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      ),
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
        const SizedBox(height: 12),
        Center(
          child: Text(
            driver.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Driver Account',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 20),

        _infoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: driver.email,
        ),
        _infoTile(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: driver.phone,
        ),
        _infoTile(
          icon: Icons.badge_outlined,
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

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }
}
