// lib/pages/customer/cart_screen.dart

import 'package:flutter/material.dart';

import '../../mock/mock_cart_repository.dart';
import '../../models/cart_models.dart';
import 'checkout_screen.dart';

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
  Coupon? _appliedCoupon;
  bool _isValidatingCoupon = false;
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
    ]);

    if (!mounted) return;

    setState(() {
      _cartItems = results[0] as List<CartItem>;
      _checkoutData = results[1] as CheckoutData;
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartItems: List.unmodifiable(_cartItems),
          checkoutData: _checkoutData!,
          appliedCoupon: _appliedCoupon,
          subtotal: _subtotal,
          tax: _tax,
          discount: _discount,
          total: _total,
        ),
      ),
    );
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
        title: const Text(
          'Cart',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: _isLoading ? null : _buildCheckoutBar(),
    );
  }

  Widget _buildBody() {
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