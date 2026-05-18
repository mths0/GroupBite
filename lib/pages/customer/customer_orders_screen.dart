import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yjeek/cart/cart_scope.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/customer.dart';
import 'package:yjeek/models/family_wallet.dart';
import 'package:yjeek/models/order.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/pages/customer/order_detail_screen.dart';
import 'package:yjeek/widgets/confirm_dialog.dart';

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

  List<Order>? _orders;
  FamilyWallet? _wallet;
  List<Order>? _familyOrders;
  bool _walletLoaded = false;

  StreamSubscription<List<Order>>? _ordersSub;
  StreamSubscription<FamilyWallet?>? _walletSub;
  StreamSubscription<List<Order>>? _familyOrdersSub;
  String? _subscribedFamilyWalletId;

  final Map<String, Future<Restaurant?>> _restaurantFutures = {};
  final Map<String, Future<String>> _memberNameFutures = {};
  final Set<String> _autoCancelInFlight = {};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _ordersSub = _db.getOrdersForCustomer(widget.customer.id).listen((data) {
      if (!mounted) return;
      setState(() => _orders = data);
      _autoCancelStale(data);
    });
    _walletSub = _db.streamFamilyWalletForUser(widget.customer.id).listen((
      wallet,
    ) {
      if (!mounted) return;
      _bindFamilyOrders(wallet?.id);
      setState(() {
        _wallet = wallet;
        _walletLoaded = true;
      });
    });
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  void _bindFamilyOrders(String? walletId) {
    if (walletId == _subscribedFamilyWalletId) return;
    _familyOrdersSub?.cancel();
    _familyOrdersSub = null;
    _familyOrders = null;
    _subscribedFamilyWalletId = walletId;
    if (walletId != null) {
      _familyOrdersSub = _db.streamOrdersForFamilyWallet(walletId).listen((
        data,
      ) {
        if (!mounted) return;
        setState(() => _familyOrders = data);
      });
    }
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _walletSub?.cancel();
    _familyOrdersSub?.cancel();
    _tick?.cancel();
    super.dispose();
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOwner = _wallet != null && _wallet!.isOwner(widget.customer.id);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Text(
                  'Orders',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
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
          Expanded(
            child: !_walletLoaded
                ? const Center(child: CircularProgressIndicator())
                : !isOwner
                ? _myOrdersList()
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Material(
                          color: theme.scaffoldBackgroundColor,
                          child: TabBar(
                            labelColor: scheme.primary,
                            indicatorColor: scheme.primary,
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
                              _familyOrdersList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _isPastOrder(OrderStatus status) {
    return status == OrderStatus.delivered ||
        status == OrderStatus.cancelled ||
        status == OrderStatus.rejected;
  }

  Widget _ordersBody({
    required List<Order> orders,
    required String Function(Order) nameForOrder,
  }) {
    if (orders.isEmpty) {
      return const Center(child: Text('No orders yet'));
    }

    final active = orders.where((o) => !_isPastOrder(o.status)).toList();
    final past = orders.where((o) => _isPastOrder(o.status)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (active.isNotEmpty) ...[
          _OrdersSectionHeader(title: 'Active Orders'),
          const SizedBox(height: 12),
          for (final order in active) ...[
            _OrderCard(
              order: order,
              customerName: nameForOrder(order),
              restaurantFuture: _restaurantFuture(order.restaurantId),
              isPast: false,
              onTap: () => _openDetail(order, nameForOrder(order)),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 16),
        ],
        if (past.isNotEmpty) ...[
          _OrdersSectionHeader(title: 'Past Orders'),
          const SizedBox(height: 12),
          for (final order in past) ...[
            _OrderCard(
              order: order,
              customerName: nameForOrder(order),
              restaurantFuture: _restaurantFuture(order.restaurantId),
              isPast: true,
              onTap: () => _openDetail(order, nameForOrder(order)),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }

  Widget _myOrdersList() {
    final orders = _orders;
    if (orders == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _ordersBody(
      orders: orders,
      nameForOrder: (_) => widget.customer.name,
    );
  }

  Widget _familyOrdersList() {
    final orders = _familyOrders;
    if (orders == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      return const Center(child: Text('No family wallet orders yet'));
    }

    final active = orders.where((o) => !_isPastOrder(o.status)).toList();
    final past = orders.where((o) => _isPastOrder(o.status)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (active.isNotEmpty) ...[
          _OrdersSectionHeader(title: 'Active Orders'),
          const SizedBox(height: 12),
          for (final order in active) ...[
            FutureBuilder<String>(
              future: _memberNameFuture(order.customerId),
              builder: (context, nameSnap) {
                final name = nameSnap.data ?? '…';
                return _OrderCard(
                  order: order,
                  customerName: name,
                  restaurantFuture: _restaurantFuture(order.restaurantId),
                  isPast: false,
                  onTap: () => _openDetail(order, name),
                );
              },
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 16),
        ],
        if (past.isNotEmpty) ...[
          _OrdersSectionHeader(title: 'Past Orders'),
          const SizedBox(height: 12),
          for (final order in past) ...[
            FutureBuilder<String>(
              future: _memberNameFuture(order.customerId),
              builder: (context, nameSnap) {
                final name = nameSnap.data ?? '…';
                return _OrderCard(
                  order: order,
                  customerName: name,
                  restaurantFuture: _restaurantFuture(order.restaurantId),
                  isPast: true,
                  onTap: () => _openDetail(order, name),
                );
              },
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }

  void _openDetail(Order order, String displayName) {
    final cart = CartScope.read(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CartScope(
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
  bool _isSkipping = false;

  @override
  void initState() {
    super.initState();

    _ticker = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _confirmCancelOrder() async {
    final shouldCancel = await showDestructiveConfirmDialog(
      context: context,
      title: 'Cancel Order?',
      message:
          'Are you sure you want to cancel this order? This action cannot be undone.',
      confirmLabel: 'Yes, Cancel',
      cancelLabel: 'Keep Order',
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

  Future<void> _skipTimer() async {
    setState(() => _isSkipping = true);
    try {
      await DatabaseService().skipCancelTimer(
        orderId: widget.orderId,
        customerId: widget.customerId,
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
      if (mounted) setState(() => _isSkipping = false);
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

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_isCancelling || _isSkipping)
                          ? null
                          : _confirmCancelOrder,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_isCancelling || _isSkipping)
                          ? null
                          : _skipTimer,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSkipping
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: colorScheme.onSurface,
                        ),
                      )
                          : const Icon(Icons.skip_next),
                      label: Text(
                        _isSkipping ? 'Skipping...' : 'Skip Timer',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrdersSectionHeader extends StatelessWidget {
  const _OrdersSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.customerName,
    required this.restaurantFuture,
    required this.isPast,
    required this.onTap,
  });

  final Order order;
  final String customerName;
  final Future<Restaurant?> restaurantFuture;
  final bool isPast;
  final VoidCallback onTap;

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $hour:$min';
  }

  String _phaseLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
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
      case OrderStatus.rejected:
        return 'Rejected';
    }
  }

  ({Color bg, Color fg}) _phaseColors(BuildContext context, OrderStatus s) {
    final scheme = Theme.of(context).colorScheme;
    switch (s) {
      case OrderStatus.pending:
        return (bg: const Color(0xFFFFF1C9), fg: const Color(0xFF7A5500));
      case OrderStatus.accepted:
        return (bg: const Color(0xFFDDEBFF), fg: const Color(0xFF1A3D7A));
      case OrderStatus.assigned:
        return (bg: const Color(0xFFD4EEF1), fg: const Color(0xFF0F5E66));
      case OrderStatus.pickedUp:
        return (bg: const Color(0xFFFFDDB5), fg: const Color(0xFF7A3E00));
      case OrderStatus.delivered:
        return (bg: const Color(0xFFD7F0DC), fg: const Color(0xFF1A5E2A));
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return (bg: scheme.errorContainer, fg: scheme.onErrorContainer);
    }
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
        final phaseColors = _phaseColors(context, order.status);

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
                    color: Colors.black.withValues(alpha: 0.06),
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
                              color: scheme.onSurfaceVariant,
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isPast)
                          Text(
                            '${order.totalPrice.toStringAsFixed(2)} SAR',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: phaseColors.bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _phaseLabel(order.status),
                              style: TextStyle(
                                color: phaseColors.fg,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        if (isPast)
                          Text(
                            _formatTime(order.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Text(
                            '${order.totalPrice.toStringAsFixed(2)} SAR',
                            style: theme.textTheme.titleSmall?.copyWith(
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
