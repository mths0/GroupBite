import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';

import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/models/order.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key, required this.driver});

  final Driver driver;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with WidgetsBindingObserver {
  late Stream<List<Order>> _orderStream;

  //! remove later
  bool showAddOrderForm = false;
  final customerIdController = TextEditingController();
  final restaurantIdController = TextEditingController();
  final priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.driver.status != DriverStatus.busy) {
      _updateDriverStatus(DriverStatus.available);
    }
    _orderStream = DatabaseService().listenForPendingOrders();
  }

  @override
  void dispose() {
    customerIdController.dispose();
    restaurantIdController.dispose();
    priceController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // This method is called when the app lifecycle state changes (e.g., when the app is paused or resumed).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.driver.status == DriverStatus.busy) {
      return; // if driver is busy, we don't want to change their status
    }

    if (state == AppLifecycleState.resumed) {
      _updateDriverStatus(DriverStatus.available);
    } else if (state == AppLifecycleState.paused) {
      _updateDriverStatus(DriverStatus.offline);
    }
  }

  void _updateDriverStatus(DriverStatus status) {
    print("Updating driver status to: ${status.name}");
    setState(() {
      widget.driver.updateStatus(status);
    });

    //TODO: Update status in database
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [Text(widget.driver.name), Text(widget.driver.id)],
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: statusColorBasedOnStatus(widget.driver.status),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(widget.driver.status.name),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Pending Orders",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              child: Expanded(
                child: StreamBuilder<List<Order>>(
                  stream: _orderStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("No pending orders"),
                      );
                    }

                    final orders = snapshot.data!;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        //TODO: sort orders based on distance from driver (requires location data)
                        // Inside your ListView.builder...
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text("Order #${order.id}"),
                            subtitle: Column(
                              children: [
                                Text("Total: ${order.totalPrice} SAR"),
                                Text("Customer: ${order.customerId}"),
                                Text("Restaurant: ${order.restaurantId}"),
                                Text(
                                  "Distance: ${order.restaurantLocation.latitude.round()} km",
                                ),
                              ],
                            ),

                            // FIX: Wrap the trailing widget in a SizedBox or ConstrainedBox
                            trailing: SizedBox(
                              width: 100, // Give the button a specific width
                              child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await DatabaseService().acceptOrder(
                                      orderId: order.id,
                                      driverId: widget.driver.id,
                                    );
                                    _updateDriverStatus(DriverStatus.busy);
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
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Text(
                "Other sections like current order, earnings, profile, etc. (coming soon)",
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    showAddOrderForm = !showAddOrderForm;
                  });
                },
                child: Text(showAddOrderForm ? "Cancel" : "Add Order"),
              ),
            ),
            if (showAddOrderForm)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: customerIdController,
                          decoration: const InputDecoration(
                            labelText: "Customer ID",
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextField(
                          controller: restaurantIdController,
                          decoration: const InputDecoration(
                            labelText: "Restaurant ID",
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Total Price",
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final price = double.tryParse(
                                priceController.text,
                              );

                              if (customerIdController.text.isEmpty ||
                                  restaurantIdController.text.isEmpty ||
                                  price == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Fill all fields"),
                                  ),
                                );
                                return;
                              }

                              await DatabaseService().addOrder(
                                customerId: customerIdController.text,
                                restaurantId: restaurantIdController.text,
                                totalPrice: price,
                              );

                              customerIdController.clear();
                              restaurantIdController.clear();
                              priceController.clear();

                              setState(() {
                                showAddOrderForm = false;
                              });
                            },
                            child: const Text("Save Order"),
                          ),
                        ),
                      ],
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
