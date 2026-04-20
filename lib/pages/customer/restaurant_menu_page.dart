import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/mock/mock_menu_items_repository.dart';

import 'package:food_delivery_platform/models/menu_item.dart';
import 'package:food_delivery_platform/models/restaurant.dart' as app_models;
import 'package:food_delivery_platform/pages/customer/cart_screen.dart';

class RestaurantMenuPage extends StatefulWidget {
  const RestaurantMenuPage({
    super.key,
    required this.restaurant,
    this.repository,
  });

  final app_models.Restaurant restaurant;

  /// لو ما مررت repository بيستخدم البيانات الثابتة
  final MenuRepository? repository;

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<String> _tabs = const [
    'Appetizers',
    'Mains',
    'Desserts',
    'Drinks',
  ];

  late final MenuRepository _repo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _repo = widget.repository ?? StaticMenuRepository();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cart = CartScope.of(context);
    final restaurantId = widget.restaurant.id;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: FutureBuilder<List<MenuItem>>(
        future: _repo.getMenuForRestaurant(widget.restaurant.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];

          return Column(
            children: [
              HeaderCard(restaurant: widget.restaurant),
              const SizedBox(height: 8),

              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.outline,
                indicatorColor: scheme.primary,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),

              // Lists
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((cat) {
                    final filtered = items
                        .where((e) => e.category == cat)
                        .toList();
                    if (filtered.isEmpty) {
                      return const Center(child: Text('No items'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _MenuItemTile(
                          item: item,
                          onAdd: () {
                            cart.addItem(
                              restaurantId: restaurantId,
                              item: item,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${item.name} added to cart'),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: cart,
        builder: (_, _) {
          final count = cart.itemCount(restaurantId);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartScope(
                        notifier: cart,
                        child: CartScreen(restaurantId: restaurantId),
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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

//Todo use this in the restaurant list page
class HeaderCard extends StatelessWidget {
  const HeaderCard({super.key, required this.restaurant});

  final app_models.Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: scheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة كبيرة (لو عندك imageUrl في Restaurant لاحقاً استبدلها)
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  restaurant.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: scheme.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: restaurant.isOpen
                                ? Colors.green
                                : Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            restaurant.isOpen ? "Open" : "Closed",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(Icons.star, size: 18, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          restaurant.rating.toString(),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.access_time, size: 18),
                        const SizedBox(width: 6),
                        //Todo make delivery time dynamic (wait for backend)
                        Text(
                          "Delivery Time (Soon)",
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.attach_money, size: 18),
                        Text(
                          restaurant.deliveryFee == 0
                              ? "Free Delivery"
                              : "${restaurant.deliveryFee.toStringAsFixed(0)} SAR",
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: restaurant.tags
                          .map((tag) => _TagChip(text: tag))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: scheme.onSurface)),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    required this.item,
    required this.onAdd,
  });

  final MenuItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              item.imageUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 70,
                height: 70,
                color: scheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.price.toStringAsFixed(0)} SAR',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: scheme.onPrimary),
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}
