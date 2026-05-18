import 'package:flutter/material.dart';
import 'package:yjeek/cart/cart_scope.dart';
import 'package:yjeek/models/cart_item.dart';

class GlobalCartPage extends StatelessWidget {
  const GlobalCartPage({
    super.key,
    required this.restaurantNamesById,
  });

  final Map<String, String> restaurantNamesById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = CartScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Cart'),
        actions: [
          TextButton(
            onPressed: cart.hasAnyItems() ? cart.clearAll : null,
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: cart,
        builder: (context, child) {
          final grouped = cart.groupedItems();
          if (grouped.isEmpty) {
            return const Center(
              child: Text('Your global cart is empty'),
            );
          }

          final entries = grouped.entries.toList();

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final restaurantId = entry.key;
                    final items = entry.value;
                    final restaurantName =
                        restaurantNamesById[restaurantId] ??
                        'Restaurant $restaurantId';

                    return _RestaurantSection(
                      restaurantName: restaurantName,
                      subtotal: cart.subtotalForRestaurant(restaurantId),
                      onClear: () => cart.clearRestaurantCart(restaurantId),
                      onCheckout: () {},
                      children: items
                          .map(
                            (item) => _CartLineTile(
                              item: item,
                              onDecrease: () => cart.decreaseItem(
                                restaurantId: restaurantId,
                                menuItemId: item.cartKey,
                              ),
                              onIncrease: () => cart.addItem(
                                restaurantId: restaurantId,
                                item: item.menuItem,
                                selectedOptions: item.selectedOptions,
                                customUnitPrice: item.customUnitPrice,
                              ),
                              onRemove: () => cart.removeLine(
                                restaurantId: restaurantId,
                                menuItemId: item.cartKey,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Text(
                        'Grand Total: ${cart.grandTotal().toStringAsFixed(0)} SAR',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 120,
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Checkout All'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RestaurantSection extends StatelessWidget {
  const _RestaurantSection({
    required this.restaurantName,
    required this.subtotal,
    required this.onClear,
    required this.onCheckout,
    required this.children,
  });

  final String restaurantName;
  final double subtotal;
  final VoidCallback onClear;
  final VoidCallback onCheckout;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    restaurantName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...children,
            const Divider(),
            Row(
              children: [
                const Text('Section subtotal'),
                const Spacer(),
                Text(
                  '${subtotal.toStringAsFixed(0)} SAR',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCheckout,
                child: const Text('Checkout This Cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.menuItem.name, style: titleStyle),
                if (item.customizationSummary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.customizationSummary,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${item.unitPrice.toStringAsFixed(0)} SAR x ${item.quantity}',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('${item.quantity}'),
          IconButton(
            onPressed: onIncrease,
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
