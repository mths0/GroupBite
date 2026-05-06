// lib/pages/customer/checkout_screen.dart
//
// Displays the Checkout flow: address selection, delivery time selection,
// and payment method selection. Pre-calculated totals are passed in from
// CartScreen so there is no duplication of logic.
// All state is managed with plain setState.

import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/order.dart';

import 'package:food_delivery_platform/models/cart_models.dart';
import 'package:food_delivery_platform/models/family_wallet.dart';
import 'package:food_delivery_platform/models/family_wallet_member.dart';
import 'package:food_delivery_platform/models/saved_card.dart';
import 'package:food_delivery_platform/pages/customer/card_form_sheet.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';

//! This class needs to be refactored and cleaned up
//Todo This class needs to be refactored and cleaned up
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.checkoutData,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.discount,
    required this.total,
    required this.customerId,
    required this.restaurantId,
    this.appliedCoupon,
    this.groupOrderId,
    this.isGroupHost = false,
    this.onOrderPlaced,
  });

  /// Immutable snapshot of cart items for display/confirmation.
  final List<CartItem> cartItems;
  final CheckoutData checkoutData;
  final Coupon? appliedCoupon;
  final String customerId;
  final String restaurantId;
  final String? groupOrderId;
  final bool isGroupHost;
  final VoidCallback? onOrderPlaced;

  /// Pre-computed values forwarded from CartScreen.
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double total;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

// ---------------------------------------------------------------------------
// Delivery Time selection options
// ---------------------------------------------------------------------------
enum _DeliveryTimeOption { asap, schedule }

// ---------------------------------------------------------------------------
// Payment method identifiers — kept as simple strings matching model IDs
// so the selection state is just a String? field.
// ---------------------------------------------------------------------------
const String _kPaymentCreditCard = 'pay_credit';
const String _kPaymentWallet = 'pay_wallet';
const String _kPaymentFamilyWallet = 'pay_family_wallet';

class _CheckoutScreenState extends State<CheckoutScreen> {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final DatabaseService _db = DatabaseService();

  /// Whether delivery is ASAP or scheduled.
  _DeliveryTimeOption _deliveryTimeOption = _DeliveryTimeOption.asap;

  /// Populated when the user picks a scheduled delivery.
  DateTime? _scheduledDateTime;

  /// ID of the currently selected payment method.
  String _selectedPaymentId = _kPaymentCreditCard;

  /// True while the "Place Order" call is in progress.
  bool _isPlacingOrder = false;

  bool get _isGroupCheckout => widget.groupOrderId != null;

  bool get _shouldShowDeliveryTime {
    if (!_isGroupCheckout) return true;

    return widget.isGroupHost;
  }

  /// Latest family wallet snapshot, kept in sync via a stream subscription so
  /// _placeOrder can read the wallet ID without re-querying.
  FamilyWallet? _familyWallet;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
  }

  // ---------------------------------------------------------------------------
  // Delivery Time
  // ---------------------------------------------------------------------------

  Future<void> _onDeliveryTimeTapped(_DeliveryTimeOption option) async {
    if (option == _DeliveryTimeOption.asap) {
      setState(() {
        _deliveryTimeOption = _DeliveryTimeOption.asap;
        _scheduledDateTime = null;
      });
      return;
    }

    // ── Schedule: show date picker then time picker ───────────────────────
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'Select delivery date',
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      helpText: 'Select delivery time',
    );

    if (pickedTime == null || !mounted) return;

    final scheduled = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _deliveryTimeOption = _DeliveryTimeOption.schedule;
      _scheduledDateTime = scheduled;
    });
  }

  // ---------------------------------------------------------------------------
  // Add Card (from checkout)
  // ---------------------------------------------------------------------------

  Future<void> _openAddCardSheet() async {
    final input = await showModalBottomSheet<CardInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CardFormSheet(),
    );

    if (input == null) return;

    try {
      await _db.addCustomerCard(
        customerId: widget.customerId,
        card: SavedCard(
          id: IdGenerator.generateCardId(),
          brand: SavedCard.brandFromNumber(input.number),
          last4: SavedCard.last4FromNumber(input.number),
          expiry: input.expiry,
          holderName: input.holderName,
          isDefault: true,
        ),
      );
      if (!mounted) return;
      setState(() => _selectedPaymentId = _kPaymentCreditCard);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save card: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Place Order
  // ---------------------------------------------------------------------------

  Future<void> _placeOrder() async {
    setState(() => _isPlacingOrder = true);

    try {
      if (_selectedPaymentId == _kPaymentWallet) {
        await _db.deductFromWallet(
          customerId: widget.customerId,
          amount: widget.total,
        );
      } else if (_selectedPaymentId == _kPaymentFamilyWallet) {
        final wallet = _familyWallet;
        if (wallet == null) {
          throw Exception('Family wallet not loaded');
        }
        await _db.deductFromFamilyWallet(
          walletId: wallet.id,
          userId: widget.customerId,
          amount: widget.total,
        );
      }

      // GROUP CHECKOUT:
      // Member only pays their part. Do NOT create order yet.
      if (widget.groupOrderId != null) {
        final result = await _db.payGroupMemberAndMaybePlaceOrder(
          groupOrderId: widget.groupOrderId!,
          customerId: widget.customerId,
          restaurantId: widget.restaurantId,
        );

        if (!mounted) return;

        setState(() => _isPlacingOrder = false);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(
              result.finalOrderPlaced
                  ? 'Group Order Placed 🎉'
                  : 'Payment Done',
            ),
            content: Text(
              result.finalOrderPlaced
                  ? 'Everyone has paid. The final group order has been placed successfully.'
                  : 'Your part of ${widget.total.toStringAsFixed(2)} SAR has been paid successfully.\n\n'
                        'You will now return to the home page.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );

        return;
      }

      // NORMAL CHECKOUT:
      // Create normal order immediately.
      final orderItems = widget.cartItems
          .map(
            (item) => OrderItem(
              menuId: item.id,
              name: item.name,
              quantity: item.quantity,
              priceAtPurchase: item.unitPrice,
            ),
          )
          .toList();

      await _db.addOrder(
        customerId: widget.customerId,
        restaurantId: widget.restaurantId,
        totalPrice: widget.total,
        items: orderItems,
      );

      if (!mounted) return;

      widget.onOrderPlaced?.call();

      setState(() => _isPlacingOrder = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Order Placed! 🎉'),
          content: Text(
            'Your order of ${widget.total.toStringAsFixed(2)} SAR has been placed.\n\n'
            '${_deliveryTimeOption == _DeliveryTimeOption.asap ? 'Estimated arrival: 25–35 min' : 'Scheduled for: ${_formatScheduled()}'}',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context)
                  ..pop()
                  ..pop()
                  ..pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isPlacingOrder = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatScheduled() {
    if (_scheduledDateTime == null) return '';
    final dt = _scheduledDateTime!;
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $hour:$min';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isGroupCheckout
              ? widget.isGroupHost
                    ? 'Host Checkout'
                    : 'Pay Your Part'
              : 'Checkout',
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildPlaceOrderBar(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (_isGroupCheckout)
          _SectionCard(
            title: widget.isGroupHost
                ? 'Host Checkout'
                : 'Group Member Checkout',
            icon: Icons.groups_outlined,
            child: Text(
              widget.isGroupHost
                  ? 'You are the host. After you pay, the final group order will be placed.'
                  : 'You are paying only your part of the group order.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

        if (_isGroupCheckout) const SizedBox(height: 12),

        if (_shouldShowDeliveryTime) ...[
          _SectionCard(
            title: 'Delivery Time',
            icon: Icons.schedule_outlined,
            child: _DeliveryTimeSelector(
              selected: _deliveryTimeOption,
              scheduledDateTime: _scheduledDateTime,
              onTap: _onDeliveryTimeTapped,
            ),
          ),
          const SizedBox(height: 12),
        ],

        _SectionCard(
          title: 'Payment Method',
          icon: Icons.credit_card_outlined,
          child: StreamBuilder<List<SavedCard>>(
            stream: _db.streamCustomerCards(widget.customerId),
            builder: (context, cardsSnap) {
              final cards = cardsSnap.data ?? [];
              final card = cards.isEmpty ? null : cards.first;

              return StreamBuilder<double>(
                stream: _db.streamWalletBalance(widget.customerId),
                builder: (context, balanceSnap) {
                  final balance = balanceSnap.data ?? 0.0;
                  final hasEnough = balance >= widget.total;

                  return StreamBuilder<FamilyWallet?>(
                    stream: _db.streamFamilyWalletForUser(widget.customerId),
                    builder: (context, familySnap) {
                      final family = familySnap.data;
                      // Cache for _placeOrder — schedule after build to avoid
                      // calling setState during a build pass.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (_familyWallet?.id != family?.id ||
                            _familyWallet?.balance != family?.balance) {
                          setState(() => _familyWallet = family);
                        }
                      });
                      return Column(
                        children: [
                          if (card == null)
                            _PaymentTile(
                              id: 'add_card',
                              label: 'Add Card',
                              subtitle: 'No card on file — tap to add one',
                              icon: Icons.add_card,
                              isSelected: false,
                              onTap: _openAddCardSheet,
                            )
                          else
                            _PaymentTile(
                              id: _kPaymentCreditCard,
                              label: card.brand,
                              subtitle: '•••• ${card.last4}',
                              icon: Icons.credit_card_rounded,
                              isSelected:
                                  _selectedPaymentId == _kPaymentCreditCard,
                              onTap: () => setState(
                                () => _selectedPaymentId = _kPaymentCreditCard,
                              ),
                            ),
                          const SizedBox(height: 8),
                          _PaymentTile(
                            id: _kPaymentWallet,
                            label: 'Wallet',
                            subtitle: hasEnough
                                ? 'Balance: ${balance.toStringAsFixed(2)} SAR'
                                : 'Insufficient balance — ${balance.toStringAsFixed(2)} SAR',
                            icon: Icons.account_balance_wallet_outlined,
                            isSelected: _selectedPaymentId == _kPaymentWallet,
                            disabled: !hasEnough,
                            onTap: () => setState(
                              () => _selectedPaymentId = _kPaymentWallet,
                            ),
                          ),
                          if (family != null) ...[
                            const SizedBox(height: 8),
                            _FamilyWalletTile(
                              family: family,
                              currentUserId: widget.customerId,
                              total: widget.total,
                              isSelected: _selectedPaymentId ==
                                  _kPaymentFamilyWallet,
                              onSelected: () => setState(
                                () => _selectedPaymentId =
                                    _kPaymentFamilyWallet,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        _SectionCard(
          title: _isGroupCheckout ? 'Your Part Summary' : 'Order Summary',
          icon: Icons.receipt_long_outlined,
          child: _CheckoutSummary(
            subtotal: widget.subtotal,
            deliveryFee: widget.deliveryFee,
            tax: widget.tax,
            discount: widget.discount,
            total: widget.total,
            appliedCoupon: widget.appliedCoupon,
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlaceOrderBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _isPlacingOrder ? null : _placeOrder,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isPlacingOrder
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  !_isGroupCheckout
                      ? 'Place Order  •  ${widget.total.toStringAsFixed(2)} SAR'
                      : widget.isGroupHost
                      ? 'Pay Last & Place Order  •  ${widget.total.toStringAsFixed(2)} SAR'
                      : 'Pay My Part  •  ${widget.total.toStringAsFixed(2)} SAR',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// Private Sub-Widgets
// =============================================================================

/// Generic card wrapper used for every section on the checkout screen.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Two-button selector for ASAP vs. Schedule delivery time.
class _DeliveryTimeSelector extends StatelessWidget {
  const _DeliveryTimeSelector({
    required this.selected,
    required this.scheduledDateTime,
    required this.onTap,
  });

  final _DeliveryTimeOption selected;
  final DateTime? scheduledDateTime;
  final Future<void> Function(_DeliveryTimeOption) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // ASAP tile
            Expanded(
              child: _DeliveryOptionTile(
                label: 'ASAP',
                subtitle: '25–35 min',
                isSelected: selected == _DeliveryTimeOption.asap,
                onTap: () => onTap(_DeliveryTimeOption.asap),
              ),
            ),
            const SizedBox(width: 10),
            // Schedule tile
            Expanded(
              child: _DeliveryOptionTile(
                label: 'Schedule',
                subtitle:
                    selected == _DeliveryTimeOption.schedule &&
                        scheduledDateTime != null
                    ? _formatDate(scheduledDateTime!)
                    : 'Choose time',
                isSelected: selected == _DeliveryTimeOption.schedule,
                onTap: () => onTap(_DeliveryTimeOption.schedule),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $h:$m';
  }
}

/// A single tile option inside the delivery time selector.
class _DeliveryOptionTile extends StatelessWidget {
  const _DeliveryOptionTile({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 1.8 : 0.8,
          ),
          color: isSelected
              ? colorScheme.primaryContainer.withOpacity(0.25)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// A selectable tile representing a payment method.
class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.disabled = false,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 1.8 : 0.8,
        ),
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.25)
            : Colors.transparent,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHigh,
            child: Icon(
              icon,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: disabled
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Radio<String>(
            value: id,
            groupValue: isSelected ? id : null,
            onChanged: disabled ? null : (_) => onTap(),
            activeColor: colorScheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );

    if (disabled) {
      return Opacity(
        opacity: 0.5,
        child: AbsorbPointer(child: tile),
      );
    }

    return GestureDetector(onTap: onTap, child: tile);
  }
}

// ---------------------------------------------------------------------------

/// Family-wallet payment tile. Computes the effective spendable amount
/// (`min(remainingLimit, balance)` for members; `balance` for the owner)
/// and disables the tile when that amount is below the order total.
class _FamilyWalletTile extends StatelessWidget {
  const _FamilyWalletTile({
    required this.family,
    required this.currentUserId,
    required this.total,
    required this.isSelected,
    required this.onSelected,
  });

  final FamilyWallet family;
  final String currentUserId;
  final double total;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isOwner = family.ownerId == currentUserId;

    if (isOwner) {
      // Owner spends without per-member limits.
      final hasEnough = family.balance >= total;
      return _PaymentTile(
        id: _kPaymentFamilyWallet,
        label: 'Family Wallet',
        subtitle: hasEnough
            ? 'Available: ${family.balance.toStringAsFixed(2)} SAR'
            : 'Insufficient balance — ${family.balance.toStringAsFixed(2)} SAR',
        icon: Icons.family_restroom,
        isSelected: isSelected,
        disabled: !hasEnough,
        onTap: onSelected,
      );
    }

    return StreamBuilder<FamilyWalletMember?>(
      stream: DatabaseService().streamFamilyWalletMember(
        walletId: family.id,
        userId: currentUserId,
      ),
      builder: (context, snap) {
        final member = snap.data;
        final spent = member?.effectiveSpent(DateTime.now()) ?? 0.0;
        final limit = member?.limit;

        final remainingLimit = limit == null
            ? family.balance
            : (limit - spent).clamp(0.0, double.infinity);
        final available =
            remainingLimit < family.balance ? remainingLimit : family.balance;

        final hasEnough = available >= total;
        final overLimit = limit != null && remainingLimit <= 0;

        String subtitle;
        if (overLimit) {
          subtitle = 'Spending limit reached';
        } else if (hasEnough) {
          subtitle = 'Available: ${available.toStringAsFixed(2)} SAR';
        } else {
          subtitle =
              'Insufficient — only ${available.toStringAsFixed(2)} SAR available';
        }

        return _PaymentTile(
          id: _kPaymentFamilyWallet,
          label: 'Family Wallet',
          subtitle: subtitle,
          icon: Icons.family_restroom,
          isSelected: isSelected,
          disabled: !hasEnough,
          onTap: onSelected,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

/// Read-only order summary displayed at the bottom of the Checkout screen.
class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.discount,
    required this.total,
    this.appliedCoupon,
  });

  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double total;
  final Coupon? appliedCoupon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _SummaryRow(label: 'Subtotal', value: subtotal),
        const SizedBox(height: 8),
        _SummaryRow(label: 'Delivery Fee', value: deliveryFee),
        const SizedBox(height: 8),
        _SummaryRow(label: 'Tax (15%)', value: tax),
        if (appliedCoupon != null) ...[
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Discount (${appliedCoupon!.label})',
            value: -discount,
            valueColor: Colors.green,
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${total.toStringAsFixed(2)} SAR',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final double value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final display = value < 0
        ? '-${(-value).toStringAsFixed(2)} SAR'
        : '${value.toStringAsFixed(2)} SAR';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          display,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
