import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/cart_models.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/family_wallet.dart';
import 'package:food_delivery_platform/models/family_wallet_member.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/models/saved_card.dart';
import 'package:food_delivery_platform/pages/customer/card_form_sheet.dart';
import 'package:food_delivery_platform/pages/customer/order_detail_screen.dart';
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

class _CheckoutScreenState extends State<CheckoutScreen> {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final DatabaseService _db = DatabaseService();

  /// Whether delivery is ASAP or scheduled.
  _DeliveryTimeOption _deliveryTimeOption = _DeliveryTimeOption.asap;

  /// Populated when the user picks a scheduled delivery.
  DateTime? _scheduledDateTime;

  /// Whether the user opted to apply their personal wallet balance.
  bool _useWallet = false;

  /// Whether the user opted to apply their family wallet balance.
  bool _useFamilyWallet = false;

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

  /// Live wallet balance, kept in sync from the wallet stream.
  double _walletBalance = 0.0;

  /// Live family-wallet spendable amount (member-limit aware).
  double _familyAvailable = 0.0;

  /// Whether the customer has a saved card on file.
  bool _hasCard = false;

  ({double wallet, double family, double card}) get _split {
    final w = _useWallet ? math.min(_walletBalance, widget.total) : 0.0;
    final remaining = widget.total - w;
    final f = _useFamilyWallet ? math.min(_familyAvailable, remaining) : 0.0;
    final c = remaining - f;
    return (wallet: w, family: f, card: c);
  }

  void _syncAfterBuild({
    bool? hasCard,
    double? walletBalance,
    double? familyAvailable,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      var changed = false;
      if (hasCard != null && _hasCard != hasCard) {
        _hasCard = hasCard;
        changed = true;
      }
      if (walletBalance != null && _walletBalance != walletBalance) {
        _walletBalance = walletBalance;
        if (walletBalance <= 0 && _useWallet) _useWallet = false;
        changed = true;
      }
      if (familyAvailable != null && _familyAvailable != familyAvailable) {
        _familyAvailable = familyAvailable;
        if (familyAvailable <= 0 && _useFamilyWallet) _useFamilyWallet = false;
        changed = true;
      }

      if (changed) setState(() {});
    });
  }

  void _syncFamilyAfterBuild(FamilyWallet? family) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      var changed = false;
      if (family == null) {
        if (_familyWallet != null) {
          _familyWallet = null;
          _familyAvailable = 0.0;
          if (_useFamilyWallet) _useFamilyWallet = false;
          changed = true;
        }
      } else if (_familyWallet?.id != family.id ||
          _familyWallet?.balance != family.balance) {
        _familyWallet = family;
        changed = true;
      }

      if (changed) setState(() {});
    });
  }

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

    var groupAmountToRefundOnFailure = 0.0;

    try {
      final restaurant = await _db.getRestaurantById(widget.restaurantId);
      if (!mounted) return;
      if (restaurant == null || !restaurant.isOpen) {
        setState(() => _isPlacingOrder = false);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Restaurant is closed'),
            content: const Text(
              'This restaurant is no longer accepting orders. '
              'You will be returned to the home page.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      final split = _split;

      if (split.wallet > 0) {
        await _db.deductFromWallet(
          customerId: widget.customerId,
          amount: split.wallet,
        );
        if (widget.groupOrderId != null) {
          groupAmountToRefundOnFailure += split.wallet;
        }
      }
      if (split.family > 0) {
        final wallet = _familyWallet;
        if (wallet == null) {
          throw Exception('Family wallet not loaded');
        }
        await _db.deductFromFamilyWallet(
          walletId: wallet.id,
          userId: widget.customerId,
          amount: split.family,
        );
        if (widget.groupOrderId != null) {
          groupAmountToRefundOnFailure += split.family;
        }
      }

      // GROUP CHECKOUT:
      // Member only pays their part. Do NOT create order yet.
      if (widget.groupOrderId != null) {
        final result = await _db.payGroupMemberAndMaybePlaceOrder(
          groupOrderId: widget.groupOrderId!,
          customerId: widget.customerId,
          restaurantId: widget.restaurantId,
          paidAmount: widget.total,
        );
        groupAmountToRefundOnFailure = 0;

        if (!mounted) return;

        setState(() => _isPlacingOrder = false);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(
              result ? 'Group Order Placed 🎉' : 'Payment Done',
            ),
            content: Text(
              result
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
              selectedOptions: item.selectedOptions,
            ),
          )
          .toList();

      final placedOrder = await _db.addOrder(
        customerId: widget.customerId,
        restaurantId: widget.restaurantId,
        totalPrice: widget.total,
        items: orderItems,
        scheduledFor: _deliveryTimeOption == _DeliveryTimeOption.schedule
            ? _scheduledDateTime
            : null,
        familyWalletId: split.family > 0 ? _familyWallet?.id : null,
      );

      final user = await _db.getUserById(widget.customerId);
      final customer = user is Customer ? user : null;

      if (!mounted) return;

      widget.onOrderPlaced?.call();

      setState(() => _isPlacingOrder = false);

      final theme = Theme.of(context);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Order Placed!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _deliveryTimeOption == _DeliveryTimeOption.asap
                      ? 'Your order of ${widget.total.toStringAsFixed(2)} SAR has been placed.'
                      : 'Your order of ${widget.total.toStringAsFixed(2)} SAR has been placed.\n'
                            'Scheduled for: ${_formatScheduled()}',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text('View order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted) return;

      if (customer != null) {
        final cart = CartScope.read(context);
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CartScope(
              notifier: cart,
              child: OrderDetailScreen(
                order: placedOrder,
                customer: customer,
              ),
            ),
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (groupAmountToRefundOnFailure > 0) {
        try {
          await _db.addFundsToWallet(
            customerId: widget.customerId,
            amount: groupAmountToRefundOnFailure,
          );
        } catch (_) {
          // Best-effort rollback. The original error is still shown below.
        }
      }

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
              _syncAfterBuild(hasCard: card != null);

              return StreamBuilder<double>(
                stream: _db.streamWalletBalance(widget.customerId),
                builder: (context, balanceSnap) {
                  final balance = balanceSnap.data ?? 0.0;
                  _syncAfterBuild(walletBalance: balance);

                  return StreamBuilder<FamilyWallet?>(
                    stream: _db.streamFamilyWalletForUser(widget.customerId),
                    builder: (context, familySnap) {
                      final family = familySnap.data;
                      _syncFamilyAfterBuild(family);

                      return Column(
                        children: [
                          if (card == null)
                            _PaymentTile(
                              label: 'Add Card',
                              subtitle: 'No card on file — tap to add one',
                              icon: Icons.add_card,
                              isSelected: false,
                              onTap: _openAddCardSheet,
                            )
                          else
                            _PaymentTile(
                              label: card.brand,
                              subtitle: '•••• ${card.last4}',
                              icon: Icons.credit_card_rounded,
                              isSelected: true,
                              onTap: null,
                            ),
                          const SizedBox(height: 8),
                          _PaymentTile(
                            label: 'Wallet',
                            subtitle: balance > 0
                                ? 'Balance: ${balance.toStringAsFixed(2)} SAR'
                                : 'No balance',
                            icon: Icons.account_balance_wallet_outlined,
                            isSelected: _useWallet,
                            isToggle: true,
                            disabled: balance <= 0,
                            onTap: () =>
                                setState(() => _useWallet = !_useWallet),
                          ),
                          if (family != null) ...[
                            const SizedBox(height: 8),
                            _FamilyWalletTile(
                              family: family,
                              currentUserId: widget.customerId,
                              isOn: _useFamilyWallet,
                              onToggle: () => setState(
                                () => _useFamilyWallet = !_useFamilyWallet,
                              ),
                              onAvailableChanged: (v) =>
                                  _syncAfterBuild(familyAvailable: v),
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
            walletCredit: _split.wallet,
            familyCredit: _split.family,
            cardCharge: _split.card,
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlaceOrderBar() {
    final cardNeeded = _split.card > 0 && !_hasCard;
    final disabled = _isPlacingOrder || cardNeeded;
    final amount = _split.card.toStringAsFixed(2);
    final label = cardNeeded
        ? 'Insufficient funds'
        : !_isGroupCheckout
        ? 'Place Order  •  $amount SAR'
        : widget.isGroupHost
        ? 'Pay Last & Place Order  •  $amount SAR'
        : 'Pay My Part  •  $amount SAR';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: disabled ? null : _placeOrder,
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
                  label,
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
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
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
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// A payment-method tile. Renders a checkbox when [isToggle] is true (used for
/// the wallet/family-wallet apply-toggles); otherwise renders a check icon
/// indicating the implicit primary method.
class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.disabled = false,
    this.isToggle = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool disabled;
  final bool isToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Widget trailing;
    if (isToggle) {
      trailing = Checkbox(
        value: isSelected,
        onChanged: disabled || onTap == null ? null : (_) => onTap!(),
        activeColor: colorScheme.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    } else {
      trailing = Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? colorScheme.primary : colorScheme.outline,
      );
    }

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
          trailing,
        ],
      ),
    );

    if (disabled) {
      return Opacity(
        opacity: 0.5,
        child: AbsorbPointer(child: tile),
      );
    }

    if (onTap == null) return tile;
    return GestureDetector(onTap: onTap, child: tile);
  }
}

// ---------------------------------------------------------------------------

/// Family-wallet apply-toggle. Computes the effective spendable amount
/// (`min(remainingLimit, balance)` for members; `balance` for the owner)
/// and reports it via [onAvailableChanged] so the checkout state can compute
/// the payment split. Tapping toggles whether the credit is applied.
class _FamilyWalletTile extends StatelessWidget {
  const _FamilyWalletTile({
    required this.family,
    required this.currentUserId,
    required this.isOn,
    required this.onToggle,
    required this.onAvailableChanged,
  });

  final FamilyWallet family;
  final String currentUserId;
  final bool isOn;
  final VoidCallback onToggle;
  final ValueChanged<double> onAvailableChanged;

  @override
  Widget build(BuildContext context) {
    final isOwner = family.ownerId == currentUserId;

    if (isOwner) {
      onAvailableChanged(family.balance);
      return _PaymentTile(
        label: 'Family Wallet',
        subtitle: family.balance > 0
            ? 'Available: ${family.balance.toStringAsFixed(2)} SAR'
            : 'No balance',
        icon: Icons.family_restroom,
        isSelected: isOn,
        isToggle: true,
        disabled: family.balance <= 0,
        onTap: onToggle,
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
        final available = remainingLimit < family.balance
            ? remainingLimit
            : family.balance;

        onAvailableChanged(available);

        final overLimit = limit != null && remainingLimit <= 0;
        final String subtitle = overLimit
            ? 'Spending limit reached'
            : available > 0
            ? 'Available: ${available.toStringAsFixed(2)} SAR'
            : 'No balance';

        return _PaymentTile(
          label: 'Family Wallet',
          subtitle: subtitle,
          icon: Icons.family_restroom,
          isSelected: isOn,
          isToggle: true,
          disabled: available <= 0,
          onTap: onToggle,
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
    required this.walletCredit,
    required this.familyCredit,
    required this.cardCharge,
    this.appliedCoupon,
  });

  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double total;
  final double walletCredit;
  final double familyCredit;
  final double cardCharge;
  final Coupon? appliedCoupon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _SummaryRow(label: 'Subtotal', value: subtotal),
        const SizedBox(height: 8),
        _SummaryRow(label: 'Tax (15%)', value: tax),
        const SizedBox(height: 8),
        _SummaryRow(label: 'Delivery Fee', value: deliveryFee),
        if (appliedCoupon != null) ...[
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Discount (${appliedCoupon!.label})',
            value: -discount,
            valueColor: Colors.green,
          ),
        ],
        if (walletCredit > 0) ...[
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Wallet credit',
            value: -walletCredit,
            valueColor: Colors.green,
          ),
        ],
        if (familyCredit > 0) ...[
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Family Wallet credit',
            value: -familyCredit,
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
              '${cardCharge.toStringAsFixed(2)} SAR',
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
