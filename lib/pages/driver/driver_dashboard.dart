import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/models/order.dart';
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

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
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

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Order #${order.id}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Total: ${order.totalPrice.toStringAsFixed(2)} SAR",
                          ),
                          const SizedBox(height: 4),
                          Text("Restaurant: ${order.restaurantId}"),
                          const SizedBox(height: 4),
                          Text("Status: ${_statusLabel(order.status)}"),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  await DatabaseService().assignOrderToDriver(
                                    orderId: order.id,
                                    driverId: widget.driver.id,
                                  );
                                  _updateDriverStatus(DriverStatus.busy);

                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Order assigned successfully",
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              },
                              child: const Text("Accept"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.driver.name),
                Text(
                  widget.driver.id,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
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
