import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/customer_address.dart';
import 'package:food_delivery_platform/pages/customer/add_address_screen.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';

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
      body: ListView(
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
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),

          _ProfileTextField(
            controller: _phoneController,
            label: 'Phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),

          Text(
            'Addresses',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<CustomerAddress>>(
            stream: _db.streamCustomerAddresses(widget.customer.id),
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
                              await _db.setDefaultCustomerAddress(
                                customerId: widget.customer.id,
                                addressId: address.id,
                              );
                            } else if (value == 'edit') {
                              _openAddressScreen(existing: address);
                            } else if (value == 'delete') {
                              await _db.deleteCustomerAddress(
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
                      onPressed: _openAddressScreen,
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
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
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
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ),
        ],
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
