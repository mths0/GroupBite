import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/customer/cart_screen.dart';
import 'package:food_delivery_platform/pages/customer/customer_orders_screen.dart';
import 'package:food_delivery_platform/pages/customer/map_track_screen.dart';
import 'package:food_delivery_platform/pages/customer/rate_order_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.customer,
    this.displayCustomerName,
  });

  final Order order;
  final Customer customer;

  /// Override the customer name shown in the detail header. Defaults to the
  /// logged-in customer's name. Set this when the viewer is not the buyer
  /// (e.g. family wallet owner viewing a member's order).
  final String? displayCustomerName;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final DatabaseService _db = DatabaseService();

  bool _canTrack(OrderStatus status) {
    return status == OrderStatus.assigned || status == OrderStatus.pickedUp;
  }

  String _formatDateTime(DateTime dt) {
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
    final cart = CartScope.read(context);
    cart.clearRestaurantCart(order.restaurantId);

    final menu = await DatabaseService().getMenuForRestaurant(
      restaurantId: order.restaurantId,
    );

    var addedCount = 0;
    for (final item in order.items) {
      final menuitem = menu.where((m) => m.id == item.menuId).firstOrNull;
      if (menuitem == null) continue;

      final extras = item.selectedOptions.fold<double>(
        0.0,
        (sum, o) => sum + o.extraPrice,
      );
      final unitPrice = menuitem.price + extras;

      for (var i = 0; i < item.quantity; i++) {
        cart.addItem(
          restaurantId: order.restaurantId,
          item: menuitem,
          selectedOptions: item.selectedOptions,
          customUnitPrice: unitPrice,
        );
      }
      addedCount++;
    }

    if (!mounted) return;

    if (addedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("None of these items are available anymore."),
        ),
      );
      return;
    }

    if (addedCount < order.items.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Some items are no longer available and were skipped."),
        ),
      );
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order details'),
      ),
      body: StreamBuilder<Order?>(
        stream: _db.streamOrderById(widget.order.id),
        initialData: widget.order,
        builder: (context, snap) {
          final order = snap.data ?? widget.order;
          return _buildBody(context, theme, scheme, order);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    Order order,
  ) {
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(order.createdAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${order.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 16),
          Text(
            'Items',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (int i = 0; i < order.items.length; i++) ...[
                    if (i > 0) const Divider(height: 16),
                    _ItemRow(item: order.items[i]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${order.totalPrice.toStringAsFixed(2)} SAR',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Order from',
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<Restaurant?>(
            future: _db.getRestaurantById(order.restaurantId),
            builder: (context, snap) {
              return Text(
                snap.data?.name ?? 'Restaurant',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Customer',
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.displayCustomerName ?? widget.customer.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          CancelOrderTimer(
            orderId: order.id,
            customerId: widget.customer.id,
            canCancelUntil: order.canCancelUntil,
            status: order.status,
            onCancelled: () {
              if (!mounted) return;
              Navigator.pop(context);
            },
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
          if (order.status == OrderStatus.delivered && !order.isRated)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openRatingSheet(order),
                icon: const Icon(Icons.star_outline),
                label: const Text('Rate Order'),
              ),
            ),
          if (order.status == OrderStatus.delivered && order.isRated)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _orderSameOrderAgain(order),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orangeAccent.withOpacity(0.8),
                ),
                child: const Text('Order again'),
              ),
            ),
        ],
      );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unitWithTax = item.priceAtPurchase;
    final lineTotalWithTax = unitWithTax * item.quantity;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Qty: ${item.quantity}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
              if (item.customizationSummary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.customizationSummary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${unitWithTax.toStringAsFixed(2)} SAR',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '= ${lineTotalWithTax.toStringAsFixed(2)} SAR',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
