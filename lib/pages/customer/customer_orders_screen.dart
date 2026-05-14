import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/family_wallet.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/customer/order_detail_screen.dart';

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
  late final Stream<List<Order>> _ordersStream =
      _db.getOrdersForCustomer(widget.customer.id);
  late final Stream<FamilyWallet?> _walletStream =
      _db.streamFamilyWalletForUser(widget.customer.id);

  final Map<String, Future<Restaurant?>> _restaurantFutures = {};
  final Map<String, Future<String>> _memberNameFutures = {};

  Future<Restaurant?> _restaurantFuture(String restaurantId) {
    return _restaurantFutures.putIfAbsent(
      restaurantId,
      () => _db.getRestaurantById(restaurantId),
    );
  }

  Future<String> _memberNameFuture(String userId) {
    return _memberNameFutures.putIfAbsent(userId, () async {
      final user = await _db.getUserById(userId);
      return user?.name ?? 'Member';
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FamilyWallet?>(
      stream: _walletStream,
      builder: (context, walletSnap) {
        if (walletSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final wallet = walletSnap.data;
        final isOwner = wallet != null && wallet.isOwner(widget.customer.id);

        if (!isOwner) {
          return _myOrdersList();
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: const [
                    Tab(text: 'My Orders'),
                    Tab(text: 'Family'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _myOrdersList(),
                    _familyOrdersList(wallet.id),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _myOrdersList() {
    return StreamBuilder<List<Order>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(child: Text('No orders yet'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 18),
          itemBuilder: (context, index) {
            final order = orders[index];
            return _OrderCard(
              order: order,
              customerName: widget.customer.name,
              restaurantFuture: _restaurantFuture(order.restaurantId),
              onTap: () => _openDetail(order, widget.customer.name),
            );
          },
        );
      },
    );
  }

  Widget _familyOrdersList(String walletId) {
    return StreamBuilder<List<Order>>(
      stream: _db.streamOrdersForFamilyWallet(walletId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(
            child: Text('No family wallet orders yet'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 18),
          itemBuilder: (context, index) {
            final order = orders[index];
            return FutureBuilder<String>(
              future: _memberNameFuture(order.customerId),
              builder: (context, nameSnap) {
                final name = nameSnap.data ?? '…';
                return _OrderCard(
                  order: order,
                  customerName: name,
                  restaurantFuture: _restaurantFuture(order.restaurantId),
                  onTap: () => _openDetail(order, name),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openDetail(Order order, String displayName) {
    final cart = CartScope.read(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScope(
          notifier: cart,
          child: OrderDetailScreen(
            order: order,
            customer: widget.customer,
            displayCustomerName: displayName,
          ),
        ),
      ),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.customerName,
    required this.restaurantFuture,
    required this.onTap,
  });

  final Order order;
  final String customerName;
  final Future<Restaurant?> restaurantFuture;
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

    return FutureBuilder<Restaurant?>(
      future: restaurantFuture,
      builder: (context, snap) {
        final restaurant = snap.data;
        final restaurantName = restaurant?.name ?? 'Restaurant';
        final imageUrl = restaurant?.imageUrl ?? '';

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
                            customerName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
