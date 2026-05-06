// lib/pages/customer/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';

import '../../mock/mock_cart_repository.dart';
import '../../models/cart_item.dart' as app_models;
import '../../models/cart_models.dart' as cart_models;
import 'package:food_delivery_platform/models/cart_models.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/customer/checkout_screen.dart';
import '../../cart/cart_controller.dart';
import 'package:food_delivery_platform/models/cart_models.dart';
import '../../cart/cart_scope.dart';

enum _DeliveryTimeOption { asap, schedule }

const String _kPaymentCreditCard = 'pay_credit';
const String _kPaymentWallet = 'pay_wallet';

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
  List<cart_models.Address> _addresses = [];
  cart_models.Coupon? _appliedCoupon;
  bool _isValidatingCoupon = false;
  double _deliveryFee = 0.0;

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
    final results = await Future.wait([
      _repo.getCheckoutData(),
      _repo.getAddresses(),
      DatabaseService().getRestaurantById(widget.restaurantId),
    ]);

    if (!mounted) return;

    final restaurant = results[2] as Restaurant?;

    setState(() {
      _checkoutData = results[0] as cart_models.CheckoutData;
      _addresses = results[1] as List<cart_models.Address>;
      _deliveryFee = restaurant?.deliveryFee ?? 0.0;
      if (_addresses.isNotEmpty) {
        _selectedAddressId = _addresses.first.id;
      }
      _isLoading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Cart Mutations
  // ---------------------------------------------------------------------------

  void _incrementQuantity(app_models.CartItem item) {
    _cart.addItem(restaurantId: widget.restaurantId, item: item.menuItem);
  }

  void _decrementQuantity(app_models.CartItem item) {
    _cart.decreaseItem(
      restaurantId: widget.restaurantId,
      menuItemId: item.menuItem.id,
    );
  }

  void _removeItem(app_models.CartItem item) {
    _cart.removeItem(
      restaurantId: widget.restaurantId,
      menuItemId: item.menuItem.id,
    );
  }

  // ---------------------------------------------------------------------------
  // Calculations
  // ---------------------------------------------------------------------------

  double get _subtotal => _cart.subtotal(widget.restaurantId);

  double get _tax => _subtotal * (_checkoutData?.taxRate ?? 0.15);

  double get _discount {
    if (_appliedCoupon == null) return 0.0;

    if (_appliedCoupon!.discountType ==
        cart_models.CouponDiscountType.percentage) {
      return _subtotal * (_appliedCoupon!.discountValue / 100);
    }

    return _appliedCoupon!.discountValue > _subtotal
        ? _subtotal
        : _appliedCoupon!.discountValue;
  }

  double get _total => _subtotal + _deliveryFee + _tax - _discount;

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

  void _proceedToCheckout() {
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartItems: cartItems
              .map(
                (item) => cart_models.CartItem(
                  id: item.menuItem.id,
                  name: item.menuItem.name,
                  description: item.menuItem.description,
                  imagePath: item.menuItem.imageUrl,
                  unitPrice: item.menuItem.price,
                  quantity: item.quantity,
                ),
              )
              .toList(),
          checkoutData: _checkoutData!,
          subtotal: _subtotal,
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

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: const Text(
              'Cart',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 0,
            scrolledUnderElevation: 1,
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
        ...cartItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CartItemCard(
              item: item,
              onIncrement: () => _incrementQuantity(item),
              onDecrement: () => _decrementQuantity(item),
              onDelete: () => _removeItem(item),
            ),
          );
        }),
        _PromoCodeCard(
          controller: _promoController,
          appliedCoupon: _appliedCoupon,
          isValidating: _isValidatingCoupon,
          onApply: _applyPromoCode,
          onRemove: _removeCoupon,
        ),
        const SizedBox(height: 12),
        _BillSummaryCard(
          subtotal: _subtotal,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
    );
  }

  // The checkout flow now uses CheckoutScreen directly.
  // _buildPlaceOrderBar has been removed as it is now part of CheckoutScreen.
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

  final app_models.CartItem item;
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
              child: Image.network(
                item.menuItem.imageUrl,
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
                          item.menuItem.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
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
                    item.menuItem.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Price on the left, stepper on the right
                  Row(
                    children: [
                      Text(
                        '${item.lineTotal.toStringAsFixed(2)} SAR',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
  final cart_models.Coupon? appliedCoupon;
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
                  '${total.toStringAsFixed(2)} SAR',
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
  final cart_models.Coupon? appliedCoupon;

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
