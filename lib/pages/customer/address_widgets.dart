import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer_address.dart';
import 'package:food_delivery_platform/pages/customer/add_address_screen.dart';

class AddressChip extends StatelessWidget {
  const AddressChip({
    super.key,
    required this.label,
    required this.fullAddress,
    required this.isLoading,
    required this.onTap,
  });

  final String? label;
  final String? fullAddress;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasAddress = (label ?? '').isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Deliver to',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLoading
                        ? 'Loading…'
                        : (hasAddress ? label! : 'Pick a delivery address'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isLoading &&
                      hasAddress &&
                      (fullAddress ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      fullAddress!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

class AddressPickerSheet extends StatelessWidget {
  const AddressPickerSheet({
    super.key,
    required this.customerId,
    this.title = 'Choose delivery address',
    this.subtitle = 'Tap one to use it for this order.',
    this.highlightDefault = true,
  });

  final String customerId;
  final String title;
  final String subtitle;
  final bool highlightDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

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
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: StreamBuilder<List<CustomerAddress>>(
                  stream: DatabaseService().streamCustomerAddresses(customerId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final addresses = snapshot.data ?? [];
                    if (addresses.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No addresses yet. Add one in your profile.',
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: addresses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final address = addresses[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            onTap: () => Navigator.pop(context, address),
                            leading: Icon(
                              address.isDefault && highlightDefault
                                  ? Icons.location_on
                                  : Icons.location_on_outlined,
                              color: address.isDefault && highlightDefault
                                  ? scheme.primary
                                  : null,
                            ),
                            title: Text(address.label),
                            subtitle: Text(
                              address.fullAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: address.isDefault && highlightDefault
                                ? Chip(
                                    label: const Text('Default'),
                                    backgroundColor: scheme.primaryContainer,
                                    labelStyle: TextStyle(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  )
                                : const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addNewAddress(context),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add new address'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addNewAddress(BuildContext context) async {
    final result = await Navigator.push<CustomerAddress>(
      context,
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );
    if (result == null) return;
    await DatabaseService().addCustomerAddress(
      customerId: customerId,
      address: result,
    );
    if (result.isDefault) {
      await DatabaseService().setDefaultCustomerAddress(
        customerId: customerId,
        addressId: result.id,
      );
    }
  }
}
