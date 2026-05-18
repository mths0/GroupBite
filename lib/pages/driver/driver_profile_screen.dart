import 'package:flutter/material.dart';
import 'package:yjeek/auth_service.dart';
import 'package:yjeek/models/driver.dart';
import 'package:yjeek/pages/start_screen.dart';
import 'package:yjeek/pages/support/support_screen.dart';
import 'package:yjeek/widgets/confirm_dialog.dart';

class DriverProfileTab extends StatelessWidget {
  const DriverProfileTab({
    super.key,
    required this.driver,
  });

  final Driver driver;

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut = await showDestructiveConfirmDialog(
      context: context,
      title: 'Sign out?',
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

  void _openDriverInformation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DriverInformationPage(driver: driver),
      ),
    );
  }

  void _openSupport(BuildContext context) {
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                driver.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                driver.email,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _SectionCard(
          children: [
            _SectionRow(
              icon: Icons.person_outline,
              label: 'Driver Information',
              onTap: () => _openDriverInformation(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          children: [
            _SectionRow(
              icon: Icons.support_agent_outlined,
              label: 'Contact Support',
              onTap: () => _openSupport(context),
            ),
          ],
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () => _signOut(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            side: BorderSide(
              color: scheme.error.withValues(alpha: 0.45),
              width: 1.2,
            ),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            'Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: scheme.onSurfaceVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverInformationPage extends StatelessWidget {
  const _DriverInformationPage({required this.driver});

  final Driver driver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratingText = driver.ratingCount == 0
        ? 'No ratings yet'
        : '${driver.rating.toStringAsFixed(1)} (${driver.ratingCount} ratings)';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Driver Information',
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            _ReadOnlyField(
              label: 'Full Name',
              value: driver.name,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 18),
            _ReadOnlyField(
              label: 'Email Address',
              value: driver.email,
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 18),
            _ReadOnlyField(
              label: 'Phone Number',
              value: driver.phone,
              icon: Icons.phone_outlined,
            ),
            const SizedBox(height: 18),
            _ReadOnlyField(
              label: 'National ID',
              value: driver.nationalId,
              icon: Icons.fingerprint,
            ),
            const SizedBox(height: 18),
            _ReadOnlyField(
              label: 'Driver ID',
              value: driver.id,
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 18),
            _ReadOnlyField(
              label: 'Rating',
              value: ratingText,
              icon: Icons.star_outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
