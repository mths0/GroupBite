import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/order.dart';

class RestaurantOrdersDashboard extends StatefulWidget {
  const RestaurantOrdersDashboard({
    super.key,
    required this.restaurantId,
  });

  final String restaurantId;

  @override
  State<RestaurantOrdersDashboard> createState() =>
      _RestaurantOrdersDashboardState();
}

class _RestaurantOrdersDashboardState extends State<RestaurantOrdersDashboard> {
  final DatabaseService _db = DatabaseService();

  Future<void> _updateStatus(String orderId, OrderStatus status) async {
    try {
      await _db.updateOrderStatus(
        orderId: orderId,
        status: status,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order updated to ${_statusLabel(status)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order: $e')),
      );
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.rejected:
        return Colors.red;
      case OrderStatus.accepted:
        return Colors.blue;
      case OrderStatus.assigned:
        return Colors.teal;
      case OrderStatus.pickedUp:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;
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
    }
  }

  String _restaurantStatusMessage(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Waiting for restaurant decision';
      case OrderStatus.rejected:
        return 'This order was rejected';
      case OrderStatus.accepted:
        return 'Order accepted. Waiting for driver';
      case OrderStatus.assigned:
        return 'Driver assigned to this order';
      case OrderStatus.pickedUp:
        return 'Order picked up by driver';
      case OrderStatus.delivered:
        return 'Order delivered successfully';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Order>>(
        stream: _db.getOrdersForRestaurant(widget.restaurantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text('No orders yet'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order #${order.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(order.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusLabel(order.status),
                              style: TextStyle(
                                color: _statusColor(order.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Customer ID: ${order.customerId}'),
                      const SizedBox(height: 4),
                      Text('Items: ${order.items.length}'),
                      const SizedBox(height: 4),
                      Text('Total: ${order.totalPrice.toStringAsFixed(2)} SAR'),
                      const SizedBox(height: 12),

                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('- ${item.name} x${item.quantity}'),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (order.status == OrderStatus.pending)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateStatus(
                                  order.id,
                                  OrderStatus.accepted,
                                ),
                                child: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _updateStatus(
                                  order.id,
                                  OrderStatus.rejected,
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          _restaurantStatusMessage(order.status),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
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
    );
  }
}