import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';

class CartPage extends StatelessWidget {
  const CartPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  final String restaurantId;
  final String restaurantName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = CartScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('$restaurantName Cart'),
        actions: [
          TextButton(
            onPressed: () => cart.clearRestaurantCart(restaurantId),
            child: const Text('Clear'),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: cart,
        builder: (_, _) {
          final items = cart.itemsForRestaurant(restaurantId);
          final subtotal = cart.subtotal(restaurantId);

          if (items.isEmpty) {
            return const Center(child: Text('Your cart is empty'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    final item = entry.menuItem;

                    return Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.price.toStringAsFixed(0)} SAR x ${entry.quantity}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => cart.decreaseItem(
                                restaurantId: restaurantId,
                                menuItemId: item.id,
                              ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${entry.quantity}'),
                            IconButton(
                              onPressed: () => cart.addItem(
                                restaurantId: restaurantId,
                                item: item,
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ),
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
                        'Subtotal: ${subtotal.toStringAsFixed(0)} SAR',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 120,
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Checkout'),
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
