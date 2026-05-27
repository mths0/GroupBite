import 'package:flutter/material.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/abstract_user.dart';
import 'package:yjeek/models/order.dart';
import 'package:yjeek/pages/restaurant/restaurant_order_status.dart';
import 'package:yjeek/utils/tax.dart';
import 'package:yjeek/widgets/app_snack.dart';

class RestaurantOrderDetailScreen extends StatefulWidget {
  const RestaurantOrderDetailScreen({
    super.key,
    required this.order,
  });

  final Order order;

  @override
  State<RestaurantOrderDetailScreen> createState() =>
      _RestaurantOrderDetailScreenState();
}

class _RestaurantOrderDetailScreenState
    extends State<RestaurantOrderDetailScreen> {
  final DatabaseService _db = DatabaseService();
  late Order _order = widget.order;
  bool _busy = false;

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $hour:$min';
  }

  Future<void> _updateStatus(OrderStatus status) async {
    setState(() => _busy = true);
    try {
      if (status == OrderStatus.accepted) {
        await _db.restaurantAcceptOrder(_order.id);
      } else if (status == OrderStatus.rejected) {
        await _db.restaurantRejectOrder(_order.id);
      } else {
        await _db.updateOrderStatus(orderId: _order.id, status: status);
      }

      if (!mounted) return;

      showAppSnack(
        context,
        'Order ${restaurantStatusLabel(status).toLowerCase()}',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppError(context, 'Failed to update order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final order = _order;
    final status = restaurantStatusColors(context, order.status);
    final isPending = order.status == OrderStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order details',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              children: [
                Container(
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
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: status.background,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              restaurantStatusLabel(order.status),
                              style: TextStyle(
                                color: status.foreground,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDateTime(order.createdAt),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (order.scheduledFor != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: scheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Scheduled for ${_formatDateTime(order.scheduledFor!)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FutureBuilder<User?>(
                  future: _db.getUserById(order.customerId),
                  builder: (context, snap) {
                    final name = snap.data?.name ?? 'Customer';
                    return Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: scheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Customer',
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: scheme.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${order.customerId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _OrderSummaryCard(order: order),
              ],
            ),
          ),
          if (isPending)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(height: 1, color: scheme.outlineVariant),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _updateStatus(OrderStatus.rejected),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text(
                              'Reject',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: scheme.errorContainer
                                  .withValues(alpha: 0.35),
                              foregroundColor: scheme.error,
                              side: BorderSide(
                                color: scheme.error.withValues(alpha: 0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _updateStatus(OrderStatus.accepted),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final itemsInclTax = order.items.fold<double>(
      0,
      (sum, i) => sum + i.priceAtPurchase * i.quantity,
    );
    final tax = itemsInclTax * kTaxRate;
    final subtotal = itemsInclTax - tax;
    // Prefer stored values from the order doc so the breakdown survives
    // promos (a free-delivery promo brings totalPrice down to items, which
    // makes the reverse-engineered deliveryFee compute as 0).
    final discount = order.discount ?? 0;
    final deliveryFee = order.deliveryFee ??
        (order.totalPrice + discount - itemsInclTax)
            .clamp(0, double.infinity)
            .toDouble();
    final gross = itemsInclTax + deliveryFee;
    final totalPaid = order.totalPrice;

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
          for (final item in order.items) _SummaryItemRow(item: item),
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
                '${gross.toStringAsFixed(2)} SAR',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Paid by Customer',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${totalPaid.toStringAsFixed(2)} SAR',
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

class _SummaryItemRow extends StatelessWidget {
  const _SummaryItemRow({required this.item});

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
          if (item.customizationSummary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.customizationSummary,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                fontStyle: FontStyle.italic,
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)} SAR',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

