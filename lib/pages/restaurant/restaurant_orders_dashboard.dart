import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/order.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/pages/restaurant/restaurant_dashboard.dart';
import 'package:yjeek/pages/restaurant/restaurant_order_detail_screen.dart';
import 'package:yjeek/pages/restaurant/restaurant_order_status.dart';

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

bool _isPastStatus(OrderStatus status) {
  return status == OrderStatus.pickedUp ||
      status == OrderStatus.delivered ||
      status == OrderStatus.cancelled ||
      status == OrderStatus.rejected;
}

class _RestaurantOrdersDashboardState extends State<RestaurantOrdersDashboard>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late final TabController _tabController;
  Timer? _tick;

  final Map<String, Future<String>> _customerNameFutures = {};
  final Set<String> _autoRejectInFlight = {};
  final Set<String> _autoCancelInFlight = {};

  List<Order>? _orders;
  Restaurant? _restaurant;
  StreamSubscription<List<Order>>? _ordersSub;

  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshRestaurant();
    _ordersSub = _db.getOrdersForRestaurant(widget.restaurantId).listen((
      data,
    ) {
      if (!mounted) return;
      setState(() => _orders = data);
    });
    // Re-evaluate time-based filters periodically without triggering a
    // full rebuild of the StreamBuilder/TabBarView — the bumped interval
    // keeps the cancel-window filter fresh while preserving scroll
    // position between updates.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
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

  void _autoCancelStale(List<Order> orders) {
    final now = DateTime.now();
    for (final order in orders) {
      DateTime? deadline;
      if (order.status == OrderStatus.pending) {
        deadline = order.restaurantRespondBy;
      } else if (order.status == OrderStatus.accepted) {
        deadline = order.driverAcceptBy;
      }
      if (deadline == null || now.isBefore(deadline)) continue;
      if (!_autoCancelInFlight.add(order.id)) continue;
      _db.autoCancelExpiredOrder(order.id).whenComplete(() {
        _autoCancelInFlight.remove(order.id);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ordersSub?.cancel();
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: Column(
        children: [
          const RestaurantPageHeader(title: 'Orders'),
          Material(
            color: theme.scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicatorColor: scheme.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'Orders'),
                Tab(text: 'Scheduled'),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final orders = _orders;
                if (orders == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final now = _now;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _autoRejectIfClosed(orders);
                  _autoCancelStale(orders);
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

    String? scheduledLineFor(Order order) =>
        isScheduledTab && order.scheduledFor != null
            ? 'Scheduled: ${_formatScheduledFor(order.scheduledFor!)}'
            : null;

    if (isScheduledTab) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final order = orders[i];
          return _OrderCard(
            order: order,
            customerNameFuture: _customerNameFuture(order.customerId),
            scheduledLine: scheduledLineFor(order),
            onTap: () => _openDetail(order),
          );
        },
      );
    }

    final active = orders.where((o) => !_isPastStatus(o.status)).toList();
    final past = orders.where((o) => _isPastStatus(o.status)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (active.isNotEmpty) ...[
          _SectionLabel(text: 'Active Orders'),
          const SizedBox(height: 12),
          for (final order in active) ...[
            _OrderCard(
              order: order,
              customerNameFuture: _customerNameFuture(order.customerId),
              scheduledLine: scheduledLineFor(order),
              onTap: () => _openDetail(order),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 12),
        ],
        if (past.isNotEmpty) ...[
          _SectionLabel(text: 'Past Orders'),
          const SizedBox(height: 12),
          for (final order in past) ...[
            _OrderCard(
              order: order,
              customerNameFuture: _customerNameFuture(order.customerId),
              scheduledLine: scheduledLineFor(order),
              onTap: () => _openDetail(order),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
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
    final status = restaurantStatusColors(context, order.status);

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
                border: Border.all(color: scheme.outlineVariant, width: 1),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                    color: scheme.shadow.withValues(alpha: 0.06),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Order #${order.id}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status.background,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            restaurantStatusLabel(order.status),
                            style: TextStyle(
                              color: status.foreground,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (scheduledLine != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  scheduledLine!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
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
                              '${order.totalPrice.toStringAsFixed(2)} SAR',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(order.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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
