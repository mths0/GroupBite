import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/cart_models.dart' as cart_models;
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/group_order.dart';
import 'package:food_delivery_platform/models/item_customization_result.dart';
import 'package:food_delivery_platform/models/menu_item.dart';
import 'package:food_delivery_platform/models/restaurant.dart' as app_models;
import 'package:food_delivery_platform/models/restaurant_tag.dart';
import 'package:food_delivery_platform/pages/customer/cart_screen.dart';
import 'package:food_delivery_platform/pages/customer/checkout_screen.dart';
import 'package:food_delivery_platform/pages/customer/item_customization_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RestaurantMenuPage extends StatefulWidget {
  const RestaurantMenuPage({
    super.key,
    required this.restaurant,
    required this.customer,
    this.groupOrderId,
  });

  final app_models.Restaurant restaurant;
  final Customer customer;
  final String? groupOrderId;

  bool get isInGroupOrder => groupOrderId != null;
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
  void _openGroupOrderSummary({
    required String groupOrderId,
    required String restaurantId,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return StreamBuilder<GroupOrder?>(
          stream: DatabaseService().watchGroupOrder(groupOrderId),
          builder: (context, groupSnapshot) {
            final groupOrder = groupSnapshot.data;

            if (groupOrder == null) {
              return const SafeArea(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final isHost = groupOrder.hostCustomerId == widget.customer.id;

            return StreamBuilder<List<GroupOrderMember>>(
              stream: DatabaseService().watchGroupMembers(groupOrderId),
              builder: (context, membersSnapshot) {
                final members = membersSnapshot.data ?? [];

                return StreamBuilder<List<GroupOrderItem>>(
                  stream: DatabaseService().watchGroupItems(groupOrderId),
                  builder: (context, itemsSnapshot) {
                    final allItems = itemsSnapshot.data ?? [];

                    final myItems = allItems
                        .where((item) => item.memberId == widget.customer.id)
                        .toList();

                    final mySubtotal = myItems.fold<double>(
                      0.0,
                      (sum, item) => sum + item.lineTotal,
                    );

                    final memberCount = members.isEmpty ? 1 : members.length;
                    final hasMinimumMembers = members.length >= 2;
                    final deliveryFee = widget.restaurant.deliveryFee;
                    final deliveryShare = deliveryFee / memberCount;
                    final tax = mySubtotal * 0.15;
                    final total = mySubtotal + deliveryShare + tax;

                    GroupOrderMember? myMember;

                    for (final member in members) {
                      if (member.customerId == widget.customer.id) {
                        myMember = member;
                        break;
                      }
                    }

                    final myStatus =
                        myMember?.status ?? GroupMemberStatus.ordering;
                    final iAmReady = myStatus == GroupMemberStatus.ready;
                    final iAlreadyPaid = myStatus == GroupMemberStatus.paid;

                    final allReadyOrPaid =
                        members.isNotEmpty &&
                        members.every(
                          (member) =>
                              member.status == GroupMemberStatus.ready ||
                              member.status == GroupMemberStatus.paid,
                        );

                    final allOtherMembersPaid =
                        members.isNotEmpty &&
                        members
                            .where(
                              (member) =>
                                  member.customerId != widget.customer.id,
                            )
                            .every(
                              (member) =>
                                  member.status == GroupMemberStatus.paid,
                            );

                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.78,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Group Order',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'Delivery fee is split between $memberCount member(s).',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),

                              const SizedBox(height: 12),

                              Text(
                                'Members',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),

                              const SizedBox(height: 8),

                              SizedBox(
                                height: 120,
                                child: members.isEmpty
                                    ? const Center(
                                        child: Text('No members yet.'),
                                      )
                                    : ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: members.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(width: 8),
                                        itemBuilder: (context, index) {
                                          final member = members[index];

                                          final memberSubtotal = allItems
                                              .where(
                                                (item) =>
                                                    item.memberId ==
                                                    member.customerId,
                                              )
                                              .fold<double>(
                                                0.0,
                                                (sum, item) =>
                                                    sum + item.lineTotal,
                                              );

                                          return SizedBox(
                                            width: 180,
                                            child: Card(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      member.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Items: ${memberSubtotal.toStringAsFixed(2)} SAR',
                                                    ),
                                                    const SizedBox(height: 8),
                                                    _MemberStatusChip(
                                                      status: member.status,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),

                              const SizedBox(height: 12),

                              Text(
                                'Your Items',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),

                              const SizedBox(height: 8),
                              if (!hasMinimumMembers)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Group order needs at least 2 members before checkout.',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                              if (myItems.isEmpty)
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'You have not added any items yet.',
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: myItems.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final item = myItems[index];

                                      return Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${item.unitPrice.toStringAsFixed(2)} SAR x${item.quantity}',
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Total: ${item.lineTotal.toStringAsFixed(2)} SAR',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    onPressed: () async {
                                                      await DatabaseService()
                                                          .decrementGroupOrderItem(
                                                            groupOrderId:
                                                                groupOrderId,
                                                            memberId: widget
                                                                .customer
                                                                .id,
                                                            itemId: item.id,
                                                          );
                                                    },
                                                    icon: const Icon(
                                                      Icons
                                                          .remove_circle_outline,
                                                    ),
                                                  ),
                                                  Text('${item.quantity}'),
                                                  IconButton(
                                                    onPressed: () async {
                                                      await DatabaseService()
                                                          .incrementGroupOrderItem(
                                                            groupOrderId:
                                                                groupOrderId,
                                                            memberId: widget
                                                                .customer
                                                                .id,
                                                            itemId: item.id,
                                                          );
                                                    },
                                                    icon: const Icon(
                                                      Icons.add_circle_outline,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () async {
                                                      await DatabaseService()
                                                          .removeGroupOrderItem(
                                                            groupOrderId:
                                                                groupOrderId,
                                                            memberId: widget
                                                                .customer
                                                                .id,
                                                            itemId: item.id,
                                                          );
                                                    },
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              const Divider(),

                              _GroupSummaryRow(
                                label: 'Your Items Subtotal',
                                value: mySubtotal,
                              ),
                              _GroupSummaryRow(
                                label:
                                    'Delivery Share (${deliveryFee.toStringAsFixed(2)} ÷ $memberCount)',
                                value: deliveryShare,
                              ),
                              _GroupSummaryRow(
                                label: 'Tax (15%)',
                                value: tax,
                              ),
                              _GroupSummaryRow(
                                label: 'Your Total',
                                value: total,
                                isBold: true,
                              ),

                              const SizedBox(height: 12),

                              if (!iAmReady && !iAlreadyPaid)
                                FilledButton.icon(
                                  onPressed:
                                      (!hasMinimumMembers || myItems.isEmpty)
                                      ? null
                                      : () async {
                                          await DatabaseService()
                                              .markGroupMemberReady(
                                                groupOrderId: groupOrderId,
                                                customerId: widget.customer.id,
                                              );

                                          if (!context.mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'You are ready. Waiting for others.',
                                              ),
                                            ),
                                          );
                                        },
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  icon: const Icon(Icons.check),
                                  label: const Text('I Am Ready'),
                                ),

                              if (iAmReady)
                                FilledButton(
                                  onPressed:
                                      (!hasMinimumMembers ||
                                          (isHost
                                              ? !allOtherMembersPaid
                                              : !allReadyOrPaid))
                                      ? null
                                      : () {
                                          Navigator.pop(bottomSheetContext);

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CheckoutScreen(
                                                cartItems: myItems.map((item) {
                                                  return cart_models.CartItem(
                                                    id: item.menuItemId,
                                                    name: item.name,
                                                    description:
                                                        item.description,
                                                    imagePath: item.imageUrl,
                                                    unitPrice: item.unitPrice,
                                                    quantity: item.quantity,
                                                  );
                                                }).toList(),
                                                checkoutData:
                                                    cart_models.CheckoutData(
                                                      deliveryFee:
                                                          deliveryShare,
                                                      taxRate: 0.15,
                                                      walletBalance: 100.0,
                                                    ),
                                                subtotal: mySubtotal,
                                                tax: tax,
                                                discount: 0.0,
                                                total: total,
                                                customerId: widget.customer.id,
                                                restaurantId: restaurantId,
                                                groupOrderId: groupOrderId,
                                                isGroupHost: isHost,
                                              ),
                                            ),
                                          );
                                        },
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  child: Text(
                                    isHost
                                        ? allOtherMembersPaid
                                              ? 'Pay Last & Place Group Order • ${total.toStringAsFixed(2)} SAR'
                                              : 'Waiting for members to pay first'
                                        : allReadyOrPaid
                                        ? 'Pay My Part • ${total.toStringAsFixed(2)} SAR'
                                        : 'Waiting for everyone to be ready',
                                  ),
                                ),

                              if (iAlreadyPaid)
                                FilledButton.icon(
                                  onPressed: null,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Your Part Is Paid'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _startGroupOrder() async {
    final groupOrderId = await DatabaseService().createGroupOrder(
      hostCustomerId: widget.customer.id,
      hostName: widget.customer.name,
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
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _menuFuture = DatabaseService().getMenuForRestaurant(
      restaurantId: widget.restaurant.id,
    );
  }

  late final Future<List<MenuItem>> _menuFuture;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cart = widget.groupOrderId == null ? CartScope.read(context) : null;
    final restaurantId = widget.restaurant.id;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: FutureBuilder<List<MenuItem>>(
        future: _menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load menu items'),
            );
          }

          final items = snapshot.data ?? [];

          return Column(
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
                ),
              const SizedBox(height: 8),

              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.outline,
                indicatorColor: scheme.primary,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),

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
                          onAdd: () async {
                            ItemCustomizationResult? customization;

                            if (item.optionGroups.isNotEmpty) {
                              customization =
                                  await Navigator.push<ItemCustomizationResult>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ItemCustomizationScreen(item: item),
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
                                    customization?.selectedOptions ?? const [],
                                customUnitPrice: customization?.finalUnitPrice,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item.name} added to cart'),
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

                            if (member.status == GroupMemberStatus.ready ||
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
                                  customization?.selectedOptions ?? const [],
                              customUnitPrice: customization?.finalUnitPrice,
                            );

                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${item.name} added to group order',
                                ),
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
                            builder: (_) => CartScope(
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
                      onPressed: () {
                        _openGroupOrderSummary(
                          groupOrderId: widget.groupOrderId!,
                          restaurantId: restaurantId,
                        );
                      },
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
                              color: Theme.of(context).colorScheme.surface,
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
  });

  final MenuItem item;
  final Future<void> Function() onAdd;

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
              onPressed: () async {
                await onAdd();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupOrderStatusBar extends StatelessWidget {
  const _GroupOrderStatusBar({
    required this.groupOrderId,
    required this.customerId,
  });

  final String groupOrderId;
  final String customerId;

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
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<GroupOrder?>(
      stream: db.watchGroupOrder(groupOrderId),
      builder: (context, snapshot) {
        final groupOrder = snapshot.data;

        if (groupOrder == null) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }

        return Container(
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
                        color: scheme.onPrimaryContainer.withOpacity(0.75),
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
        );
      },
    );
  }
}

class _GroupSummaryRow extends StatelessWidget {
  const _GroupSummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final double value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${value.toStringAsFixed(2)} SAR', style: style),
        ],
      ),
    );
  }
}

class _MemberStatusChip extends StatelessWidget {
  const _MemberStatusChip({
    required this.status,
  });

  final GroupMemberStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case GroupMemberStatus.ordering:
        color = Colors.orange;
        text = 'Ordering';
        icon = Icons.shopping_bag_outlined;
        break;
      case GroupMemberStatus.ready:
        color = Colors.blue;
        text = 'Ready';
        icon = Icons.check;
        break;
      case GroupMemberStatus.paid:
        color = Colors.green;
        text = 'Paid';
        icon = Icons.payments_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
