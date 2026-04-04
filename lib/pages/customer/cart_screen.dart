// lib/pages/customer/cart_screen.dart

import 'package:flutter/material.dart';

import '../../mock/mock_cart_repository.dart';
import '../../models/cart_models.dart';

enum _DeliveryTimeOption { asap, schedule }

const String _kPaymentCreditCard = 'pay_credit';
const String _kPaymentWallet = 'pay_wallet';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------
  final MockCartRepository _repo = MockCartRepository();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  bool _isLoading = true;
  List<CartItem> _cartItems = [];
  CheckoutData? _checkoutData;
  List<Address> _addresses = [];
  Coupon? _appliedCoupon;
  bool _isValidatingCoupon = false;
  bool _isShowingCheckout = false;
  String? _selectedAddressId;
  _DeliveryTimeOption _deliveryTimeOption = _DeliveryTimeOption.asap;
  DateTime? _scheduledDateTime;
  String _selectedPaymentId = _kPaymentCreditCard;
  bool _isPlacingOrder = false;
  final TextEditingController _promoController = TextEditingController();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  Future<void> _loadData() async {
    final results = await Future.wait([
      _repo.getCartItems(),
      _repo.getCheckoutData(),
      _repo.getAddresses(),
    ]);

    if (!mounted) return;

    setState(() {
      _cartItems = results[0] as List<CartItem>;
      _checkoutData = results[1] as CheckoutData;
      _addresses = results[2] as List<Address>;
      if (_addresses.isNotEmpty) {
        _selectedAddressId = _addresses.first.id;
      }
      _isLoading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Cart Mutations
  // ---------------------------------------------------------------------------

  void _incrementQuantity(int index) {
    setState(() => _cartItems[index].quantity++);
  }

  void _decrementQuantity(int index) {
    setState(() {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _cartItems.removeAt(index));
  }

  // ---------------------------------------------------------------------------
  // Calculations
  // ---------------------------------------------------------------------------

  double get _subtotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get _tax => _subtotal * (_checkoutData?.taxRate ?? 0.15);

  double get _discount => _appliedCoupon != null
      ? _subtotal * _appliedCoupon!.discountFraction
      : 0.0;

  double get _total =>
      _subtotal + (_checkoutData?.deliveryFee ?? 0.0) + _tax - _discount;

  // ---------------------------------------------------------------------------
  // Promo Code
  // ---------------------------------------------------------------------------

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isValidatingCoupon = true);

    final coupon = await _repo.validateCoupon(code);

    if (!mounted) return;

    setState(() {
      _isValidatingCoupon = false;
      _appliedCoupon = coupon;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          coupon == null
              ? 'Invalid or expired promo code.'
              : '${coupon.label} applied successfully!',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _promoController.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _proceedToCheckout() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isShowingCheckout = true);
  }

  Future<void> _onDeliveryTimeTapped(_DeliveryTimeOption option) async {
    if (option == _DeliveryTimeOption.asap) {
      setState(() {
        _deliveryTimeOption = _DeliveryTimeOption.asap;
        _scheduledDateTime = null;
      });
      return;
    }

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

    setState(() {
      _deliveryTimeOption = _DeliveryTimeOption.schedule;
      _scheduledDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _placeOrder() async {
    setState(() => _isPlacingOrder = true);
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _isPlacingOrder = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Order Placed!'),
        content: Text(
          'Your order of \$${_total.toStringAsFixed(2)} has been placed.\n\n'
          '${_deliveryTimeOption == _DeliveryTimeOption.asap ? 'Estimated arrival: 25-35 min' : 'Scheduled for: ${_formatScheduled()}'}',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
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
    // Use surfaceContainerLow so white/surface cards sit visibly on top of it.
    // Avoid surfaceContainerLowest — it is identical to surface on many devices.
    final bg = Theme.of(context).colorScheme.surfaceContainerLow;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: _isShowingCheckout
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => setState(() => _isShowingCheckout = false),
              )
            : null,
        title: Text(
          _isShowingCheckout ? 'Checkout' : 'Cart',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_isShowingCheckout ? _buildCheckoutBody() : _buildCartBody()),
      bottomNavigationBar: _isLoading
          ? null
          : (_isShowingCheckout ? _buildPlaceOrderBar() : _buildCheckoutBar()),
    );
  }

  Widget _buildCartBody() {
    if (_cartItems.isEmpty && _checkoutData != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // ── Cart Items ──────────────────────────────────────────────────────
        ...List.generate(_cartItems.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CartItemCard(
              item: _cartItems[index],
              onIncrement: () => _incrementQuantity(index),
              onDecrement: () => _decrementQuantity(index),
              onDelete: () => _removeItem(index),
            ),
          );
        }),

        // ── Promo Code ──────────────────────────────────────────────────────
        _PromoCodeCard(
          controller: _promoController,
          appliedCoupon: _appliedCoupon,
          isValidating: _isValidatingCoupon,
          onApply: _applyPromoCode,
          onRemove: _removeCoupon,
        ),

        const SizedBox(height: 12),

        // ── Bill Summary ────────────────────────────────────────────────────
        _BillSummaryCard(
          subtotal: _subtotal,
          deliveryFee: _checkoutData?.deliveryFee ?? 0.0,
          tax: _tax,
          discount: _discount,
          total: _total,
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCheckoutBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _SectionCard(
          title: 'Delivery Address',
          icon: Icons.location_on_outlined,
          child: Column(
            children: _addresses.map((address) {
              final isSelected = address.id == _selectedAddressId;
              return _AddressTile(
                address: address,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedAddressId = address.id),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
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
        _SectionCard(
          title: 'Payment Method',
          icon: Icons.credit_card_outlined,
          child: Column(
            children: [
              _PaymentTile(
                id: _kPaymentCreditCard,
                label: 'Credit Card',
                subtitle: '**** 4242',
                icon: Icons.credit_card_rounded,
                isSelected: _selectedPaymentId == _kPaymentCreditCard,
                onTap: () =>
                    setState(() => _selectedPaymentId = _kPaymentCreditCard),
              ),
              const SizedBox(height: 8),
              _PaymentTile(
                id: _kPaymentWallet,
                label: 'Family Wallet',
                subtitle:
                    'Balance: \$${_checkoutData!.walletBalance.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_outlined,
                isSelected: _selectedPaymentId == _kPaymentWallet,
                onTap: () =>
                    setState(() => _selectedPaymentId = _kPaymentWallet),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Order Summary',
          icon: Icons.receipt_long_outlined,
          child: _CheckoutSummary(
            subtotal: _subtotal,
            deliveryFee: _checkoutData!.deliveryFee,
            tax: _tax,
            discount: _discount,
            total: _total,
            appliedCoupon: _appliedCoupon,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCheckoutBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _cartItems.isEmpty ? null : _proceedToCheckout,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Proceed to Checkout  •  \$${_total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
                  'Place Order  •  \$${_total.toStringAsFixed(2)}',
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
// Cart Item Card
// =============================================================================

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      // Use elevation + shadow instead of a border for visibility.
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Thumbnail ───────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(
                image: AssetImage(item.imagePath),
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.fastfood_rounded,
                    color: colorScheme.primary,
                    size: 32,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Name / Description / Price ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Delete icon aligned to the right of the name row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onDelete,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: colorScheme.error,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),

                  const SizedBox(height: 10),

                  // Price on the left, stepper on the right
                  Row(
                    children: [
                      Text(
                        '\$${item.lineTotal.toStringAsFixed(2)}',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const Spacer(),
                      // ── Quantity Stepper ──────────────────────────────────
                      _QuantityStepper(
                        quantity: item.quantity,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Quantity Stepper
// =============================================================================

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Minus ────────────────────────────────────────────────────────────
        _StepperButton(
          icon: Icons.remove,
          onTap: onDecrement,
          filled: false,
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$quantity',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
          ),
        ),

        // ── Plus ─────────────────────────────────────────────────────────────
        _StepperButton(
          icon: Icons.add,
          onTap: onIncrement,
          filled: true,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? colorScheme.primary : Colors.transparent,
          border: filled
              ? null
              : Border.all(
                  color: colorScheme.outline,
                  width: 1.4,
                ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
    );
  }
}

// =============================================================================
// Promo Code Card
// =============================================================================

class _PromoCodeCard extends StatelessWidget {
  const _PromoCodeCard({
    required this.controller,
    required this.appliedCoupon,
    required this.isValidating,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final Coupon? appliedCoupon;
  final bool isValidating;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Promo Code',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Applied Chip OR Input Row ─────────────────────────────────────
            if (appliedCoupon != null)
              Chip(
                avatar: Icon(
                  Icons.check_circle_outline,
                  color: colorScheme.onPrimaryContainer,
                  size: 18,
                ),
                label: Text(
                  '${appliedCoupon!.code}  ·  ${appliedCoupon!.label}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: colorScheme.primaryContainer,
                deleteIcon: Icon(
                  Icons.close,
                  size: 16,
                  color: colorScheme.onPrimaryContainer,
                ),
                onDeleted: onRemove,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textCapitalization: TextCapitalization.characters,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Enter code',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        // Explicit borders so the field is always visible
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.8,
                          ),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLowest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IntrinsicWidth(
                    child: FilledButton(
                      onPressed: isValidating ? null : onApply,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isValidating
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Bill Summary Card
// =============================================================================

class _BillSummaryCard extends StatelessWidget {
  const _BillSummaryCard({
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.discount,
    required this.total,
  });

  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),

            const SizedBox(height: 16),

            _BillRow(label: 'Subtotal', value: subtotal),
            const SizedBox(height: 10),
            _BillRow(label: 'Delivery Fee', value: deliveryFee),
            const SizedBox(height: 10),
            _BillRow(label: 'Tax (15%)', value: tax),

            if (discount > 0) ...[
              const SizedBox(height: 10),
              _BillRow(
                label: 'Discount',
                value: -discount,
                valueColor: Colors.green.shade600,
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                color: colorScheme.outlineVariant,
              ),
            ),

            // Total
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
                  '\$${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
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
    final isNegative = value < 0;
    final display = isNegative
        ? '-\$${(-value).toStringAsFixed(2)}'
        : '\$${value.toStringAsFixed(2)}';

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

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  final Address address;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.fullAddress,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: address.id,
              groupValue: _dummyRadioGroupValue(isSelected, address.id),
              onChanged: (_) => onTap(),
              activeColor: colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  String? _dummyRadioGroupValue(bool isSelected, String id) {
    return isSelected ? id : null;
  }
}

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
    return Row(
      children: [
        Expanded(
          child: _DeliveryOptionTile(
            label: 'ASAP',
            subtitle: '25-35 min',
            isSelected: selected == _DeliveryTimeOption.asap,
            onTap: () => onTap(_DeliveryTimeOption.asap),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DeliveryOptionTile(
            label: 'Schedule',
            subtitle: selected == _DeliveryTimeOption.schedule &&
                    scheduledDateTime != null
                ? _formatDate(scheduledDateTime!)
                : 'Choose time',
            isSelected: selected == _DeliveryTimeOption.schedule,
            onTap: () => onTap(_DeliveryTimeOption.schedule),
          ),
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
            color:
                isSelected ? colorScheme.primary : colorScheme.outlineVariant,
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
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
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

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? colorScheme.primary : colorScheme.outlineVariant,
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
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: isSelected ? id : null,
              onChanged: (_) => onTap(),
              activeColor: colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

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
              '\$${total.toStringAsFixed(2)}',
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
        ? '-\$${(-value).toStringAsFixed(2)}'
        : '\$${value.toStringAsFixed(2)}';

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
