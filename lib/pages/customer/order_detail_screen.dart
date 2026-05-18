import 'package:flutter/material.dart';
import 'package:yjeek/cart/cart_scope.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/customer.dart';
import 'package:yjeek/models/driver.dart';
import 'package:yjeek/models/order.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/models/restaurant_tag.dart';
import 'package:yjeek/pages/customer/cart_screen.dart';
import 'package:yjeek/pages/customer/customer_orders_screen.dart';
import 'package:yjeek/pages/customer/map_track_screen.dart';
import 'package:yjeek/pages/customer/rate_order_screen.dart';
import 'package:yjeek/utils/tax.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.customer,
    this.displayCustomerName,
  });

  final Order order;
  final Customer customer;
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

  String _statusLabel(OrderStatus status) {
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
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusPillBg(BuildContext context, OrderStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFFF1C9);
      case OrderStatus.accepted:
        return const Color(0xFFDDEBFF);
      case OrderStatus.assigned:
        return const Color(0xFFD4EEF1);
      case OrderStatus.pickedUp:
        return const Color(0xFFFFDDB5);
      case OrderStatus.delivered:
        return const Color(0xFFD7F0DC);
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return scheme.errorContainer;
    }
  }

  Color _statusPillFg(BuildContext context, OrderStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFF7A5500);
      case OrderStatus.accepted:
        return const Color(0xFF1A3D7A);
      case OrderStatus.assigned:
        return const Color(0xFF0F5E66);
      case OrderStatus.pickedUp:
        return const Color(0xFF7A3E00);
      case OrderStatus.delivered:
        return const Color(0xFF1A5E2A);
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return scheme.onErrorContainer;
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
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Order Details',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        centerTitle: true,
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
    final isCancelled =
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.rejected;
    final showMap =
        _canTrack(order.status) &&
        (order.driverId != null && order.driverId!.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (isCancelled) ...[
          _CancelledBlock(order: order),
          const SizedBox(height: 20),
        ],

        _HeaderCard(
          order: order,
          statusLabel: _statusLabel(order.status),
          statusBg: _statusPillBg(context, order.status),
          statusFg: _statusPillFg(context, order.status),
          formattedDate: _formatDateTime(order.createdAt),
        ),
        const SizedBox(height: 20),

        if (showMap) ...[
          _OrderMapCard(order: order),
          const SizedBox(height: 16),
          _DriverCard(driverId: order.driverId!),
          const SizedBox(height: 20),
        ],

        if (!isCancelled) ...[
          _PhaseIndicator(status: order.status),
          const SizedBox(height: 24),
        ],

        _RestaurantDetailsCard(restaurantId: order.restaurantId),
        const SizedBox(height: 20),

        if (!showMap &&
            order.status != OrderStatus.delivered &&
            order.driverId != null &&
            order.driverId!.isNotEmpty) ...[
          _DriverCard(driverId: order.driverId!),
          const SizedBox(height: 20),
        ],

        if (order.status == OrderStatus.pending &&
            order.canCancelUntil != null) ...[
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
          const SizedBox(height: 16),
        ],

        if (order.status == OrderStatus.delivered) ...[
          if (!order.isRated) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _openRatingSheet(order),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.star_outline),
                label: const Text(
                  'Rate Order',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _orderSameOrderAgain(order),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Order again',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        _OrderSummaryCard(order: order),
      ],
    );
  }
}

// =============================================================================
// Cancelled block
// =============================================================================

class _CancelledBlock extends StatelessWidget {
  const _CancelledBlock({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRejected = order.status == OrderStatus.rejected;
    final title = isRejected
        ? 'Order rejected by the restaurant'
        : 'Order Cancelled';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.error,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onErrorContainer,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The order total has been refunded to your wallet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onErrorContainer.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Header card: Order # + status pill, date/time below
// =============================================================================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.order,
    required this.statusLabel,
    required this.statusBg,
    required this.statusFg,
    required this.formattedDate,
  });

  final Order order;
  final String statusLabel;
  final Color statusBg;
  final Color statusFg;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '#${order.id}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formattedDate,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Phase indicator (horizontal row of icon circles connected by lines)
// =============================================================================

class _PhaseIndicator extends StatelessWidget {
  const _PhaseIndicator({required this.status});

  final OrderStatus status;

  bool _isComplete(int index) {
    // 0 placed, 1 confirmed, 2 preparing/assigned, 3 out for delivery, 4 delivered
    switch (status) {
      case OrderStatus.pending:
        return index <= 0;
      case OrderStatus.accepted:
        return index <= 1;
      case OrderStatus.assigned:
        return index <= 2;
      case OrderStatus.pickedUp:
        return index <= 3;
      case OrderStatus.delivered:
        return index <= 4;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const icons = [
      Icons.receipt_long_rounded,
      Icons.outdoor_grill_rounded,
      Icons.two_wheeler_rounded,
      Icons.location_on_rounded,
      Icons.home_rounded,
    ];

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          for (var i = 0; i < icons.length; i++) ...[
            _PhaseDot(
              icon: icons[i],
              complete: _isComplete(i),
              scheme: scheme,
            ),
            if (i < icons.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: _isComplete(i + 1)
                      ? scheme.primary
                      : scheme.outlineVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PhaseDot extends StatelessWidget {
  const _PhaseDot({
    required this.icon,
    required this.complete,
    required this.scheme,
  });

  final IconData icon;
  final bool complete;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: complete ? scheme.primary : scheme.surfaceContainer,
        border: Border.all(
          color: complete ? scheme.primary : scheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: 18,
        color: complete ? scheme.onPrimary : scheme.outline,
      ),
    );
  }
}

// =============================================================================
// Restaurant details card (no image)
// =============================================================================

class _RestaurantDetailsCard extends StatelessWidget {
  const _RestaurantDetailsCard({required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                color: scheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Restaurant Details',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          const SizedBox(height: 14),
          FutureBuilder<Restaurant?>(
            future: DatabaseService().getRestaurantById(restaurantId),
            builder: (context, snap) {
              final restaurant = snap.data;
              if (restaurant == null) {
                return Text(
                  'Restaurant',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }
              final tagsLabel = restaurant.tags
                  .take(2)
                  .map((t) => t.label)
                  .join(' · ');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tagsLabel,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Color(0xFFE9C176),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              restaurant.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Driver card (name, rating, message + call buttons) — no profile image
// =============================================================================

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driverId});

  final String driverId;

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    var cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '966${cleaned.substring(1)}';
    } else if (cleaned.startsWith('5')) {
      cleaned = '966$cleaned';
    }
    final uri = Uri.parse('https://wa.me/$cleaned');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _callDriver(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: '+966$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Driver?>(
      stream: DatabaseService().streamDriverById(driverId),
      builder: (context, snap) {
        final driver = snap.data;
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver?.name ?? 'Your Driver',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: scheme.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          driver == null
                              ? 'Loading...'
                              : driver.rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _CircleAction(
                icon: Icons.chat_bubble_outline_rounded,
                filled: false,
                onTap: driver == null
                    ? null
                    : () => _openWhatsApp(context, driver.phone),
              ),
              const SizedBox(width: 10),
              _CircleAction(
                icon: Icons.phone_rounded,
                filled: true,
                onTap: driver == null
                    ? null
                    : () => _callDriver(context, driver.phone),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      shape: const CircleBorder(),
      color: filled ? scheme.primary : scheme.surfaceContainerLowest,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: filled
                ? null
                : Border.all(color: scheme.outlineVariant, width: 1),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: filled ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Map card (shown when driver is en route)
// =============================================================================

class _OrderMapCard extends StatelessWidget {
  const _OrderMapCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final restaurantLatLng = LatLng(
      order.restaurantLocation.latitude,
      order.restaurantLocation.longitude,
    );
    final customerLatLng = LatLng(
      order.customerLocation.latitude,
      order.customerLocation.longitude,
    );
    final mid = LatLng(
      (restaurantLatLng.latitude + customerLatLng.latitude) / 2,
      (restaurantLatLng.longitude + customerLatLng.longitude) / 2,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MapScreen(order: order)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              AbsorbPointer(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: mid, zoom: 12),
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  liteModeEnabled: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId('restaurant'),
                      position: restaurantLatLng,
                    ),
                    Marker(
                      markerId: const MarkerId('customer'),
                      position: customerLatLng,
                    ),
                  },
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.navigation_rounded,
                        color: scheme.onPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Track on Map',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Order Summary (items + subtotal + delivery + total)
// =============================================================================

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final itemsInclTax = order.items.fold<double>(
      0,
      (sum, i) => sum + i.priceAtPurchase * i.quantity,
    );
    final tax = itemsInclTax * kTaxRate;
    final subtotal = itemsInclTax - tax;
    final deliveryFee = (order.totalPrice - itemsInclTax)
        .clamp(0, double.infinity)
        .toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: scheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Order Summary',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          const SizedBox(height: 6),
          for (final item in order.items) _OrderItemRow(item: item),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Subtotal', value: subtotal),
          const SizedBox(height: 10),
          _SummaryLine(label: 'Taxes (15%)', value: tax),
          if (deliveryFee > 0) ...[
            const SizedBox(height: 10),
            _SummaryLine(label: 'Delivery Fee', value: deliveryFee),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${order.totalPrice.toStringAsFixed(2)} SAR',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineTotal = item.priceAtPurchase * item.quantity;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${item.quantity}x  ${item.name}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${lineTotal.toStringAsFixed(2)} SAR',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (item.selectedOptions.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final opt in item.selectedOptions)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '· ${opt.choiceName}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (opt.extraPrice > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '+${(opt.extraPrice * item.quantity).toStringAsFixed(2)} SAR',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)} SAR',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
