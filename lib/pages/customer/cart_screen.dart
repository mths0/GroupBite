// lib/pages/customer/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/pages/customer/checkout_screen.dart';

import '../../cart/cart_controller.dart';
import '../../cart/cart_scope.dart';
import '../../mock/mock_cart_repository.dart';
import '../../models/cart_item.dart' as app_models;
import '../../models/cart_models.dart' as cart_models;
import '../../utils/tax.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.restaurantId,
    required this.customerId,
  });

  final String restaurantId;
  final String customerId;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------
  final MockCartRepository _repo = MockCartRepository();
  late CartController _cart;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  bool _isLoading = true;
  cart_models.CheckoutData? _checkoutData;
  cart_models.Coupon? _appliedCoupon;
  bool _isValidatingCoupon = false;
  double _deliveryFee = 0.0;

  final TextEditingController _promoController = TextEditingController();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cart = CartScope.of(context);
  }

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
  //No need for this no more
  Future<void> _loadData() async {
    final checkoutData = await _repo.getCheckoutData();
    final restaurant =
    await DatabaseService().getRestaurantById(widget.restaurantId);

    if (!mounted) return;

    setState(() {
      _checkoutData = checkoutData;
      _deliveryFee = restaurant?.deliveryFee ?? 0.0;
      _isLoading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Cart Mutations
  // ---------------------------------------------------------------------------

  void _incrementQuantity(app_models.CartItem item) {
    _cart.addItem(
      restaurantId: widget.restaurantId,
      item: item.menuItem,
      selectedOptions: item.selectedOptions,
      customUnitPrice: item.customUnitPrice,
    );
  }

  void _decrementQuantity(app_models.CartItem item) {
    _cart.decreaseItem(
      restaurantId: widget.restaurantId,
      menuItemId: item.cartKey,
    );
  }

  void _removeItem(app_models.CartItem item) {
    _cart.removeItem(
      restaurantId: widget.restaurantId,
      menuItemId: item.cartKey,
    );
  }

  // ---------------------------------------------------------------------------
  // Calculations
  // ---------------------------------------------------------------------------

  double get _subtotalInclTax => _cart.subtotal(widget.restaurantId);

  double get _tax => _subtotalInclTax * (_checkoutData?.taxRate ?? kTaxRate);

  double get _subtotalExclTax => _subtotalInclTax - _tax;

  double get _discount {
    final coupon = _appliedCoupon;
    if (coupon == null) return 0.0;
    final base = _subtotalInclTax + _deliveryFee;

    switch (coupon.discountType) {
      case cart_models.CouponDiscountType.freeDelivery:
        return _deliveryFee;
      case cart_models.CouponDiscountType.percentage:
        return base * (coupon.discountValue / 100);
      case cart_models.CouponDiscountType.fixed:
        return coupon.discountValue > base ? base : coupon.discountValue;
    }
  }

  double get _total {
    final result = _subtotalInclTax + _deliveryFee - _discount;
    return result < 0 ? 0 : result;
  }

  // ---------------------------------------------------------------------------
  // Promo Code
  // ---------------------------------------------------------------------------

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isValidatingCoupon = true);

    final coupon = await DatabaseService().validateCoupon(
      restaurantId: widget.restaurantId,
      code: code,
    );

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

  Future<void> _proceedToCheckout() async {
    final cartItems = _cart.itemsForRestaurant(widget.restaurantId);

    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final restaurant = await DatabaseService().getRestaurantById(
      widget.restaurantId,
    );
    if (!mounted) return;
    if (restaurant == null || !restaurant.isOpen) {
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

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScope(
          notifier: _cart,
          child: CheckoutScreen(
            cartItems: cartItems
                .map(
                  (item) => cart_models.CartItem(
                    id: item.menuItem.id,
                    name: item.menuItem.name,
                    description: item.menuItem.description,
                    imagePath: item.menuItem.imageUrl,
                    unitPrice: item.customUnitPrice,
                    selectedOptions: item.selectedOptions,
                    quantity: item.quantity,
                  ),
                )
                .toList(),
            checkoutData: _checkoutData!,
            subtotal: _subtotalExclTax,
            deliveryFee: _deliveryFee,
            tax: _tax,
            discount: _discount,
            total: _total,
            appliedCoupon: _appliedCoupon,
            customerId: widget.customerId,
            restaurantId: widget.restaurantId,
            onOrderPlaced: () {
              _cart.clearRestaurantCart(widget.restaurantId);
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerLow;

    return AnimatedBuilder(
      animation: _cart,
      builder: (context, _) {
        final cartItems = _cart.itemsForRestaurant(widget.restaurantId);

        final scheme = Theme
            .of(context)
            .colorScheme;
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: const Text(
              'Cart',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            elevation: 0,
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
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildCartBody(cartItems),
          bottomNavigationBar: _isLoading ? null : _buildCheckoutBar(cartItems),
        );
      },
    );
  }

  Widget _buildCartBody(List<app_models.CartItem> cartItems) {
    if (cartItems.isEmpty && _checkoutData != null) {
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
        _CartItemsListCard(
          items: cartItems,
          onIncrement: _incrementQuantity,
          onDecrement: _decrementQuantity,
          onDelete: _removeItem,
        ),
        const SizedBox(height: 12),
        _PromoCodeCard(
          controller: _promoController,
          appliedCoupon: _appliedCoupon,
          discount: _discount,
          isValidating: _isValidatingCoupon,
          onApply: _applyPromoCode,
          onRemove: _removeCoupon,
        ),
        const SizedBox(height: 12),
        _BillSummaryCard(
          subtotal: _subtotalExclTax,
          deliveryFee: _deliveryFee,
          tax: _tax,
          discount: _discount,
          total: _total,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCheckoutBar(List<app_models.CartItem> cartItems) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: FilledButton(
              onPressed: cartItems.isEmpty ? null : _proceedToCheckout,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                cartItems.isNotEmpty
                    ? 'Proceed to Checkout  •  ${_total.toStringAsFixed(2)} SAR'
                    : "Try to put some items",
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

  // The checkout flow now uses CheckoutScreen directly.
  // _buildPlaceOrderBar has been removed as it is now part of CheckoutScreen.
}

// =============================================================================
// Cart Items List (single connected card with dividers between items)
// =============================================================================

class _CartItemsListCard extends StatelessWidget {
  const _CartItemsListCard({
    required this.items,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  final List<app_models.CartItem> items;
  final void Function(app_models.CartItem) onIncrement;
  final void Function(app_models.CartItem) onDecrement;
  final void Function(app_models.CartItem) onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _CartItemRow(
                item: items[i],
                onIncrement: () => onIncrement(items[i]),
                onDecrement: () => onDecrement(items[i]),
                onDelete: () => onDelete(items[i]),
              ),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  final app_models.CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              item.menuItem.imageUrl,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fastfood_rounded,
                      color: scheme.primary,
                      size: 32,
                    ),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.menuItem.name,
                        style: theme.textTheme.titleSmall?.copyWith(
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
                          color: scheme.error,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.menuItem.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (item.selectedOptions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final option in item.selectedOptions)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• ${option.groupTitle}: ${option.choiceName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${item.lineTotal.toStringAsFixed(2)} SAR',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
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
    );
  }
}

// =============================================================================
// Quantity Stepper — connected pill with [-] [n] [+]
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
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: onDecrement,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          icon,
          size: 18,
          color: scheme.onSurface,
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
    required this.discount,
    required this.isValidating,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final cart_models.Coupon? appliedCoupon;
  final double discount;
  final bool isValidating;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: colorScheme.onPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${appliedCoupon!.code}  ·  ${appliedCoupon!.label}',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (discount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '−${discount.toStringAsFixed(2)} SAR',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onRemove,
                      child: Icon(
                        Icons.close,
                        color: colorScheme.onPrimary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.characters,
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Enter promo code',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    Material(
                      color: colorScheme.primary,
                      child: InkWell(
                        onTap: isValidating ? null : onApply,
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          child: isValidating
                              ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                              : Text(
                            'Apply',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Order Summary',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 14),
            _BillRow(label: 'Subtotal', value: subtotal),
            const SizedBox(height: 12),
            _BillRow(label: 'Tax (15%)', value: tax),
            const SizedBox(height: 12),
            _BillRow(label: 'Delivery Fee', value: deliveryFee),
            if (discount > 0) ...[
              const SizedBox(height: 12),
              _BillRow(
                label: 'Discount',
                value: -discount,
                valueColor: Colors.green.shade600,
              ),
            ],
            const SizedBox(height: 14),
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(2)} SAR',
                  style: Theme
                      .of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
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

class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  final cart_models.Address address;
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
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
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
