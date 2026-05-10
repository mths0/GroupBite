import 'dart:async';

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

class _RestaurantOrdersDashboardState extends State<RestaurantOrdersDashboard>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late final TabController _tabController;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tabController.dispose();
    super.dispose();
  }

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
      case OrderStatus.accepted:
        return Colors.blue;
      case OrderStatus.rejected:
        return Colors.red;
      case OrderStatus.pickedUp:
        return Colors.deepPurple;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.assigned:
        return Colors.cyan;
      case OrderStatus.cancelled:
        return Colors.grey;
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
      case OrderStatus.cancelled:
        return 'Order was cancelled';
    }
  }

  String _formatScheduledFor(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Orders'),
                Tab(text: 'Scheduled'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Order>>(
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
                final now = DateTime.now();
                final scheduled = orders
                    .where(
                      (o) =>
                          o.scheduledFor != null &&
                          o.scheduledFor!.isAfter(now),
                    )
                    .toList();
                final active = orders
                    .where(
                      (o) =>
                          o.scheduledFor == null ||
                          !o.scheduledFor!.isAfter(now),
                    )
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrdersList(
                      active,
                      emptyText: 'No active orders',
                      isScheduledTab: false,
                    ),
                    _buildOrdersList(
                      scheduled,
                      emptyText: 'No scheduled orders',
                      isScheduledTab: true,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(
    List<Order> orders, {
    required String emptyText,
    required bool isScheduledTab,
  }) {
    if (orders.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index], isScheduledTab: isScheduledTab);
      },
    );
  }

  Widget _buildOrderCard(Order order, {required bool isScheduledTab}) {
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
            if (order.scheduledFor != null) ...[
              const SizedBox(height: 4),
              Text(
                'Scheduled for: ${_formatScheduledFor(order.scheduledFor!)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),

            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('- ${item.name} x${item.quantity}'),
              ),
            ),

            const SizedBox(height: 12),

            if (isScheduledTab) ...[
              Text(
                'Scheduled — will activate at the scheduled time.',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
            ],
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
  }
}
