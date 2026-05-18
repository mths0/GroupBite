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
    this.groupContributionNote,
    this.groupOthersPaid,
    this.groupOwnSubtotal,
    this.groupOwnTax,
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

  /// Group-order context: a one-line note explaining how the total was derived
  /// (e.g. "You declared a fixed contribution of 5.00 SAR").
  final String? groupContributionNote;

  /// Group-order context (host view): per-member amounts already paid by
  /// others, shown as a section in the summary.
  final List<MapEntry<String, double>>? groupOthersPaid;

  /// Group-order context: the value of this user's own items if it differs
  /// from [subtotal] (used for host checkouts where [subtotal] gets repurposed).
  final double? groupOwnSubtotal;
  final double? groupOwnTax;

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
        final placed = await _db.payGroupMemberAndMaybePlaceOrder(
          groupOrderId: widget.groupOrderId!,
          customerId: widget.customerId,
          restaurantId: widget.restaurantId,
          paidAmount: widget.total,
        );
        groupAmountToRefundOnFailure = 0;

        if (!mounted) return;

        setState(() => _isPlacingOrder = false);

        if (placed == null) {
          // Member-only payment: no final order yet — return to home.
          await _showOrderPlacedSheet(
            title: 'Payment Done',
            message:
                'Your part of ${widget.total.toStringAsFixed(2)} SAR has been paid successfully.\n\n'
                'You will now return to the home page.',
            buttonLabel: 'Done',
          );
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }

        // Final group order was placed — mirror the normal-checkout success
        // flow (bottom sheet "Order Placed!" then push to OrderDetailScreen).
        final user = await _db.getUserById(widget.customerId);
        final customer = user is Customer ? user : null;

        if (!mounted) return;

        widget.onOrderPlaced?.call();

        await _showOrderPlacedSheet(
          title: 'Group Order Placed!',
          message: 'Everyone has paid. The group order is on its way.',
        );

        if (!mounted) return;

        if (customer != null) {
          Navigator.popUntil(context, (route) => route.isFirst);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                order: placed,
                customer: customer,
              ),
            ),
          );
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }

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

      await _showOrderPlacedSheet(
        title: 'Order Placed!',
        message: _deliveryTimeOption == _DeliveryTimeOption.asap
            ? 'Your order of ${widget.total.toStringAsFixed(2)} SAR has been placed.'
            : 'Your order of ${widget.total.toStringAsFixed(2)} SAR has been placed.\nScheduled for ${_formatScheduled()}.',
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

  Future<void> _showOrderPlacedSheet({
    required String title,
    required String message,
    String buttonLabel = 'View order',
    VoidCallback? onPressed,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final scheme = theme.colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD7F0DC),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF1A5E2A),
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      onPressed?.call();
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
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
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant,
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildPlaceOrderBar(),
    );
  }

  Widget _buildBody() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
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
          const SizedBox(height: 28),
        ],

        _BorderlessSectionHeader(
          title: 'Payment Method',
          icon: Icons.credit_card_outlined,
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<SavedCard>>(
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

                    final rows = <Widget>[];
                    if (card == null) {
                      rows.add(
                        _PaymentRow(
                          icon: Icons.add_card,
                          label: 'Add Card',
                          subtitle: 'No card on file — tap to add one',
                          isSelected: false,
                          onTap: _openAddCardSheet,
                        ),
                      );
                    } else {
                      rows.add(
                        _PaymentRow(
                          icon: Icons.credit_card_rounded,
                          label: '•••• ${card.last4}',
                          subtitle: card.holderName,
                          isSelected: true,
                          onTap: null,
                        ),
                      );
                    }
                    rows.add(
                      _PaymentRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Personal Wallet',
                        subtitle: balance > 0
                            ? 'Balance: ${balance.toStringAsFixed(2)} SAR'
                            : 'No balance',
                        isSelected: _useWallet,
                        isToggle: true,
                        disabled: balance <= 0,
                        onTap: () =>
                            setState(() => _useWallet = !_useWallet),
                      ),
                    );
                    if (family != null) {
                      rows.add(
                        _FamilyWalletRow(
                          family: family,
                          currentUserId: widget.customerId,
                          isOn: _useFamilyWallet,
                          onToggle: () => setState(
                            () => _useFamilyWallet = !_useFamilyWallet,
                          ),
                          onAvailableChanged: (v) =>
                              _syncAfterBuild(familyAvailable: v),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          rows[i],
                          if (i < rows.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        ),

        const SizedBox(height: 28),

        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                    _isGroupCheckout && !widget.isGroupHost
                        ? 'Your Part Summary'
                        : 'Order Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant,
              ),
              _CheckoutSummary(
                cartItems: widget.cartItems,
                subtotal: widget.subtotal,
                deliveryFee: widget.deliveryFee,
                tax: widget.tax,
                discount: widget.discount,
                total: widget.total,
                appliedCoupon: widget.appliedCoupon,
                walletCredit: _split.wallet,
                familyCredit: _split.family,
                cardCharge: _split.card,
                contributionNote: widget.groupContributionNote,
                othersPaid: widget.groupOthersPaid,
                ownSubtotal: widget.groupOwnSubtotal,
                ownTax: widget.groupOwnTax,
              ),
            ],
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
        ? (widget.total <= 0.005
            ? 'Place Order'
            : 'Pay Last & Place Order  •  $amount SAR')
        : 'Pay My Part  •  $amount SAR';

    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
        ),
      ],
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

/// Pill-style segmented selector for Immediate vs. Schedule delivery time.
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
    final scheme = Theme.of(context).colorScheme;
    final isImmediate = selected == _DeliveryTimeOption.asap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _DeliveryOptionTile(
                  label: 'Immediate',
                  isSelected: isImmediate,
                  onTap: () => onTap(_DeliveryTimeOption.asap),
                ),
              ),
              Expanded(
                child: _DeliveryOptionTile(
                  label: 'Scheduled',
                  isSelected: !isImmediate,
                  onTap: () => onTap(_DeliveryTimeOption.schedule),
                ),
              ),
            ],
          ),
        ),
        if (!isImmediate && scheduledDateTime != null)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  color: scheme.onSurfaceVariant,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(scheduledDateTime!),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $h:$m';
  }
}

/// A single segment inside the delivery time pill.
class _DeliveryOptionTile extends StatelessWidget {
  const _DeliveryOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.surfaceContainerLowest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// A clean, borderless section header (icon + title) used for sections that
/// shouldn't be wrapped in a card (Payment Method, Order Summary).
class _BorderlessSectionHeader extends StatelessWidget {
  const _BorderlessSectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Borderless payment-method row with icon, label, subtitle, and a radio/check
/// on the right. Sits in a list separated by 1px dividers — no per-tile box.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.disabled = false,
    this.isToggle = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final bool disabled;
  final bool isToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trailing = isToggle
        ? Icon(
            isSelected
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            color: isSelected ? scheme.primary : scheme.outline,
          )
        : Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: isSelected ? scheme.primary : scheme.outline,
          );

    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.primaryContainer.withValues(alpha: 0.15)
            : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: disabled
                        ? scheme.error
                        : scheme.onSurfaceVariant,
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
      return Opacity(opacity: 0.5, child: AbsorbPointer(child: row));
    }
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: row,
    );
  }
}

// ---------------------------------------------------------------------------

/// Family-wallet apply-toggle. Computes the effective spendable amount
/// (`min(remainingLimit, balance)` for members; `balance` for the owner)
/// and reports it via [onAvailableChanged] so the checkout state can compute
/// the payment split. Tapping toggles whether the credit is applied.
class _FamilyWalletRow extends StatelessWidget {
  const _FamilyWalletRow({
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
      return _PaymentRow(
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

        return _PaymentRow(
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
    required this.cartItems,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.discount,
    required this.total,
    required this.walletCredit,
    required this.familyCredit,
    required this.cardCharge,
    this.appliedCoupon,
    this.contributionNote,
    this.othersPaid,
    this.ownSubtotal,
    this.ownTax,
  });

  final List<CartItem> cartItems;
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double total;
  final double walletCredit;
  final double familyCredit;
  final double cardCharge;
  final Coupon? appliedCoupon;
  final String? contributionNote;
  final List<MapEntry<String, double>>? othersPaid;
  final double? ownSubtotal;
  final double? ownTax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displaySubtotal = ownSubtotal ?? subtotal;
    final displayTax = ownTax ?? tax;
    final lineItemsTotal = displaySubtotal + displayTax + deliveryFee - discount;
    final adjustment = total - lineItemsTotal;
    final showAdjustment = adjustment.abs() > 0.005;
    final paidByOthersTotal = othersPaid == null
        ? 0.0
        : othersPaid!.fold<double>(0, (s, e) => s + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cartItems.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final item in cartItems) _CheckoutItemRow(item: item),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        ],
        const SizedBox(height: 14),
        _SummaryRow(label: 'Subtotal', value: displaySubtotal),
        const SizedBox(height: 10),
        _SummaryRow(label: 'Taxes (15%)', value: displayTax),
        const SizedBox(height: 10),
        _SummaryRow(label: 'Delivery Fee', value: deliveryFee),
        if (othersPaid != null && othersPaid!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'Paid by other members',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          ...othersPaid!.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '-${entry.value.toStringAsFixed(2)} SAR',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          _SummaryRow(
            label: 'Total paid by others',
            value: -paidByOthersTotal,
            valueColor: Colors.green,
          ),
        ],
        if (showAdjustment && othersPaid == null) ...[
          const SizedBox(height: 10),
          _SummaryRow(
            label: adjustment < 0
                ? 'Host covers the rest'
                : 'Additional contribution',
            value: adjustment,
            valueColor: adjustment < 0 ? Colors.green : null,
          ),
        ],
        if (appliedCoupon != null) ...[
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Discount (${appliedCoupon!.label})',
            value: -discount,
            valueColor: Colors.green,
          ),
        ],
        if (walletCredit > 0) ...[
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Personal Wallet applied',
            value: -walletCredit,
            valueColor: Colors.green.shade700,
          ),
        ],
        if (familyCredit > 0) ...[
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Family Wallet applied',
            value: -familyCredit,
            valueColor: Colors.green.shade700,
          ),
        ],
        const SizedBox(height: 14),
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${total.toStringAsFixed(2)} SAR',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${item.lineTotal.toStringAsFixed(2)} SAR',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (opt.extraPrice > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '+${(opt.extraPrice * item.quantity).toStringAsFixed(2)} SAR',
                        style: theme.textTheme.bodySmall?.copyWith(
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
    final scheme = Theme.of(context).colorScheme;
    final display = value < 0
        ? '-${(-value).toStringAsFixed(2)} SAR'
        : '${value.toStringAsFixed(2)} SAR';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          display,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor ?? scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
