import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/utils/location_service.dart';
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

  VoidCallback confirmDialog({required Future<void> Function() onPress}) {
    return () {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Action'),
          content: const Text('Are you sure you want to proceed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Center(child: const Text('Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await onPress();
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (_restaurant?.imageUrl ?? '').isNotEmpty
                        ? Image.network(
                            _restaurant!.imageUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 64,
                              height: 64,
                              color: scheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.restaurant,
                                color: scheme.outline,
                              ),
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: scheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.restaurant,
                              color: scheme.outline,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _restaurant?.name ?? 'Restaurant',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${widget.order.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                                  color: scheme.outline,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              if (isGoingToRestaurant) ...[
                const Text(
                  "Go to Restaurant",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _openDirections(
                    destinationLat: widget.order.restaurantLocation.latitude,
                    destinationLng: widget.order.restaurantLocation.longitude,
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text("Open Google Maps"),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _restaurant == null
                      ? null
                      : () => _callPhone(_saudiPhone(_restaurant!.phone)),
                  icon: const Icon(Icons.call),
                  label: const Text("Call Restaurant"),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: canMarkPickedUp
                      ? confirmDialog(onPress: widget.onPickedUp)
                      : null,
                  child: const Text("Picked Up"),
                ),
                const SizedBox(height: 8),
                Text(
                  canMarkPickedUp
                      ? 'You are close enough to the restaurant.'
                      : 'Move closer to the restaurant (${restaurantDistanceKm.toStringAsFixed(2)} km away).',
                  style: TextStyle(
                    color: canMarkPickedUp ? Colors.green : scheme.error,
                    fontSize: 12,
                  ),
                ),
              ],

              if (isGoingToCustomer) ...[
                const Text(
                  "Go to Customer",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_customer != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: scheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _customer!.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _openDirections(
                    destinationLat: widget.order.customerLocation.latitude,
                    destinationLng: widget.order.customerLocation.longitude,
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text("Open Google Maps"),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _customer == null
                      ? null
                      : () => _callPhone(_saudiPhone(_customer!.phone)),
                  icon: const Icon(Icons.call),
                  label: const Text("Call Customer"),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _customer == null
                      ? null
                      : () => _openWhatsApp(_customer!.phone),
                  icon: const Icon(Icons.chat),
                  label: const Text("WhatsApp Customer"),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: canMarkDelivered
                      ? confirmDialog(onPress: widget.onDelivered)
                      : null,
                  child: const Text("Delivered"),
                ),
                const SizedBox(height: 8),
                Text(
                  canMarkDelivered
                      ? 'You are close enough to the customer.'
                      : 'Move closer to the customer (${customerDistanceKm.toStringAsFixed(2)} km away).',
                  style: TextStyle(
                    color: canMarkDelivered ? Colors.green : scheme.error,
                    fontSize: 12,
                  ),
                ),
              ],

              if (!isGoingToRestaurant && !isGoingToCustomer)
                const Text("No active driver action for this order."),
            ],
          ),
        ),
      ),
    );
  }
}
