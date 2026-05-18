import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/customer_address.dart';
import 'package:food_delivery_platform/models/saved_card.dart';
import 'package:food_delivery_platform/pages/customer/add_funds_sheet.dart';
import 'package:food_delivery_platform/pages/customer/add_address_screen.dart';
import 'package:food_delivery_platform/pages/customer/card_form_sheet.dart';
import 'package:food_delivery_platform/pages/customer/family_wallet_tab.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:food_delivery_platform/pages/support/support_screen.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';
import 'package:food_delivery_platform/widgets/confirm_dialog.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.customer,
    this.onDefaultAddressChanged,
  });

  final Customer customer;
  final VoidCallback? onDefaultAddressChanged;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final DatabaseService _db = DatabaseService();
  Customer? _customer;
  StreamSubscription<Customer?>? _customerSub;

  Customer get _current => _customer ?? widget.customer;

  @override
  void initState() {
    super.initState();
    _customerSub = _db.streamCustomerById(widget.customer.id).listen((c) {
      if (!mounted || c == null) return;
      setState(() => _customer = c);
    });
  }

  @override
  void dispose() {
    _customerSub?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDestructiveConfirmDialog(
      context: context,
      title: 'Sign out?',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign out',
    );

    if (shouldSignOut != true) return;

    try {
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StartScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign out: $e')),
      );
    }
  }

  void _openPersonalInformation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PersonalInformationPage(customer: _current),
      ),
    );
  }

  void _openSavedAddresses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _SavedAddressesPage(
              customerId: _current.id,
              onDefaultAddressChanged: widget.onDefaultAddressChanged,
            ),
      ),
    );
  }

  void _openPaymentMethods() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PaymentMethodsPage(
              customerId: _current.id,
              customerName: _current.name,
            ),
      ),
    );
  }

  void _openSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SupportScreen(
              userId: _current.id,
              userRole: 'customer',
              userName: _current.name,
              userEmail: _current.email,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Text(
                  'Account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
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
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        _current.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _current.email,
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
                      label: 'Account Information',
                      onTap: _openPersonalInformation,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _SectionCard(
                  children: [
                    _SectionRow(
                      icon: Icons.location_on_outlined,
                      label: 'Saved Addresses',
                      onTap: _openSavedAddresses,
                    ),
                    const _SectionRowDivider(),
                    _SectionRow(
                      icon: Icons.credit_card_outlined,
                      label: 'Payment Methods',
                      onTap: _openPaymentMethods,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _SectionCard(
                  children: [
                    _SectionRow(
                      icon: Icons.support_agent_outlined,
                      label: 'Contact Support',
                      onTap: _openSupport,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                OutlinedButton.icon(
                  onPressed: _signOut,
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
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Section primitives
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: scheme.onSurface),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionRowDivider extends StatelessWidget {
  const _SectionRowDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: scheme.outlineVariant,
    );
  }
}

// =============================================================================
// Personal Information page
// =============================================================================

class _PersonalInformationPage extends StatefulWidget {
  const _PersonalInformationPage({required this.customer});

  final Customer customer;

  @override
  State<_PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<_PersonalInformationPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;
  String? _phoneError;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone);
    _nameController.addListener(() {
      if (_nameError != null && _nameController.text
          .trim()
          .isNotEmpty) {
        setState(() => _nameError = null);
      }
    });
    _phoneController.addListener(() {
      if (_phoneError != null) setState(() => _phoneError = null);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    String? nameError;
    String? phoneError;
    if (name.isEmpty) nameError = 'Enter your name';
    if (phone.isEmpty) {
      phoneError = 'Enter a phone number';
    } else if (phone.length != 9) {
      phoneError = 'Phone number must be 9 digits';
    }

    if (nameError != null || phoneError != null) {
      setState(() {
        _nameError = nameError;
        _phoneError = phoneError;
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.customer.id)
          .update({
        'name': name,
        'phone': phone,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account Information',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                children: [
                  _LabeledField(
                    label: 'Full Name',
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: _nameError,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _LabeledField(
                    label: 'Email Address',
                    child: TextField(
                      controller: TextEditingController(
                        text: widget.customer.email,
                      ),
                      enabled: false,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: scheme.surfaceContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _LabeledField(
                    label: 'Phone Number',
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 9,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone_outlined),
                        errorText: _phoneError,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _LabeledField(
                    label: 'Customer ID',
                    child: TextField(
                      controller: TextEditingController(
                        text: widget.customer.id,
                      ),
                      enabled: false,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined),
                        filled: true,
                        fillColor: scheme.surfaceContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                      : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

// =============================================================================
// Saved Addresses page
// =============================================================================

class _SavedAddressesPage extends StatefulWidget {
  const _SavedAddressesPage({
    required this.customerId,
    this.onDefaultAddressChanged,
  });

  final String customerId;
  final VoidCallback? onDefaultAddressChanged;

  @override
  State<_SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<_SavedAddressesPage> {
  final DatabaseService _db = DatabaseService();

  Future<void> _addNew() async {
    await Navigator.push<CustomerAddress>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddAddressScreen(
              onSubmit: (address) async {
                await _db.addCustomerAddress(
                  customerId: widget.customerId,
                  address: address,
                );
                if (address.isDefault) {
                  await _db.setDefaultCustomerAddress(
                    customerId: widget.customerId,
                    addressId: address.id,
                  );
                  widget.onDefaultAddressChanged?.call();
                }
              },
            ),
      ),
    );
  }

  Future<void> _edit(CustomerAddress address) async {
    await Navigator.push<CustomerAddress>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddAddressScreen(
              existing: address,
              onSubmit: (updated) async {
                await _db.updateCustomerAddress(
                  customerId: widget.customerId,
                  address: updated,
                );
                if (updated.isDefault && !address.isDefault) {
                  await _db.setDefaultCustomerAddress(
                    customerId: widget.customerId,
                    addressId: updated.id,
                  );
                  widget.onDefaultAddressChanged?.call();
                }
              },
            ),
      ),
    );
  }

  Future<void> _delete(CustomerAddress address,
      List<CustomerAddress> all) async {
    if (all.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must keep at least one delivery address.'),
        ),
      );
      return;
    }
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Delete address?',
      message: 'Remove "${address.label}" from your addresses?',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) return;

    String? newDefaultId;
    if (address.isDefault) {
      final remaining = all.where((a) => a.id != address.id).toList();
      newDefaultId = remaining.isNotEmpty ? remaining.first.id : null;
    }
    try {
      await _db.deleteCustomerAddress(
        customerId: widget.customerId,
        addressId: address.id,
      );
      if (newDefaultId != null) {
        await _db.setDefaultCustomerAddress(
          customerId: widget.customerId,
          addressId: newDefaultId,
        );
        widget.onDefaultAddressChanged?.call();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved Addresses',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<CustomerAddress>>(
                stream: _db.streamCustomerAddresses(widget.customerId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final addresses = snap.data ?? const <CustomerAddress>[];
                  if (addresses.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No addresses yet. Add one below.'),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final a = addresses[i];
                      return _AddressTile(
                        address: a,
                        onEdit: () => _edit(a),
                        onDelete: () => _delete(a, addresses),
                      );
                    },
                  );
                },
              ),
            ),
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _addNew,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text(
                    'Add new address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomerAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: address.isDefault ? scheme.primary : scheme.outlineVariant,
            width: address.isDefault ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.isDefault) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Default',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    address.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.fullAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _IconAction(
              icon: Icons.delete_outline_rounded,
              color: scheme.error,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// =============================================================================
// Payment Methods page
// =============================================================================

class _PaymentMethodsPage extends StatefulWidget {
  const _PaymentMethodsPage({
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<_PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<_PaymentMethodsPage> {
  final DatabaseService _db = DatabaseService();

  Future<void> _showAddFunds() async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddFundsSheet(customerId: widget.customerId),
    );
    if (amount == null || amount <= 0) return;
    try {
      await _db.addFundsToWallet(
        customerId: widget.customerId,
        amount: amount,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add funds: $e')),
      );
    }
  }

  Future<void> _addCard({required bool hasExistingCard}) async {
    final result = await showModalBottomSheet<CardInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CardFormSheet(),
    );
    if (result == null) return;
    final card = SavedCard(
      id: IdGenerator.generateCardId(),
      last4: SavedCard.last4FromNumber(result.number),
      expiry: result.expiry,
      holderName: result.holderName,
      isDefault: !hasExistingCard,
    );
    try {
      await _db.addCustomerCard(customerId: widget.customerId, card: card);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save card: $e')),
      );
    }
  }

  Future<void> _deleteCard(SavedCard card) async {
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Delete card?',
      message:
      'Remove card ending in ${card.last4} from your payment methods?',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) return;
    try {
      await _db.deleteCustomerCard(
        customerId: widget.customerId,
        cardId: card.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete card: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Payment Methods',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(height: 1, color: scheme.outlineVariant),
                TabBar(
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  indicatorColor: scheme.primary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  tabs: const [
                    Tab(text: 'Personal'),
                    Tab(text: 'Family Wallet'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  StreamBuilder<double>(
                    stream: _db.streamWalletBalance(widget.customerId),
                    builder: (context, snap) {
                      final balance = snap.data ?? 0.0;
                      return _WalletCard(
                        label: 'PERSONAL WALLET',
                        balance: balance,
                        onAddFunds: _showAddFunds,
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel(label: 'SAVED CARDS'),
                  const SizedBox(height: 10),
                  StreamBuilder<List<SavedCard>>(
                    stream: _db.streamCustomerCards(widget.customerId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final cards = snap.data ?? [];
                      if (cards.isEmpty) {
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _addCard(hasExistingCard: false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: BorderSide(color: scheme.outlineVariant),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.add_card),
                            label: const Text(
                              'Add Card',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      }
                      final card = cards.first;
                      return Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: scheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.credit_card,
                            color: scheme.primary,
                          ),
                          title: Text('••••  ${card.last4}'),
                          subtitle: Text(card.holderName),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: scheme.error,
                            ),
                            onPressed: () => _deleteCard(card),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              FamilyWalletTab(
                customerId: widget.customerId,
                customerName: widget.customerName,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.label,
    required this.balance,
    required this.onAddFunds,
  });

  final String label;
  final double balance;
  final VoidCallback onAddFunds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 120,
              color: scheme.onPrimary.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SAR',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    balance.toStringAsFixed(2),
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Material(
                color: scheme.secondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onAddFunds,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: scheme.onSecondaryContainer,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Top Up',
                          style: TextStyle(
                            color: scheme.onSecondaryContainer,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
