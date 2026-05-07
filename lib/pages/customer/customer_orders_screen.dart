import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/pages/customer/cart_screen.dart';
import 'package:food_delivery_platform/pages/customer/map_track_screen.dart';
import 'package:food_delivery_platform/pages/customer/rate_order_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({
    super.key,
    required this.customer,
  });

  final Customer customer;

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final DatabaseService _db = DatabaseService();

  bool _canTrack(OrderStatus status) {
    return status == OrderStatus.assigned || status == OrderStatus.pickedUp;
  }

  String _formatScheduledFor(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $hour:$min';
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
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  void _openRatingSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RateOrderSheet(
        order: order,
        onSubmit:
            ({
              required int restaurantRating,
              required int driverRating,
            }) async {
              if (order.driverId == null || order.driverId!.isEmpty) {
                throw Exception('Driver not found for this order');
              }

              await _db.submitOrderRating(
                orderId: order.id,
                restaurantId: order.restaurantId,
                driverId: order.driverId!,
                restaurantRating: restaurantRating,
                driverRating: driverRating,
              );
            },
      ),
    );
  }

  Future<void> _orderSameOrderAgain(Order order) async {
    final cart = CartScope.of(context);
    cart.clearRestaurantCart(order.restaurantId);
    // get restaurant menu
    final menu = await DatabaseService().getMenuForRestaurant(
      restaurantId: order.restaurantId,
    );

    for (var item in order.items) {
      if (menu.any((menu) => menu.id == item.menuId)) {
        final menuitem = menu.firstWhere((menu) => menu.id == item.menuId);
        for (int i = 0; i < item.quantity; i++) {
          cart.addItem(
            restaurantId: order.restaurantId,
            item: menuitem,
            selectedOptions: const [],
            customUnitPrice: menuitem.price,
          );
        }
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScope(
          notifier: cart,
          child: CartScreen(
            restaurantId: order.restaurantId,
            customerId: order.customerId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: _db.getOrdersForCustomer(widget.customer.id),
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
                    Text('Total: ${order.totalPrice.toStringAsFixed(2)} SAR'),
                    const SizedBox(height: 6),
                    Text('Items: ${order.items.length}'),
                    if (order.scheduledFor != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Scheduled for: ${_formatScheduledFor(order.scheduledFor!)}',
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

                    CancelOrderTimer(
                      orderId: order.id,

                      customerId: widget.customer.id,

                      canCancelUntil: order.canCancelUntil,

                      status: order.status,

                      onCancelled: () {},
                    ),

                    const SizedBox(height: 12),

                    if (_canTrack(order.status))
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MapScreen(order: order),
                              ),
                            );
                          },
                          icon: const Icon(Icons.location_on_outlined),
                          label: Text(
                            order.status == OrderStatus.assigned
                                ? 'Track Driver'
                                : 'Track Order',
                          ),
                        ),
                      ),

                    if (order.status == OrderStatus.delivered &&
                        !order.isRated) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openRatingSheet(order),
                          icon: const Icon(Icons.star_outline),
                          label: const Text('Rate Order'),
                        ),
                      ),
                    ],

                    if (order.status == OrderStatus.delivered &&
                        order.isRated) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ElevatedButton(
                          onPressed: () => _orderSameOrderAgain(order),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.orangeAccent.withOpacity(
                              0.8,
                            ),
                          ),
                          child: const Text('Order again'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CancelOrderTimer extends StatefulWidget {
  const CancelOrderTimer({
    super.key,
    required this.orderId,
    required this.customerId,
    required this.canCancelUntil,
    required this.status,
    required this.onCancelled,
  });

  final String orderId;
  final String customerId;
  final DateTime? canCancelUntil;
  final OrderStatus status;
  final VoidCallback onCancelled;

  @override
  State<CancelOrderTimer> createState() => _CancelOrderTimerState();
}

class _CancelOrderTimerState extends State<CancelOrderTimer> {
  late final Stream<int> _ticker;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();

    _ticker = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _confirmCancelOrder() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Order?'),
          content: const Text(
            'Are you sure you want to cancel this order? This action cannot be undone.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes, Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Center(child: const Text('Keep Order')),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) return;

    await _cancelOrder();
  }

  Future<void> _cancelOrder() async {
    setState(() => _isCancelling = true);

    try {
      await DatabaseService().cancelOrderByCustomer(
        orderId: widget.orderId,
        customerId: widget.customerId,
      );

      widget.onCancelled();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.canCancelUntil == null) {
      return const SizedBox.shrink();
    }

    if (widget.status != OrderStatus.pending) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, snapshot) {
        final remaining = widget.canCancelUntil!.difference(DateTime.now());

        if (remaining.isNegative) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_clock_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cancellation time ended',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        final formattedTime = '$minutes:${seconds.toString().padLeft(2, '0')}';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.error.withOpacity(0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can cancel for $formattedTime',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                'After this time, the restaurant may start preparing your order.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCancelling ? null : _confirmCancelOrder,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isCancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                    _isCancelling ? 'Cancelling...' : 'Cancel Order',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
