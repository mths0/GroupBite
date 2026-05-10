import 'dart:math';

import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/driver/driver_active_order_card.dart';
import 'package:food_delivery_platform/pages/driver/driver_profile_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key, required this.driver});

  final Driver driver;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late Stream<List<Order>> _availableOrdersStream;
  late Stream<List<Order>> _driverOrdersStream;

  final Map<String, Future<Restaurant?>> _restaurantFutures = {};

  Future<Restaurant?> _restaurantFuture(String restaurantId) {
    return _restaurantFutures.putIfAbsent(restaurantId, () async {
      final user = await DatabaseService().getRestaurantById(restaurantId);
      return user;
    });
  }

  String _distanceLabel(Order order) {
    final driverLocation = widget.driver.location;
    if (driverLocation == null) return '— km away';
    final restaurantLocation = order.restaurantLocation;
    const kmPerLatDegree = 111.0;
    final latDiff = driverLocation.latitude - restaurantLocation.latitude;
    final lngDiff = driverLocation.longitude - restaurantLocation.longitude;
    final distanceKm =
        sqrt((latDiff * latDiff) + (lngDiff * lngDiff)) * kmPerLatDegree;
    return '${distanceKm.toStringAsFixed(1)} km away · ETA —';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.driver.status == DriverStatus.offline) {
      _updateDriverStatus(DriverStatus.available);
    }

    _availableOrdersStream = DatabaseService().getAvailableOrdersForDrivers();
    _driverOrdersStream = DatabaseService().getOrdersForDriver(
      widget.driver.id,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.driver.status == DriverStatus.busy) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _updateDriverStatus(DriverStatus.available);
    } else if (state == AppLifecycleState.paused) {
      _updateDriverStatus(DriverStatus.offline);
    }
  }

  Widget _buildAvailableOrdersSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            "Available Orders",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Order>>(
            stream: _availableOrdersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No available orders"));
              }

              final orders = snapshot.data!
                ..sort((a, b) {
                  final aDistance = _distanceToRestaurant(a);
                  final bDistance = _distanceToRestaurant(b);
                  return aDistance.compareTo(bDistance);
                });

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _AvailableOrderTile(
                    order: order,
                    restaurantFuture: _restaurantFuture(order.restaurantId),
                    distanceLabel: _distanceLabel(order),
                    onAccept: () => _acceptOrder(order),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _acceptOrder(Order order) async {
    try {
      await DatabaseService().assignOrderToDriver(
        orderId: order.id,
        driverId: widget.driver.id,
      );
      _updateDriverStatus(DriverStatus.busy);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order assigned successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _updateDriverStatus(DriverStatus status) {
    setState(() {
      widget.driver.updateStatus(status);
    });

    DatabaseService().updateDriverStatus(widget.driver.id, status);
  }

  Color statusColorBasedOnStatus(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return Colors.green;
      case DriverStatus.busy:
        return Colors.orange;
      case DriverStatus.offline:
        return Colors.red;
    }
  }

  double _distanceToRestaurant(Order order) {
    final driverLocation = widget.driver.location;
    final restaurantLocation = order.restaurantLocation;

    if (driverLocation == null) {
      return double.infinity;
    }

    final latDiff = driverLocation.latitude - restaurantLocation.latitude;
    final lngDiff = driverLocation.longitude - restaurantLocation.longitude;

    return (latDiff * latDiff) + (lngDiff * lngDiff);
  }

  Widget _buildOrdersBody() {
    return SafeArea(
      child: StreamBuilder<List<Order>>(
        stream: _driverOrdersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final orders = snapshot.data ?? [];

          final activeOrders = orders.where((order) {
            return order.status == OrderStatus.assigned ||
                order.status == OrderStatus.pickedUp;
          }).toList();

          if (activeOrders.isNotEmpty) {
            return DriverActiveOrderCard(
              order: activeOrders.first,
              driver: widget.driver,
              onPickedUp: () async {
                await DatabaseService().markOrderPickedUp(
                  activeOrders.first.id,
                );
              },
              onDelivered: () async {
                await DatabaseService().markOrderDelivered(
                  activeOrders.first.id,
                );
                _updateDriverStatus(DriverStatus.available);
              },
            );
          }

          return _buildAvailableOrdersSection();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.driver.name),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: statusColorBasedOnStatus(widget.driver.status),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  widget.driver.status.name,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
      body: _selectedIndex == 0
          ? _buildOrdersBody()
          : DriverProfileTab(driver: widget.driver),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AvailableOrderTile extends StatelessWidget {
  const _AvailableOrderTile({
    required this.order,
    required this.restaurantFuture,
    required this.distanceLabel,
    required this.onAccept,
  });

  final Order order;
  final Future<Restaurant?> restaurantFuture;
  final String distanceLabel;
  final Future<void> Function() onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FutureBuilder<Restaurant?>(
      future: restaurantFuture,
      builder: (context, snap) {
        final restaurant = snap.data;
        final restaurantName = restaurant?.name ?? 'Restaurant';
        final imageUrl = restaurant?.imageUrl ?? '';

        return Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _ImageFallback(
                                  scheme: scheme,
                                ),
                              )
                            : _ImageFallback(scheme: scheme),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurantName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order #${order.id}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: scheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    distanceLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.outline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: () async => onAccept(),
                      child: const Text('Accept'),
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
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, color: scheme.outline),
    );
  }
}
