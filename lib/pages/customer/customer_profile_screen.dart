import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/customer_address.dart';
import 'package:food_delivery_platform/models/saved_card.dart';
import 'package:food_delivery_platform/pages/customer/add_address_screen.dart';
import 'package:food_delivery_platform/pages/customer/card_form_sheet.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.customer,
  });

  final Customer customer;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final DatabaseService _db = DatabaseService();

  bool _isSaving = false;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _openAddressScreen({CustomerAddress? existing}) async {
    final result = await Navigator.push<CustomerAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(existing: existing),
      ),
    );

    if (result == null) return;

    if (existing == null) {
      await _db.addCustomerAddress(
        customerId: widget.customer.id,
        address: result,
      );
    } else {
      await _db.updateCustomerAddress(
        customerId: widget.customer.id,
        address: result,
      );
    }

    if (result.isDefault) {
      await _db.setDefaultCustomerAddress(
        customerId: widget.customer.id,
        addressId: result.id,
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      await _usersCollection.doc(widget.customer.id).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Center(child: const Text('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Center(child: const Text('Sign out')),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    try {
      await AuthService().signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const StartScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign out: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.outline,
                indicatorColor: scheme.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.person_outline), text: 'Account'),
                  Tab(icon: Icon(Icons.credit_card), text: 'Payment'),
                  Tab(icon: Icon(Icons.family_restroom), text: 'Family'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _AccountTab(
                    customer: widget.customer,
                    nameController: _nameController,
                    phoneController: _phoneController,
                    isSaving: _isSaving,
                    db: _db,
                    onSave: _saveProfile,
                    onSignOut: _signOut,
                    onOpenAddress: _openAddressScreen,
                  ),
                  _PaymentTab(
                    customerId: widget.customer.id,
                    db: _db,
                  ),
                  const _FamilyWalletTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTab extends StatefulWidget {
  const _AccountTab({
    required this.customer,
    required this.nameController,
    required this.phoneController,
    required this.isSaving,
    required this.db,
    required this.onSave,
    required this.onSignOut,
    required this.onOpenAddress,
  });

  final Customer customer;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool isSaving;
  final DatabaseService db;
  final VoidCallback onSave;
  final VoidCallback onSignOut;
  final Future<void> Function({CustomerAddress? existing}) onOpenAddress;

  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<_AccountTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: scheme.primary.withOpacity(0.12),
          child: Text(
            widget.customer.name.isNotEmpty
                ? widget.customer.name[0].toUpperCase()
                : 'C',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Customer Profile',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),

        Text(
          'ID: ${widget.customer.id}',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.outline),
        ),
        const SizedBox(height: 24),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.email_outlined),
          title: const Text('Email'),
          subtitle: Text(widget.customer.email),
        ),
        const SizedBox(height: 12),

        _ProfileTextField(
          controller: widget.nameController,
          label: 'Full Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),

        _ProfileTextField(
          controller: widget.phoneController,
          label: 'Phone',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),

        Text(
          'Addresses',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        StreamBuilder<List<CustomerAddress>>(
          stream: widget.db.streamCustomerAddresses(widget.customer.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final addresses = snapshot.data ?? [];

            return Column(
              children: [
                if (addresses.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No addresses added yet'),
                  ),

                ...addresses.map((address) {
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        address.isDefault
                            ? Icons.location_on
                            : Icons.location_on_outlined,
                      ),
                      title: Text(address.label),
                      subtitle: Text(address.fullAddress),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'default') {
                            await widget.db.setDefaultCustomerAddress(
                              customerId: widget.customer.id,
                              addressId: address.id,
                            );
                          } else if (value == 'edit') {
                            widget.onOpenAddress(existing: address);
                          } else if (value == 'delete') {
                            await widget.db.deleteCustomerAddress(
                              customerId: widget.customer.id,
                              addressId: address.id,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('Set as default'),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onOpenAddress(),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add Address'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: widget.isSaving ? null : widget.onSave,
            child: widget.isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Changes'),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }
}

class _PaymentTab extends StatefulWidget {
  const _PaymentTab({
    required this.customerId,
    required this.db,
  });

  final String customerId;
  final DatabaseService db;

  @override
  State<_PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<_PaymentTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _showAddFundsDialog() async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => const _AddFundsDialog(),
    );

    if (amount == null || amount <= 0) return;

    try {
      await widget.db.addFundsToWallet(
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

  Future<void> _openCardForm({required bool hasExistingCard}) async {
    final result = await showModalBottomSheet<CardInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CardFormSheet(),
    );

    if (result == null) return;

    final card = SavedCard(
      id: IdGenerator.generateCardId(),
      brand: SavedCard.brandFromNumber(result.number),
      last4: SavedCard.last4FromNumber(result.number),
      expiry: result.expiry,
      holderName: result.holderName,
      isDefault: !hasExistingCard,
    );

    try {
      await widget.db.addCustomerCard(
        customerId: widget.customerId,
        card: card,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save card: $e')),
      );
    }
  }

  Future<void> _deleteCard(String cardId) async {
    try {
      await widget.db.deleteCustomerCard(
        customerId: widget.customerId,
        cardId: cardId,
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
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<double>(
          stream: widget.db.streamWalletBalance(widget.customerId),
          builder: (context, snapshot) {
            final balance = snapshot.data ?? 0.0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Wallet Balance',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${balance.toStringAsFixed(2)} SAR',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _showAddFundsDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add funds'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        Text(
          'Saved Card',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        StreamBuilder<List<SavedCard>>(
          stream: widget.db.streamCustomerCards(widget.customerId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final cards = snapshot.data ?? [];

            if (cards.isEmpty) {
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openCardForm(hasExistingCard: false),
                  icon: const Icon(Icons.add_card),
                  label: const Text('Add Card'),
                ),
              );
            }

            final card = cards.first;
            return Card(
              child: ListTile(
                leading: Icon(Icons.credit_card, color: scheme.primary),
                title: Text('${card.brand}  ••••  ${card.last4}'),
                subtitle: Text(card.holderName),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteCard(card.id),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AddFundsDialog extends StatefulWidget {
  const _AddFundsDialog();

  @override
  State<_AddFundsDialog> createState() => _AddFundsDialogState();
}

class _AddFundsDialogState extends State<_AddFundsDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final parsed = double.tryParse(_controller.text);
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add funds'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Amount (SAR)',
          border: OutlineInputBorder(),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _FamilyWalletTab extends StatelessWidget {
  const _FamilyWalletTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom,
              size: 72,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Family Wallet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon — features will be added later',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.outline,
              ),
            ),
          ],
        ),
      ),
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
        border: const OutlineInputBorder(),
      ),
    );
  }
}

