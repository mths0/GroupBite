import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_controller.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/cart_item.dart' as cart_lines;
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/group_order.dart';
import 'package:food_delivery_platform/models/item_customization_result.dart';
import 'package:food_delivery_platform/models/menu_item.dart';
import 'package:food_delivery_platform/models/restaurant.dart' as app_models;
import 'package:food_delivery_platform/models/restaurant_tag.dart';
import 'package:food_delivery_platform/pages/customer/cart_screen.dart';
import 'package:food_delivery_platform/pages/customer/group_order_summary_screen.dart';
import 'package:food_delivery_platform/pages/customer/item_customization_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RestaurantMenuPage extends StatefulWidget {
  const RestaurantMenuPage({
    super.key,
    required this.restaurant,
    required this.customer,
    this.groupOrderId,
    this.showGroupQrOnOpen = false,
  });

  final app_models.Restaurant restaurant;
  final Customer customer;
  final String? groupOrderId;
  final bool showGroupQrOnOpen;

  bool get isInGroupOrder => groupOrderId != null;
  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage> {
  static const List<String> _defaultTabs = [
    'Mains',
    'Appetizers',
    'Desserts',
    'Drinks',
  ];

  late final Stream<firestore.DocumentSnapshot<Map<String, dynamic>>>
  _restaurantStream = firestore.FirebaseFirestore.instance
      .collection('users')
      .doc(widget.restaurant.id)
      .snapshots();

  List<String> _extractCategories(Map<String, dynamic>? data) {
    final raw = data?['categories'];
    if (raw is List) {
      final cats = raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (cats.isNotEmpty) return cats;
    }
    return List<String>.from(_defaultTabs);
  }

  void _navigateToGroupOrderSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupOrderSummaryScreen(
          groupOrderId: widget.groupOrderId!,
          customer: widget.customer,
          restaurant: widget.restaurant,
        ),
      ),
    );
  }

  Future<void> _startGroupOrder() async {
    final groupOrderId = await DatabaseService().createGroupOrder(
      hostCustomerId: widget.customer.id,
      restaurantId: widget.restaurant.id,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantMenuPage(
          restaurant: widget.restaurant,
          customer: widget.customer,
          groupOrderId: groupOrderId,
          showGroupQrOnOpen: true,
        ),
      ),
    );
  }

  Future<bool> _handleBackAction() async {
    if (widget.groupOrderId == null) {
      return true;
    }

    // Check if user is host
    final group = await DatabaseService().getGroupOrderById(
      widget.groupOrderId!,
    );
    if (group == null) return true;

    final isHost = group.hostCustomerId == widget.customer.id;

    if (!mounted) return false;

    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isHost ? 'End Group Order?' : 'Leave Group Order?'),
        content: Text(
          isHost
              ? 'As the host, leaving will cancel the group order for everyone. Are you sure?'
              : 'Leaving will remove you from the group and delete your items. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isHost ? 'End Order' : 'Leave Group'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await DatabaseService().leaveGroupOrder(
        groupOrderId: widget.groupOrderId!,
        customerId: widget.customer.id,
      );
      return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _menuFuture = DatabaseService().getMenuForRestaurant(
      restaurantId: widget.restaurant.id,
    );
  }

  late final Future<List<MenuItem>> _menuFuture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cart = widget.groupOrderId == null ? CartScope.read(context) : null;
    final restaurantId = widget.restaurant.id;

    final page = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackAction();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () async {
              final shouldPop = await _handleBackAction();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),

        body: FutureBuilder<List<MenuItem>>(
          future: _menuFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Failed to load menu items: ${snapshot.error}'),
              );
            }

            final items = snapshot.data ?? const <MenuItem>[];

            return StreamBuilder<
              firestore.DocumentSnapshot<Map<String, dynamic>>
            >(
              stream: _restaurantStream,
              builder: (context, restaurantSnap) {
                final tabs = _extractCategories(
                  restaurantSnap.data?.data(),
                );

                if (tabs.isEmpty) {
                  return Column(
                    children: [
                      HeaderCard(restaurant: widget.restaurant),
                      const Expanded(
                        child: Center(child: Text('No menu categories yet')),
                      ),
                    ],
                  );
                }

                return DefaultTabController(
                  key: ValueKey(tabs.join('|')),
                  length: tabs.length,
                  child: Column(
                    children: [
                      HeaderCard(restaurant: widget.restaurant),

                      const SizedBox(height: 8),

                      if (widget.groupOrderId == null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _startGroupOrder,
                            icon: const Icon(Icons.group_add),
                            label: const Text('Start Group Order'),
                          ),
                        )
                      else
                        _GroupOrderStatusBar(
                          groupOrderId: widget.groupOrderId!,
                          customerId: widget.customer.id,
                          autoShowQr: widget.showGroupQrOnOpen,
                          onSummaryTap: _navigateToGroupOrderSummary,
                        ),

                      const SizedBox(height: 8),

                      TabBar(
                        isScrollable: true,
                        labelColor: scheme.primary,
                        unselectedLabelColor: scheme.outline,
                        indicatorColor: scheme.primary,
                        tabs: tabs.map((t) => Tab(text: t)).toList(),
                      ),

                      Expanded(
                        child: TabBarView(
                          children: tabs.map((cat) {
                            final filtered = items
                                .where((e) => e.category == cat)
                                .toList();

                            if (filtered.isEmpty) {
                              return const Center(child: Text('No items'));
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filtered[index];

                                Future<void> handleTap() async {
                                  ItemCustomizationResult? customization;

                                  if (item.optionGroups.isNotEmpty) {
                                    customization =
                                        await showModalBottomSheet<
                                          ItemCustomizationResult
                                        >(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          showDragHandle: true,
                                          clipBehavior: Clip.antiAlias,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                          ),
                                          builder: (_) =>
                                              ItemCustomizationScreen(
                                                item: item,
                                              ),
                                        );

                                    if (customization == null) {
                                      return;
                                    }
                                  }

                                  if (widget.groupOrderId == null) {
                                    cart!.addItem(
                                      restaurantId: restaurantId,
                                      item: item,
                                      selectedOptions:
                                          customization?.selectedOptions ??
                                          const [],
                                      customUnitPrice:
                                          customization?.finalUnitPrice,
                                    );

                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${item.name} added to cart',
                                        ),
                                      ),
                                    );

                                    return;
                                  }

                                  final member = await DatabaseService()
                                      .getGroupMember(
                                        groupOrderId: widget.groupOrderId!,
                                        customerId: widget.customer.id,
                                      );

                                  if (member == null) {
                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'You are not a member of this group order.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (member.status ==
                                          GroupMemberStatus.ready ||
                                      member.status == GroupMemberStatus.paid) {
                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'You already marked yourself ready. You cannot add more items.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  await DatabaseService().addItemToGroupOrder(
                                    groupOrderId: widget.groupOrderId!,
                                    memberId: widget.customer.id,
                                    menuItem: item,
                                    selectedOptions:
                                        customization?.selectedOptions ??
                                        const [],
                                    customUnitPrice:
                                        customization?.finalUnitPrice,
                                  );

                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${item.name} added to group order',
                                      ),
                                    ),
                                  );
                                }

                                if (cart == null) {
                                  return _MenuItemTile(
                                    item: item,
                                    onAdd: handleTap,
                                  );
                                }

                                Future<void> handleIncrement() async {
                                  final lines = cart
                                      .itemsForRestaurant(restaurantId)
                                      .where((e) => e.menuItem.id == item.id)
                                      .toList();

                                  if (lines.isEmpty) return;

                                  cart_lines.CartItem? chosen;

                                  if (lines.length == 1) {
                                    chosen = lines.first;
                                  } else {
                                    chosen =
                                        await showModalBottomSheet<
                                          cart_lines.CartItem
                                        >(
                                          context: context,
                                          showDragHandle: true,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                          ),
                                          builder: (_) => _ConfigPickerSheet(
                                            item: item,
                                            lines: lines,
                                          ),
                                        );
                                  }

                                  if (chosen == null) return;

                                  cart.addItem(
                                    restaurantId: restaurantId,
                                    item: item,
                                    selectedOptions: chosen.selectedOptions,
                                    customUnitPrice: chosen.customUnitPrice,
                                  );
                                }

                                return AnimatedBuilder(
                                  animation: cart,
                                  builder: (_, _) => _MenuItemTile(
                                    item: item,
                                    count: cart.quantityForMenuItem(
                                      restaurantId: restaurantId,
                                      menuItemId: item.id,
                                    ),
                                    onAdd: handleTap,
                                    onIncrement: handleIncrement,
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: widget.groupOrderId == null
            ? AnimatedBuilder(
                animation: cart!,
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
                        builder: (_) =>
                            CartScope(
                              notifier: cart,
                              child: CartScreen(
                                restaurantId: restaurantId,
                                customerId: widget.customer.id,
                              ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        )
            : StreamBuilder<List<GroupOrderItem>>(
                stream: DatabaseService().watchGroupItems(widget.groupOrderId!),
                builder: (context, snapshot) {
                  final allItems = snapshot.data ?? [];

                  final myItemCount = allItems
                .where((item) => item.memberId == widget.customer.id)
                .fold<int>(
              0,
                  (sum, item) => sum + item.quantity,
            );

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      FloatingActionButton.extended(
                        onPressed: _navigateToGroupOrderSummary,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Group Order'),
                      ),

                      if (myItemCount > 0)
                  Positioned(
                    right: -2,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '$myItemCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    if (widget.groupOrderId == null) {
      return page;
    }

    return StreamBuilder<bool>(
      stream: DatabaseService().watchIsGroupMember(
        groupOrderId: widget.groupOrderId!,
        customerId: widget.customer.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You were removed from the group order.'),
              ),
            );

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => CartScope(
                  notifier: CartController(),
                  child: RestaurantMenuPage(
                    restaurant: widget.restaurant,
                    customer: widget.customer,
                  ),
                ),
              ),
            );
          });

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return page;
      },
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
                          restaurant.rating.toStringAsFixed(1),
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
                      runSpacing: 6,
                      children: restaurant.tags
                          .map((tag) => _TagChip(text: tag.label))
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
    this.onIncrement,
    this.count = 0,
  });

  final MenuItem item;
  final Future<void> Function() onAdd;
  final Future<void> Function()? onIncrement;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Ink(
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
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await onAdd();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 84,
                            height: 84,
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_not_supported,
                              color: scheme.outline,
                            ),
                          ),
                        )
                      : Container(
                          width: 84,
                          height: 84,
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.fastfood, color: scheme.outline),
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
                        '${item.price.toStringAsFixed(2)} SAR',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Incl. 15% tax',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 10),
                  Material(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onIncrement == null
                          ? null
                          : () async {
                              await onIncrement!();
                            },
                      child: Container(
                        width: 42,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: scheme.onPrimary, size: 22),
                            const SizedBox(height: 2),
                            Text(
                              '$count',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigPickerSheet extends StatelessWidget {
  const _ConfigPickerSheet({
    required this.item,
    required this.lines,
  });

  final MenuItem item;
  final List<cart_lines.CartItem> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add another ${item.name}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick which one to add',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            ...lines.map((line) {
              final summary = line.customizationSummary.isEmpty
                  ? 'No customizations'
                  : line.customizationSummary;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => Navigator.pop(context, line),
                  title: Text(summary),
                  subtitle: Text(
                    'In cart: ${line.quantity} • '
                    '${line.unitPrice.toStringAsFixed(2)} SAR each (incl. tax)',
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _GroupOrderStatusBar extends StatelessWidget {
  const _GroupOrderStatusBar({
    required this.groupOrderId,
    required this.customerId,
    this.autoShowQr = false,
    this.onSummaryTap,
  });

  final String groupOrderId;
  final String customerId;
  final bool autoShowQr;
  final VoidCallback? onSummaryTap;

  @override
  Widget build(BuildContext context) {
    return _GroupOrderStatusBarBody(
      groupOrderId: groupOrderId,
      customerId: customerId,
      autoShowQr: autoShowQr,
      onSummaryTap: onSummaryTap,
    );
  }
}

class _GroupOrderStatusBarBody extends StatefulWidget {
  const _GroupOrderStatusBarBody({
    required this.groupOrderId,
    required this.customerId,
    required this.autoShowQr,
    this.onSummaryTap,
  });

  final String groupOrderId;
  final String customerId;
  final bool autoShowQr;
  final VoidCallback? onSummaryTap;

  @override
  State<_GroupOrderStatusBarBody> createState() =>
      _GroupOrderStatusBarBodyState();
}

class _GroupOrderStatusBarBodyState extends State<_GroupOrderStatusBarBody> {
  bool _didAutoShowQr = false;

  void _showQrDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Group Order QR'),
          content: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    size: 220,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StreamBuilder<GroupOrder?>(
      stream: db.watchGroupOrder(widget.groupOrderId),
      builder: (context, snapshot) {
        final groupOrder = snapshot.data;

        if (groupOrder == null) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }

        if (widget.autoShowQr && !_didAutoShowQr) {
          _didAutoShowQr = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            _showQrDialog(context, groupOrder.joinCode);
          });
        }

        return InkWell(
          onTap: widget.onSummaryTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.groups,
                    color: scheme.onPrimary,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Order Active',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Code: ${groupOrder.joinCode} • ${groupOrder.status.name}',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                InkWell(
                  onTap: () => _showQrDialog(context, groupOrder.joinCode),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: QrImageView(
                      data: groupOrder.joinCode,
                      version: QrVersions.auto,
                      size: 46,
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
}
