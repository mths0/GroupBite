import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/customer_address.dart';
import 'package:food_delivery_platform/models/saved_card.dart';
import 'package:food_delivery_platform/pages/customer/add_funds_sheet.dart';
import 'package:food_delivery_platform/pages/customer/add_address_screen.dart';
import 'package:food_delivery_platform/pages/customer/address_widgets.dart';
import 'package:food_delivery_platform/pages/customer/card_form_sheet.dart';
import 'package:food_delivery_platform/pages/customer/family_wallet_tab.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:food_delivery_platform/pages/support/support_screen.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';

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
                    onDefaultAddressChanged: widget.onDefaultAddressChanged,
                  ),
                  _PaymentTab(
                    customerId: widget.customer.id,
                    db: _db,
                  ),
                  FamilyWalletTab(
                    customerId: widget.customer.id,
                    customerName: widget.customer.name,
                  ),
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
    this.onDefaultAddressChanged,
  });

  final Customer customer;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool isSaving;
  final DatabaseService db;
  final VoidCallback onSave;
  final VoidCallback onSignOut;
  final VoidCallback? onDefaultAddressChanged;

  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<_AccountTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Stream<List<CustomerAddress>> _addressesStream = widget.db
      .streamCustomerAddresses(widget.customer.id);

  Future<void> _manageAddresses() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final scheme = theme.colorScheme;
        final maxHeight = MediaQuery.of(sheetCtx).size.height * 0.7;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your delivery addresses',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap an address to make it the default.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: StreamBuilder<List<CustomerAddress>>(
                      stream: widget.db.streamCustomerAddresses(
                        widget.customer.id,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final addresses =
                            snapshot.data ?? const <CustomerAddress>[];
                        if (addresses.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No addresses yet. Add one below.',
                              ),
                            ),
                          );
                        }
                        return ListView(
                          shrinkWrap: true,
                          children: addresses
                              .map(
                                (a) => _AddressRow(
                                  address: a,
                                  onTapRow: a.isDefault
                                      ? null
                                      : () async {
                                          await widget.db
                                              .setDefaultCustomerAddress(
                                                customerId:
                                                    widget.customer.id,
                                                addressId: a.id,
                                              );
                                          widget.onDefaultAddressChanged
                                              ?.call();
                                        },
                                  onEdit: () => _editAddress(a),
                                  onDelete: () =>
                                      _deleteAddress(a, addresses),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _addNewAddress();
                      },
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add new address'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addNewAddress() async {
    final result = await Navigator.push<CustomerAddress>(
      context,
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );
    if (result == null || !mounted) return;
    await widget.db.addCustomerAddress(
      customerId: widget.customer.id,
      address: result,
    );
    if (result.isDefault) {
      await widget.db.setDefaultCustomerAddress(
        customerId: widget.customer.id,
        addressId: result.id,
      );
      widget.onDefaultAddressChanged?.call();
    }
  }

  Future<void> _editAddress(CustomerAddress address) async {
    final updated = await Navigator.push<CustomerAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(existing: address),
      ),
    );
    if (updated == null || !mounted) return;
    await widget.db.updateCustomerAddress(
      customerId: widget.customer.id,
      address: updated,
    );
    if (updated.isDefault && !address.isDefault) {
      await widget.db.setDefaultCustomerAddress(
        customerId: widget.customer.id,
        addressId: updated.id,
      );
      widget.onDefaultAddressChanged?.call();
    }
  }

  Future<void> _deleteAddress(
    CustomerAddress address,
    List<CustomerAddress> all,
  ) async {
    if (all.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must keep at least one delivery address.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove "${address.label}" from your addresses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final wasDefault = address.isDefault;
    String? newDefaultId;

    if (wasDefault) {
      final remaining = all.where((a) => a.id != address.id).toList();
      newDefaultId = await _pickReplacementDefault(remaining);
      if (newDefaultId == null) return; // user cancelled
    }

    try {
      await widget.db.deleteCustomerAddress(
        customerId: widget.customer.id,
        addressId: address.id,
      );
      if (newDefaultId != null) {
        await widget.db.setDefaultCustomerAddress(
          customerId: widget.customer.id,
          addressId: newDefaultId,
        );
        widget.onDefaultAddressChanged?.call();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<String?> _pickReplacementDefault(
    List<CustomerAddress> options,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final scheme = theme.colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick a new default',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The address you are deleting is your current default. Choose another address to use as the default.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (a) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => Navigator.pop(sheetCtx, a.id),
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(a.label),
                      subtitle: Text(
                        a.fullAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),

        Text(
          '${widget.customer.name} Profile',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.email_outlined),
          title: const Text('Email'),
          subtitle: Text(widget.customer.email),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Customer ID'),
          subtitle: Text(widget.customer.id),
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
          'Delivery addresses',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        StreamBuilder<List<CustomerAddress>>(
          stream: _addressesStream,
          builder: (context, snapshot) {
            CustomerAddress? defaultAddress;
            for (final a in snapshot.data ?? const <CustomerAddress>[]) {
              if (a.isDefault) {
                defaultAddress = a;
                break;
              }
            }
            return AddressChip(
              label: defaultAddress?.label,
              fullAddress: defaultAddress?.fullAddress,
              isLoading: snapshot.connectionState == ConnectionState.waiting,
              onTap: _manageAddresses,
            );
          },
        ),

        const SizedBox(height: 24),

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
        SizedBox(
          height: 50,
          child: TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupportScreen(
                    userId: widget.customer.id,
                    userRole: 'customer',
                    userName: widget.customer.name,
                    userEmail: widget.customer.email,
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

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.onTapRow,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomerAddress address;
  final VoidCallback? onTapRow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTapRow,
        leading: Icon(
          address.isDefault ? Icons.location_on : Icons.location_on_outlined,
          color: address.isDefault ? scheme.primary : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                address.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (address.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Default',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          address.fullAddress,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ),
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
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddFundsSheet(customerId: widget.customerId),
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
