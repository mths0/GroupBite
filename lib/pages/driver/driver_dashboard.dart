import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/driver.dart';
import 'package:yjeek/models/order.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/pages/driver/driver_active_order_card.dart';
import 'package:yjeek/pages/driver/driver_profile_screen.dart';
import 'package:yjeek/themes/app_theme.dart';
import 'package:yjeek/utils/location_service.dart';
import 'package:yjeek/widgets/app_snack.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({
    super.key,
    required this.driver,
    this.initialLocation,
  });

  final Driver driver;
  final firestore.GeoPoint? initialLocation;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  bool _isProgrammaticNav = false;
  late Stream<List<Order>> _availableOrdersStream;
  late Stream<List<Order>> _driverOrdersStream;
  StreamSubscription? _locationSubscription;
  firestore.GeoPoint? _driverLocation;

  final Map<String, Future<Restaurant?>> _restaurantFutures = {};

  Future<Restaurant?> _restaurantFuture(String restaurantId) {
    return _restaurantFutures.putIfAbsent(restaurantId, () async {
      final user = await DatabaseService().getRestaurantById(restaurantId);
      return user;
    });
  }

  String _distanceLabel(Order order) {
    final driverLocation = _driverLocation;
    if (driverLocation == null) return '— km away';
    final restaurantLocation = order.restaurantLocation;

    final distanceKm = LocationService.distanceInKm(
      from: driverLocation,
      to: restaurantLocation,
    );
    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  Future<bool> _updateDriverLocation({bool showError = false}) async {
    try {
      final position = await LocationService.getCurrentLocation();

      final geoPoint = firestore.GeoPoint(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _driverLocation = geoPoint;
        });
      }

      await DatabaseService().updateDriverLocation(
        driverId: widget.driver.id,
        location: geoPoint,
      );

      return true;
    } catch (e) {
      debugPrint('Driver location update error: $e');
      if (showError && mounted) {
        showAppSnack(
          context,
          'Share your current location before accepting orders.',
        );
      }
      if (mounted) {
        _updateDriverStatus(DriverStatus.offline);
      }
      return false;
    }
  }

  Future<void> _startLiveLocationTracking() async {
    try {
      final sharedLocation = await _updateDriverLocation();
      if (!sharedLocation) return;

      if (widget.driver.status == DriverStatus.offline) {
        _updateDriverStatus(DriverStatus.available);
      }

      _locationSubscription?.cancel();
      _locationSubscription = LocationService.getLiveLocationStream().listen(
        (
          position,
        ) async {
          final geoPoint = firestore.GeoPoint(
            position.latitude,
            position.longitude,
          );

          if (!mounted) return;

          setState(() {
            _driverLocation = geoPoint;
          });

          await DatabaseService().updateDriverLocation(
            driverId: widget.driver.id,
            location: geoPoint,
          );
        },
        onError: (error) {
          debugPrint('Live location stream error: $error');
          if (mounted) {
            _updateDriverStatus(DriverStatus.offline);
          }
        },
      );
    } catch (e) {
      debugPrint('Live location error: $e');
      if (mounted) {
        _updateDriverStatus(DriverStatus.offline);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _driverLocation = widget.initialLocation;

    _availableOrdersStream = DatabaseService().getAvailableOrdersForDrivers();
    _driverOrdersStream = DatabaseService().getOrdersForDriver(
      widget.driver.id,
    );

    _startLiveLocationTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) async {
    setState(() {
      _selectedIndex = index;
      _isProgrammaticNav = true;
    });
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    setState(() => _isProgrammaticNav = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.driver.status == DriverStatus.busy) {
      if (state == AppLifecycleState.resumed) {
        _startLiveLocationTracking();
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _updateDriverStatus(DriverStatus.available);
      _startLiveLocationTracking();
    } else if (state == AppLifecycleState.paused) {
      _updateDriverStatus(DriverStatus.offline);
    }
  }

  Widget _buildAvailableOrdersSection() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Available Orders',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
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

              final orders =
                  snapshot.data!
                      .where(
                        (r) => LocationService.isWithinDistanceKm(
                          from: r.restaurantLocation,
                          to: _driverLocation,
                          maxDistanceKm: 5,
                        ),
                      )
                      .toList()
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
    final sharedLocation = await _updateDriverLocation(showError: true);
    if (!sharedLocation) return;

    try {
      await DatabaseService().assignOrderToDriver(
        orderId: order.id,
        driverId: widget.driver.id,
      );
      _updateDriverStatus(DriverStatus.busy);
      if (!mounted) return;
      showAppSnack(context, 'Order assigned successfully');
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e);
    }
  }

  void _updateDriverStatus(DriverStatus status) {
    setState(() {
      widget.driver.updateStatus(status);
    });

    DatabaseService().updateDriverStatus(widget.driver.id, status);
  }

  ({Color background, Color foreground}) _statusColors(
    BuildContext context,
    DriverStatus status,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final brand = Theme.of(context).extension<BrandColors>()!;
    switch (status) {
      case DriverStatus.available:
        return (background: brand.success, foreground: brand.onSuccess);
      case DriverStatus.busy:
        return (background: brand.offer, foreground: brand.onOffer);
      case DriverStatus.offline:
        return (background: scheme.errorContainer, foreground: scheme.error);
    }
  }

  double _distanceToRestaurant(Order order) {
    final driverLocation = _driverLocation;
    final restaurantLocation = order.restaurantLocation;

    if (driverLocation == null) {
      return double.infinity;
    }

    final distanceInKm = LocationService.distanceInKm(
      from: driverLocation,
      to: restaurantLocation,
    );

    return distanceInKm;
  }

  Widget _buildOrdersTab() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = _statusColors(context, widget.driver.status);
    final statusLabel = widget.driver.status.name;
    final statusText = statusLabel.isEmpty
        ? statusLabel
        : statusLabel[0].toUpperCase() + statusLabel.substring(1);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: status.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Yjeek',
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
          Expanded(child: _buildOrdersBody()),
        ],
      ),
    );
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
              driverLocation: _driverLocation,
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
                await _updateDriverLocation();
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (_isProgrammaticNav) return;
          setState(() => _selectedIndex = index);
        },
        children: [
          _buildOrdersTab(),
          DriverProfileTab(driver: widget.driver),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _goToPage,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Account',
              ),
            ],
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

        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant, width: 1),
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
                              color: scheme.onSurfaceVariant,
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
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  distanceLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
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
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () async => onAccept(),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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
