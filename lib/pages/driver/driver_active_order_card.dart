import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/customer.dart';
import 'package:yjeek/models/driver.dart';
import 'package:yjeek/models/order.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/themes/app_theme.dart';
import 'package:yjeek/utils/location_service.dart';
import 'package:yjeek/widgets/confirm_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverActiveOrderCard extends StatefulWidget {
  const DriverActiveOrderCard({
    super.key,
    required this.order,
    required this.driver,
    required this.driverLocation,
    required this.onPickedUp,
    required this.onDelivered,
  });

  final Order order;
  final Driver driver;
  final Future<void> Function() onPickedUp;
  final Future<void> Function() onDelivered;
  final firestore.GeoPoint? driverLocation;

  @override
  State<DriverActiveOrderCard> createState() => _DriverActiveOrderCardState();
}

class _DriverActiveOrderCardState extends State<DriverActiveOrderCard> {
  Restaurant? _restaurant;
  Customer? _customer;
  bool _isLoading = true;
  static const double _pickupDistanceKm = 0.03;
  static const double _deliveredDistanceKm = 0.025;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  double _distanceToRestaurant() {
    final driverLocation = widget.driverLocation;
    if (driverLocation == null) return double.infinity;

    return LocationService.distanceInKm(
      from: driverLocation,
      to: widget.order.restaurantLocation,
    );
  }

  double _distanceToCustomer() {
    final driverLocation = widget.driverLocation;
    if (driverLocation == null) return double.infinity;

    return LocationService.distanceInKm(
      from: driverLocation,
      to: widget.order.customerLocation,
    );
  }

  Future<void> _loadData() async {
    final db = DatabaseService();

    final restaurantUser = await db.getUserById(widget.order.restaurantId);
    final customerUser = await db.getUserById(widget.order.customerId);

    if (!mounted) return;

    setState(() {
      _restaurant = restaurantUser is Restaurant ? restaurantUser : null;
      _customer = customerUser is Customer ? customerUser : null;
      _isLoading = false;
    });
  }

  String _saudiPhone(String phone) => '+966$phone';

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '966${cleanedPhone.substring(1)}';
    } else if (cleanedPhone.startsWith('5')) {
      cleanedPhone = '966$cleanedPhone';
    }

    final uri = Uri.parse('https://wa.me/$cleanedPhone');

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _openDirections({
    required double destinationLat,
    required double destinationLng,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng&travelmode=driving',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  VoidCallback confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() onPress,
  }) {
    return () async {
      final ok = await showConfirmDialog(
        context: context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      );
      if (ok == true) await onPress();
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isGoingToRestaurant = widget.order.status == OrderStatus.assigned;
    final isGoingToCustomer = widget.order.status == OrderStatus.pickedUp;

    final restaurantDistanceKm = _distanceToRestaurant();
    final customerDistanceKm = _distanceToCustomer();

    final canMarkPickedUp = restaurantDistanceKm <= _pickupDistanceKm;
    final canMarkDelivered = customerDistanceKm <= _deliveredDistanceKm;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant, width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isGoingToCustomer)
                    _CustomerHeader(
                      customerName: _customer?.name ?? 'Customer',
                      orderId: widget.order.id,
                    )
                  else
                    _RestaurantHeader(
                      restaurant: _restaurant,
                      orderId: widget.order.id,
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'Items',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final item in widget.order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'x${item.quantity}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if (item.customizationSummary.isNotEmpty)
                                  Text(
                                    item.customizationSummary,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isGoingToRestaurant)
          _PickupActions(
            canMarkPickedUp: canMarkPickedUp,
            distanceKm: restaurantDistanceKm,
            onOpenMaps: () => _openDirections(
              destinationLat: widget.order.restaurantLocation.latitude,
              destinationLng: widget.order.restaurantLocation.longitude,
            ),
            onCall: _restaurant == null
                ? null
                : () => _callPhone(_saudiPhone(_restaurant!.phone)),
            onPickedUp: canMarkPickedUp
                ? confirmDialog(
                    title: 'Mark as picked up?',
                    message:
                        'Confirm you have collected the order from the restaurant.',
                    confirmLabel: 'Mark picked up',
                    onPress: widget.onPickedUp,
                  )
                : null,
          )
        else if (isGoingToCustomer)
          _DeliveryActions(
            canMarkDelivered: canMarkDelivered,
            distanceKm: customerDistanceKm,
            onOpenMaps: () => _openDirections(
              destinationLat: widget.order.customerLocation.latitude,
              destinationLng: widget.order.customerLocation.longitude,
            ),
            onCall: _customer == null
                ? null
                : () => _callPhone(_saudiPhone(_customer!.phone)),
            onWhatsApp: _customer == null
                ? null
                : () => _openWhatsApp(_customer!.phone),
            onDelivered: canMarkDelivered
                ? confirmDialog(
                    title: 'Mark as delivered?',
                    message: 'Confirm you handed the order to the customer.',
                    confirmLabel: 'Mark delivered',
                    onPress: widget.onDelivered,
                  )
                : null,
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No active driver action for this order.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _RestaurantHeader extends StatelessWidget {
  const _RestaurantHeader({required this.restaurant, required this.orderId});

  final Restaurant? restaurant;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final imageUrl = restaurant?.imageUrl ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _RestaurantImageFallback(),
                )
              : _RestaurantImageFallback(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restaurant?.name ?? 'Restaurant',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Order #$orderId',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RestaurantImageFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      height: 64,
      color: scheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, color: scheme.onSurfaceVariant),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.customerName, required this.orderId});

  final String customerName;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Icon(
            Icons.person_outline,
            color: scheme.onSurface,
            size: 44,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customerName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Order #$orderId',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickupActions extends StatelessWidget {
  const _PickupActions({
    required this.canMarkPickedUp,
    required this.distanceKm,
    required this.onOpenMaps,
    required this.onCall,
    required this.onPickedUp,
  });

  final bool canMarkPickedUp;
  final double distanceKm;
  final VoidCallback onOpenMaps;
  final VoidCallback? onCall;
  final VoidCallback? onPickedUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = theme.extension<BrandColors>()!;
    return Container(
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryAction(
                        icon: Icons.navigation_outlined,
                        label: 'Google Maps',
                        onPressed: onOpenMaps,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SecondaryAction(
                        icon: Icons.call_outlined,
                        label: 'Call Restaurant',
                        onPressed: onCall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: onPickedUp,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Picked Up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  canMarkPickedUp
                      ? 'You are close enough to the restaurant.'
                      : 'Move closer to the restaurant (${distanceKm.toStringAsFixed(2)} km away).',
                  style: TextStyle(
                    color: canMarkPickedUp ? brand.success : scheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _DeliveryActions extends StatelessWidget {
  const _DeliveryActions({
    required this.canMarkDelivered,
    required this.distanceKm,
    required this.onOpenMaps,
    required this.onCall,
    required this.onWhatsApp,
    required this.onDelivered,
  });

  final bool canMarkDelivered;
  final double distanceKm;
  final VoidCallback onOpenMaps;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onDelivered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = theme.extension<BrandColors>()!;
    return Container(
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryAction(
                        icon: Icons.navigation_outlined,
                        label: 'Google Maps',
                        onPressed: onOpenMaps,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CircleAction(
                      icon: Icons.phone_rounded,
                      filled: true,
                      onTap: onCall,
                    ),
                    const SizedBox(width: 10),
                    _CircleAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      filled: false,
                      onTap: onWhatsApp,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: onDelivered,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Delivered',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  canMarkDelivered
                      ? 'You are close enough to the customer.'
                      : 'Move closer to the customer (${distanceKm.toStringAsFixed(2)} km away).',
                  style: TextStyle(
                    color: canMarkDelivered ? brand.success : scheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      shape: const CircleBorder(),
      color: filled ? scheme.primary : scheme.surfaceContainerLowest,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: filled
                ? null
                : Border.all(color: scheme.outlineVariant, width: 1),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: filled ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLowest,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
