import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:yjeek/cart/cart_controller.dart';
import 'package:yjeek/cart/cart_scope.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/cart_item.dart' as cart_lines;
import 'package:yjeek/models/customer.dart';
import 'package:yjeek/models/group_order.dart';
import 'package:yjeek/models/item_customization_result.dart';
import 'package:yjeek/models/menu_item.dart';
import 'package:yjeek/models/restaurant.dart' as app_models;
import 'package:yjeek/models/restaurant_tag.dart';
import 'package:yjeek/pages/customer/cart_screen.dart';
import 'package:yjeek/pages/customer/group_order_summary_screen.dart';
import 'package:yjeek/pages/customer/item_customization_screen.dart';
import 'package:yjeek/themes/app_theme.dart';
import 'package:yjeek/widgets/confirm_dialog.dart';
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

    final bool? shouldLeave = await showDestructiveConfirmDialog(
      context: context,
      title: isHost ? 'End Group Order?' : 'Leave Group Order?',
      message: isHost
          ? 'As the host, leaving will cancel the group order for everyone. Are you sure?'
          : 'Leaving will remove you from the group and delete your items. Are you sure?',
      confirmLabel: isHost ? 'End Order' : 'Leave Group',
      cancelLabel: 'Stay',
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

  final GlobalKey _naturalChipBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _menuFuture = DatabaseService().getMenuForRestaurant(
      restaurantId: widget.restaurant.id,
    );
    _scrollController.addListener(_onScrollUpdate);
  }

  void _onScrollUpdate() {
    final keyContext = _naturalChipBarKey.currentContext;
    if (keyContext == null) return;
    final renderObject = keyContext.findRenderObject();
    if (renderObject is! RenderBox) return;
    final position = renderObject.localToGlobal(Offset.zero);
    final topInset = MediaQuery.of(context).padding.top;
    final pinned = position.dy <= topInset + _chipBarTopPadding;
    if (pinned != _isChipBarPinned) {
      setState(() => _isChipBarPinned = pinned);
    }
  }

  late final Future<List<MenuItem>> _menuFuture;

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  int _selectedTabIndex = 0;

  static const double _chipBarHeight = 65;
  static const double _chipBarTopPadding = 56;

  bool _isChipBarPinned = false;

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _sectionKey(String category) {
    return _sectionKeys.putIfAbsent(category, () => GlobalKey());
  }

  void _onChipTap(List<String> tabs, int index) {
    setState(() => _selectedTabIndex = index);
    final keyContext = _sectionKeys[tabs[index]]?.currentContext;
    if (keyContext == null) return;
    final renderObject = keyContext.findRenderObject();
    if (renderObject is! RenderBox) return;
    final viewport = RenderAbstractViewport.of(renderObject);
    final revealOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final position = _scrollController.position;
    final topInset = MediaQuery.of(context).padding.top;
    final pinnedHeight = _chipBarHeight + topInset + _chipBarTopPadding;
    final target = (revealOffset - pinnedHeight).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

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
        body: Stack(
          children: [
            FutureBuilder<List<MenuItem>>(
              future: _menuFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load menu items: ${snapshot.error}',
                    ),
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
                          _RestaurantHero(
                            imageUrl: widget.restaurant.imageUrl,
                          ),
                          HeaderCard(restaurant: widget.restaurant),
                          const Expanded(
                            child: Center(
                              child: Text('No menu categories yet'),
                            ),
                          ),
                        ],
                      );
                    }

                final topInset = MediaQuery.of(context).padding.top;

                return StreamBuilder<List<GroupOrderItem>>(
                      stream: widget.groupOrderId == null
                          ? null
                          : DatabaseService()
                              .watchGroupItems(widget.groupOrderId!),
                      builder: (context, groupItemsSnap) {
                        final groupItems =
                            groupItemsSnap.data ?? const <GroupOrderItem>[];

                        final rows = <Widget>[];
                        for (final cat in tabs) {
                            final filtered = items
                                .where((e) => e.category == cat)
                                .toList();
                            rows.add(
                              Padding(
                                key: _sectionKey(cat),
                                padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
                                child: Text(
                                  cat,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                            );
                            if (filtered.isEmpty) {
                              rows.add(
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'No items',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                              continue;
                            }
                            for (var i = 0; i < filtered.length; i++) {
                              final item = filtered[i];

                              Future<void> handleTap() async {
                                  final customization =
                                      await showModalBottomSheet<
                                        ItemCustomizationResult
                                      >(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
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

                                  if (widget.groupOrderId == null) {
                                    cart!.addItem(
                                      restaurantId: restaurantId,
                                      item: item,
                                      selectedOptions:
                                          customization.selectedOptions,
                                      customUnitPrice:
                                          customization.finalUnitPrice,
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
                                        customization.selectedOptions,
                                    customUnitPrice:
                                        customization.finalUnitPrice,
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
                                  final myLines = groupItems
                                      .where(
                                        (g) =>
                                    g.menuItemId == item.id &&
                                        g.memberId == widget.customer.id,
                                  )
                                      .toList();
                                  final myCount = myLines.fold<int>(
                                    0,
                                        (s, g) => s + g.quantity,
                                  );

                                  Future<void> handleGroupIncrement() async {
                                    if (myLines.isEmpty) return;

                                    final member = await DatabaseService()
                                        .getGroupMember(
                                      groupOrderId: widget.groupOrderId!,
                                      customerId: widget.customer.id,
                                    );

                                    if (member == null) return;

                                    if (member.status ==
                                        GroupMemberStatus.ready ||
                                        member.status ==
                                            GroupMemberStatus.paid) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'You already marked yourself ready. You cannot add more items.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    GroupOrderItem? chosen;
                                    if (myLines.length == 1) {
                                      chosen = myLines.first;
                                    } else {
                                      chosen =
                                      await showModalBottomSheet<
                                          GroupOrderItem
                                      >(
                                        context: context,
                                        showDragHandle: true,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.vertical(
                                            top: Radius.circular(20),
                                          ),
                                        ),
                                        builder: (_) =>
                                            _GroupConfigPickerSheet(
                                              item: item,
                                              lines: myLines,
                                            ),
                                      );
                                    }

                                    if (chosen == null) return;

                                    await DatabaseService()
                                        .incrementGroupOrderItem(
                                      groupOrderId: widget.groupOrderId!,
                                      memberId: widget.customer.id,
                                      itemId: chosen.id,
                                    );
                                  }

                                  rows.add(
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _MenuItemTile(
                                        item: item,
                                        count: myCount,
                                        onAdd: handleTap,
                                        onIncrement: myCount > 0
                                            ? handleGroupIncrement
                                            : null,
                                      ),
                                    ),
                                  );
                                  continue;
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

                                rows.add(
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                    ),
                                    child: AnimatedBuilder(
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
                                    ),
                                  ),
                                );
                              }
                            }

                        return Stack(
                          children: [
                            CustomScrollView(
                          controller: _scrollController,
                          cacheExtent: 10000,
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  _RestaurantHero(
                                    imageUrl: widget.restaurant.imageUrl,
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, -32),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: HeaderCard(
                                        restaurant: widget.restaurant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: widget.groupOrderId == null
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: _startGroupOrder,
                                          icon: const Icon(Icons.group_add),
                                          label: const Text(
                                            'Start Group Order',
                                          ),
                                        ),
                                      ),
                                    )
                                  : _GroupOrderStatusBar(
                                      groupOrderId: widget.groupOrderId!,
                                      customerId: widget.customer.id,
                                      autoShowQr: widget.showGroupQrOnOpen,
                                      onSummaryTap:
                                          _navigateToGroupOrderSummary,
                                    ),
                            ),
                            SliverToBoxAdapter(
                              child: Container(
                                key: _naturalChipBarKey,
                                color: scheme.surface,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: _CategoryChipBar(
                                        tabs: tabs,
                                        selectedIndex: _selectedTabIndex.clamp(
                                          0,
                                          tabs.length - 1,
                                        ),
                                        onSelect: (i) => _onChipTap(tabs, i),
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      color: scheme.outlineVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                120,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate(rows),
                              ),
                            ),
                          ],
                        ),
                            if (_isChipBarPinned)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: scheme.surface,
                                  padding: EdgeInsets.only(
                                    top: topInset + _chipBarTopPadding,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: _CategoryChipBar(
                                          tabs: tabs,
                                          selectedIndex: _selectedTabIndex
                                              .clamp(0, tabs.length - 1),
                                          onSelect: (i) =>
                                              _onChipTap(tabs, i),
                                        ),
                                      ),
                                      Divider(
                                        height: 1,
                                        color: scheme.outlineVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
              },
            );
          },
        ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: _StickyBackButton(
                onTap: () async {
                  final shouldPop = await _handleBackAction();
                  if (shouldPop && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.groupOrderId == null
            ? AnimatedBuilder(
                animation: cart!,
                builder: (_, _) {
                  final count = cart.itemCount(restaurantId);
                  if (count == 0) return const SizedBox.shrink();
                  return _ViewCartBar(
                    count: count,
                    label: 'View Cart',
                    trailing:
                        '${cart.subtotal(restaurantId).toStringAsFixed(2)} SAR',
                    onTap: () {
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
                  );
                },
              )
            : StreamBuilder<List<GroupOrderItem>>(
                stream: DatabaseService().watchGroupItems(widget.groupOrderId!),
                builder: (context, snapshot) {
                  final allItems = snapshot.data ?? [];
                  final myItems = allItems
                      .where((item) => item.memberId == widget.customer.id)
                      .toList();
                  final myCount = myItems.fold<int>(
                    0,
                    (sum, item) => sum + item.quantity,
                  );
                  if (myCount == 0) return const SizedBox.shrink();
                  final mySubtotal = myItems.fold<double>(
                    0,
                    (sum, item) => sum + (item.unitPrice * item.quantity),
                  );
                  return _ViewCartBar(
                    count: myCount,
                    label: 'View Group Order',
                    trailing: '${mySubtotal.toStringAsFixed(2)} SAR',
                    onTap: _navigateToGroupOrderSummary,
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

class _RestaurantHero extends StatelessWidget {
  const _RestaurantHero({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 260 + topInset,
      width: double.infinity,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: scheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyBackButton extends StatelessWidget {
  const _StickyBackButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.95),
      shape: CircleBorder(
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_back,
            size: 20,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class HeaderCard extends StatelessWidget {
  const HeaderCard({super.key, required this.restaurant});

  final app_models.Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = theme.extension<BrandColors>()!;
    final cuisine = restaurant.tags
        .take(2)
        .map((t) => t.label)
        .join('  •  ');

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (cuisine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            cuisine,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _HeaderBadge(
                        label: restaurant.isOpen ? 'Open' : 'Closed',
                        background: restaurant.isOpen
                            ? brand.openStatus
                            : scheme.outline,
                        foreground: restaurant.isOpen
                            ? brand.onOpenStatus
                            : scheme.surface,
                      ),
                      if (restaurant.hasOffer) ...[
                        const SizedBox(height: 6),
                        _HeaderBadge(
                          label: 'Offer',
                          background: brand.offer,
                          foreground: brand.onOffer,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Fee',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        restaurant.deliveryFee == 0
                            ? 'Free'
                            : '${restaurant.deliveryFee.toStringAsFixed(2)} SAR',
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: scheme.secondary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CategoryChipBar extends StatefulWidget {
  const _CategoryChipBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  State<_CategoryChipBar> createState() => _CategoryChipBarState();
}

class _CategoryChipBarState extends State<_CategoryChipBar> {
  final ScrollController _controller = ScrollController();
  final Map<int, GlobalKey> _chipKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(covariant _CategoryChipBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!mounted || !_controller.hasClients) return;
    final ctx = _chipKeys[widget.selectedIndex]?.currentContext;
    final renderObject = ctx?.findRenderObject();
    if (renderObject == null) return;
    _controller.position.ensureVisible(
      renderObject,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = widget.selectedIndex == index;
          final key = _chipKeys.putIfAbsent(index, () => GlobalKey());
          return Material(
            key: key,
            color: selected ? scheme.primary : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => widget.onSelect(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Text(
                  widget.tabs[index],
                  style: TextStyle(
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ViewCartBar extends StatelessWidget {
  const _ViewCartBar({
    required this.count,
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  final int count;
  final String label;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 56,
            child: Material(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    trailing,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ),
      ],
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
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await onAdd();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _MenuItemPlaceholder(scheme: scheme),
                        )
                      : _MenuItemPlaceholder(scheme: scheme),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${item.price.toStringAsFixed(2)} SAR',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (count > 0)
                            _CountPill(
                              count: count,
                              onTap: onIncrement,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemPlaceholder extends StatelessWidget {
  const _MenuItemPlaceholder({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      color: scheme.surfaceContainerHigh,
      child: Icon(
        Icons.restaurant_menu,
        color: scheme.outline,
        size: 28,
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, this.onTap});

  final int count;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap == null
            ? null
            : () async {
                await onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_shopping_cart,
                color: scheme.onPrimary,
                size: 16,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
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

class _GroupConfigPickerSheet extends StatelessWidget {
  const _GroupConfigPickerSheet({
    required this.item,
    required this.lines,
  });

  final MenuItem item;
  final List<GroupOrderItem> lines;

  String _summaryFor(GroupOrderItem line) {
    if (line.selectedOptions.isEmpty) return 'No customizations';
    return line.selectedOptions
        .map((o) => '${o.groupTitle}: ${o.choiceName}')
        .join(' • ');
  }

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
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => Navigator.pop(context, line),
                  title: Text(_summaryFor(line)),
                  subtitle: Text(
                    'In cart: ${line.quantity} • '
                        '${line.unitPrice.toStringAsFixed(
                        2)} SAR each (incl. tax)',
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
  bool _didRequestClose = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showQrDialog(BuildContext context, String code) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          clipBehavior: Clip.antiAlias,
          backgroundColor: scheme.surfaceContainerLowest,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'JOIN CODE',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      code,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: scheme.onPrimary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Join code copied!'),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_all_rounded,
                                color: scheme.onPrimary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Copy Code',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                child: Text(
                  'Invite friends to start eating together',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    size: 180,
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
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

        if (!_didRequestClose && DateTime.now().isAfter(groupOrder.expiresAt)) {
          _didRequestClose = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DatabaseService().expireGroupOrderIfNeeded(
              groupOrderId: widget.groupOrderId,
            );
          });
        }

        return InkWell(
          onTap: widget.onSummaryTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.groups,
                    color: scheme.onPrimary,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Order Active',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Code: ',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer.withValues(
                                  alpha: 0.75,
                                ),
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: groupOrder.joinCode,
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'closes in ${_formatRemaining(groupOrder.expiresAt)}',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 13,
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
