import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_order_detail_screen.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_order_status.dart';

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

const List<OrderStatus> _statusSortOrder = [
  OrderStatus.pending,
  OrderStatus.accepted,
  OrderStatus.assigned,
  OrderStatus.pickedUp,
  OrderStatus.delivered,
  OrderStatus.cancelled,
  OrderStatus.rejected,
];

int _compareOrders(Order a, Order b) {
  final byStatus = _statusSortOrder
      .indexOf(a.status)
      .compareTo(_statusSortOrder.indexOf(b.status));
  if (byStatus != 0) return byStatus;
  return b.createdAt.compareTo(a.createdAt);
}

class _RestaurantOrdersDashboardState extends State<RestaurantOrdersDashboard>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late final TabController _tabController;
  Timer? _tick;

  final Map<String, Future<String>> _customerNameFutures = {};
  final Set<String> _autoRejectInFlight = {};
  Restaurant? _restaurant;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshRestaurant();
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _refreshRestaurant();
        setState(() {});
      }
    });
  }

  Future<void> _refreshRestaurant() async {
    final r = await _db.getRestaurantById(widget.restaurantId);
    if (mounted) setState(() => _restaurant = r);
  }

  void _autoRejectIfClosed(List<Order> orders) {
    final restaurant = _restaurant;
    if (restaurant == null || restaurant.isOpen) return;
    final now = DateTime.now();
    for (final order in orders) {
      if (order.status != OrderStatus.pending) continue;
      final scheduled = order.scheduledFor;
      if (scheduled != null && scheduled.isAfter(now)) continue;
      if (!_autoRejectInFlight.add(order.id)) continue;
      _db.restaurantRejectOrder(order.id).whenComplete(() {
        _autoRejectInFlight.remove(order.id);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _customerNameFuture(String customerId) {
    return _customerNameFutures.putIfAbsent(customerId, () async {
      final user = await _db.getUserById(customerId);
      return user?.name ?? 'Customer';
    });
  }

  String _formatScheduledFor(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $hour:$min';
  }

  void _openDetail(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantOrderDetailScreen(order: order),
      ),
    );
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

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _autoRejectIfClosed(orders);
                });

                // Hide pending orders whose customer cancel window is still
                // open — they reveal to the restaurant only once the
                // customer can no longer cancel.
                final visibleOrders = orders.where((o) {
                  if (o.status != OrderStatus.pending) return true;
                  final until = o.canCancelUntil;
                  if (until == null) return true;
                  return !until.isAfter(now);
                }).toList();

                final scheduled = visibleOrders
                    .where(
                      (o) =>
                          o.scheduledFor != null &&
                          o.scheduledFor!.isAfter(now),
                    )
                    .toList()
                  ..sort(_compareOrders);
                final active = visibleOrders
                    .where(
                      (o) =>
                          o.scheduledFor == null ||
                          !o.scheduledFor!.isAfter(now),
                    )
                    .toList()
                  ..sort(_compareOrders);

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
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(
          order: order,
          customerNameFuture: _customerNameFuture(order.customerId),
          scheduledLine: isScheduledTab && order.scheduledFor != null
              ? 'Scheduled: ${_formatScheduledFor(order.scheduledFor!)}'
              : null,
          onTap: () => _openDetail(order),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.customerNameFuture,
    required this.scheduledLine,
    required this.onTap,
  });

  final Order order;
  final Future<String> customerNameFuture;
  final String? scheduledLine;
  final VoidCallback onTap;

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = restaurantStatusColor(order.status);

    return FutureBuilder<String>(
      future: customerNameFuture,
      builder: (context, snap) {
        final customerName = snap.data ?? '…';

        return Material(
          color: scheme.surface,
          elevation: 0,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.outlineVariant,
                  width: 1,
                ),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.id}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            customerName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              restaurantStatusLabel(order.status),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (scheduledLine != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              scheduledLine!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(order.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.totalPrice.toStringAsFixed(2)} SAR',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
