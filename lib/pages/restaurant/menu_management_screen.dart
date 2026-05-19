import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/models/menu_item.dart';
import 'package:food_delivery_platform/models/menu_item_option.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/restaurant/restaurant_dashboard.dart';
import 'package:food_delivery_platform/themes/app_theme.dart';
import 'package:food_delivery_platform/widgets/confirm_dialog.dart';
import 'package:image_picker/image_picker.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  static const List<String> _defaultTabs = [
    "Mains",
    "Appetizers",
    "Desserts",
    "Drinks",
  ];

  int _selectedTabIndex = 0;

  final Map<String, Stream<firestore.QuerySnapshot<Map<String, dynamic>>>>
  _streamCache = {};

  firestore.DocumentReference<Map<String, dynamic>> get _restaurantDoc =>
      firestore.FirebaseFirestore.instance
          .collection("users")
          .doc(widget.restaurant.id);

  firestore.CollectionReference<Map<String, dynamic>> get _itemsCol =>
      _restaurantDoc.collection("menu_items");

  Stream<firestore.QuerySnapshot<Map<String, dynamic>>> _streamFor(
    String category,
  ) {
    return _streamCache.putIfAbsent(
      category,
      () => _itemsCol.where("category", isEqualTo: category).snapshots(),
    );
  }

  Future<void> _openManageCategories(List<String> tabs) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ManageCategoriesSheet(
        initialTabs: tabs,
        restaurantId: widget.restaurant.id,
      ),
    );
  }

  Future<void> _addOrEditItem({
    required String category,
    MenuItem? existing,
  }) async {
    final result = await showModalBottomSheet<MenuItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddEditItemSheet(
        restaurantId: widget.restaurant.id,
        category: category,
        existing: existing,
      ),
    );

    if (result == null) return;

    final docId = existing?.id ?? _itemsCol.doc().id;

    await _itemsCol.doc(docId).set(
      {
        ...result.toJson(),
        "id": docId, // ensure ID is set in the document
        "restaurantId": widget.restaurant.id, // ensure restaurantId is set
        "category": result.category, // ensure category is set
        "createdAt": existing != null
            ? firestore.FieldValue.serverTimestamp() // keep original timestamp
            : firestore.FieldValue.serverTimestamp(), // set new timestamp
        "updatedAt": firestore.FieldValue.serverTimestamp(), // track updates
      },
      firestore.SetOptions(merge: true),
    );
  }

  Future<void> _deleteItem(MenuItem item) async {
    final ok = await showDestructiveConfirmDialog(
      context: context,
      title: "Delete item?",
      message: "Are you sure you want to delete “${item.name}”?",
      confirmLabel: "Delete",
    );

    if (ok != true) return;

    await _itemsCol.doc(item.id).delete();
  }

  Future<void> _toggleAvailable(MenuItem item, bool available) async {
    await _itemsCol.doc(item.id).update({
      "updatedAt": firestore.FieldValue.serverTimestamp(),
      "isAvailable": available,
    });
  }

  List<String> _extractCategories(Map<String, dynamic>? data) {
    final raw = data?["categories"];

    if (raw is List) {
      final categories = raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (categories.isNotEmpty) return categories;
    }

    return List<String>.from(_defaultTabs);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firestore.DocumentSnapshot<Map<String, dynamic>>>(
      stream: _restaurantDoc.snapshots(),
      builder: (context, restaurantSnapshot) {
        if (restaurantSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (restaurantSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Menu Management")),
            body: Center(child: Text("Error: ${restaurantSnapshot.error}")),
          );
        }

        final restaurantData = restaurantSnapshot.data?.data();
        final tabs = _extractCategories(restaurantData);
        _streamCache.removeWhere((key, _) => !tabs.contains(key));

        final currentIndex = _selectedTabIndex >= tabs.length
            ? 0
            : _selectedTabIndex;

        return DefaultTabController(
          length: tabs.length,
          initialIndex: currentIndex,
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final scheme = theme.colorScheme;
              return Scaffold(
                body: Column(
                  children: [
                    const RestaurantPageHeader(title: 'Menu'),
                    _CategoryPillBar(
                      tabs: tabs,
                      onSelected: (i) => _selectedTabIndex = i,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: scheme.outlineVariant,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: tabs.map((category) {
                          return StreamBuilder<
                            firestore.QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: _streamFor(category),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snap.hasError) {
                                return Center(
                                  child: Text("Error ${snap.error}"),
                                );
                              }

                              final data = snap.data?.docs ?? [];
                              if (data.isEmpty) {
                                return const Center(
                                  child: Text("No items yet"),
                                );
                              }

                              final items = data
                                  .map((doc) => MenuItem.fromFirestore(doc))
                                  .toList();

                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final item = items[i];
                                  return _MenuItemCard(
                                    item: item,
                                    onEdit: () => _addOrEditItem(
                                      category: category,
                                      existing: item,
                                    ),
                                    onDelete: () => _deleteItem(item),
                                    onToggleAvailable: (v) =>
                                        _toggleAvailable(item, v),
                                  );
                                },
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),

                bottomNavigationBar: Builder(
                  builder: (context) {
                    final tabController = DefaultTabController.of(context);
                    return AnimatedBuilder(
                      animation: tabController,
                      builder: (context, _) {
                        final activeIndex = tabController.index >= tabs.length
                            ? 0
                            : tabController.index;
                        final activeCategory = tabs[activeIndex];

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Divider(
                              height: 1,
                              color: scheme.outlineVariant,
                            ),
                            SafeArea(
                              top: false,
                              minimum: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 54,
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _openManageCategories(tabs),
                                        icon: const Icon(Icons.tune, size: 18),
                                        label: const Text(
                                          'Manage Categories',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor:
                                              scheme.surfaceContainerLowest,
                                          foregroundColor: scheme.onSurface,
                                          side: BorderSide(
                                            color: scheme.outlineVariant,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SizedBox(
                                      height: 54,
                                      child: FilledButton.icon(
                                        onPressed: () => _addOrEditItem(
                                          category: activeCategory,
                                        ),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text(
                                          'Add Item',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ManageCategoriesSheet extends StatefulWidget {
  const _ManageCategoriesSheet({
    required this.initialTabs,
    required this.restaurantId,
  });

  final List<String> initialTabs;
  final String restaurantId;

  @override
  State<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<_ManageCategoriesSheet> {
  late final TextEditingController controller;
  late List<String> _tabs;
  final Set<String> _removedCategories = {};
  final Map<String, String> _renames = {};

  firestore.DocumentReference<Map<String, dynamic>> get _restaurantDoc =>
      firestore.FirebaseFirestore.instance
          .collection("users")
          .doc(widget.restaurantId);

  firestore.CollectionReference<Map<String, dynamic>> get _itemsCol =>
      _restaurantDoc.collection("menu_items");

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    _tabs = List<String>.from(widget.initialTabs);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _addNewCategory() {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    if (_tabs.any((tab) => tab.toLowerCase() == text.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This category already exists.")),
      );
      return;
    }

    setState(() {
      _tabs.add(text);
    });

    controller.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Category “$text” added.")),
    );
  }

  Future<void> _promptDeleteCategory(int index) async {
    if (_tabs.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must have at least one category. Add another before removing this one.',
          ),
        ),
      );
      return;
    }
    final category = _tabs[index];

    final shouldDelete = await showDestructiveConfirmDialog(
      context: context,
      title: 'Delete category?',
      message:
          'This will delete the category “$category” and all menu items inside it.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep it',
    );

    if (shouldDelete != true || !mounted) return;

    setState(() {
      _tabs.removeAt(index);
      _markCategoryRemoved(category);
    });
  }

  void _markCategoryRemoved(String category) {
    if (widget.initialTabs.contains(category)) {
      _removedCategories.add(category);
      return;
    }
    final originalEntry = _renames.entries.firstWhere(
      (e) => e.value == category,
      orElse: () => const MapEntry('', ''),
    );
    if (originalEntry.key.isNotEmpty) {
      _removedCategories.add(originalEntry.key);
      _renames.remove(originalEntry.key);
    }
  }

  Future<void> _editCategory(int index) async {
    final newName = await _showRenameSheet(_tabs[index]);
    if (newName == null || newName.isEmpty) return;

    final oldName = _tabs[index];
    if (newName == oldName) return;

    for (var i = 0; i < _tabs.length; i++) {
      if (i == index) continue;
      if (_tabs[i].toLowerCase() == newName.toLowerCase()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This category already exists.')),
        );
        return;
      }
    }

    setState(() {
      _tabs[index] = newName;
      if (widget.initialTabs.contains(oldName)) {
        _renames[oldName] = newName;
      } else {
        final originalEntry = _renames.entries.firstWhere(
          (e) => e.value == oldName,
          orElse: () => const MapEntry('', ''),
        );
        if (originalEntry.key.isNotEmpty) {
          _renames[originalEntry.key] = newName;
        }
      }
    });
  }

  Future<String?> _showRenameSheet(String currentName) {
    final ctrl = TextEditingController(text: currentName);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rename Category',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Category name'),
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveCategories() async {
    if (_tabs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You need at least one category.")),
      );
      return;
    }

    for (final entry in _renames.entries) {
      if (entry.key == entry.value) continue;
      final snapshot = await _itemsCol
          .where("category", isEqualTo: entry.key)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.update({"category": entry.value});
      }
    }

    for (final removedCategory in _removedCategories) {
      final snapshot = await _itemsCol
          .where("category", isEqualTo: removedCategory)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    await _restaurantDoc.set(
      {
        "categories": _tabs,
        "updatedAt": firestore.FieldValue.serverTimestamp(),
      },
      firestore.SetOptions(merge: true),
    );

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Categories updated successfully.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Manage Categories',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                if (_tabs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No categories yet',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _tabs.length,
                    itemBuilder: (context, index) {
                      return _CategoryManageRow(
                        key: ValueKey(_tabs[index]),
                        index: index,
                        label: _tabs[index],
                        onEdit: () => _editCategory(index),
                        onDelete: () => _promptDeleteCategory(index),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final tab = _tabs.removeAt(oldIndex);
                        _tabs.insert(newIndex, tab);
                      });
                    },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.words,
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'New category',
                        ),
                        onSubmitted: (_) => _addNewCategory(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _addNewCategory,
                      label: const Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saveCategories,
                    child: const Text('Save'),
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

class _CategoryManageRow extends StatelessWidget {
  const _CategoryManageRow({
    super.key,
    required this.index,
    required this.label,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final String label;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              child: Icon(
                Icons.drag_indicator,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, color: scheme.primary, size: 22),
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: scheme.error, size: 22),
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _CategoryPillBar extends StatelessWidget {
  const _CategoryPillBar({required this.tabs, required this.onSelected});

  final List<String> tabs;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SizedBox(
        height: 40,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return Builder(
                  builder: (pillContext) {
                    final selected = i == controller.index;
                    return _CategoryPill(
                      label: tabs[i],
                      selected: selected,
                      onTap: () {
                        controller.animateTo(i);
                        onSelected(i);
                        Scrollable.ensureVisible(
                          pillContext,
                          alignment: 0.5,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? Colors.transparent : scheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailable,
  });

  final MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = theme.extension<BrandColors>()!;
    final priceText = '${item.price.toStringAsFixed(0)} SAR';
    final availableBg = item.isAvailable
        ? brand.success
        : scheme.surfaceContainerHigh;
    final availableFg = item.isAvailable
        ? brand.onSuccess
        : scheme.onSurfaceVariant;

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 110,
                          height: 110,
                          color: scheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.image_not_supported,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Container(
                        width: 110,
                        height: 110,
                        color: scheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.fastfood,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: availableBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              color: availableFg,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.description.trim().isEmpty
                                ? 'No description.'
                                : item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: onDelete,
                          icon: Icon(
                            Icons.delete_outline,
                            color: scheme.error,
                            size: 24,
                          ),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            priceText,
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.9,
                          child: Switch(
                            value: item.isAvailable,
                            onChanged: onToggleAvailable,
                          ),
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

class _AddEditItemSheet extends StatefulWidget {
  const _AddEditItemSheet({
    required this.restaurantId,
    required this.category,
    this.existing,
  });

  final String restaurantId;
  final String category;
  final MenuItem? existing;

  @override
  State<_AddEditItemSheet> createState() => _AddEditItemSheetState();
}

class _AddEditItemSheetState extends State<_AddEditItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descriptionCtrl;
  late List<MenuItemOptionGroup> _optionGroups;
  bool _available = true;
  File? _selectedImageFile;
  String? _existingImageUrl;
  bool _isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _existingImageUrl = widget.existing?.imageUrl;
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? "");
    _priceCtrl = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.price.toStringAsFixed(0)
          : "",
    );
    _descriptionCtrl = TextEditingController(
      text: widget.existing?.description ?? "",
    );
    _available = widget.existing?.isAvailable ?? true;
    _optionGroups = List<MenuItemOptionGroup>.from(
      widget.existing?.optionGroups ?? const [],
    );
    _priceCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _addOptionGroup() async {
    final result = await showModalBottomSheet<MenuItemOptionGroup>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _OptionGroupSheet(),
    );

    if (result == null) return;

    setState(() {
      _optionGroups.add(result);
    });
  }

  void _editOptionGroup(int index) async {
    final result = await showModalBottomSheet<MenuItemOptionGroup>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OptionGroupSheet(existing: _optionGroups[index]),
    );

    if (result == null) return;

    setState(() {
      _optionGroups[index] = result;
    });
  }

  Future<void> _removeOptionGroup(int index) async {
    final group = _optionGroups[index];
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Delete Group',
      message:
          'Delete "${group.title}"? This customization group will be removed from this item.',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _optionGroups.removeAt(index);
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() {
      _selectedImageFile = File(picked.path);
    });
  }

  Future<String> _uploadImage(String itemId) async {
    if (_selectedImageFile == null) {
      return _existingImageUrl ?? '';
    }

    setState(() => _isUploadingImage = true);

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'restaurants/${widget.restaurantId}/menu_items/$itemId.jpg',
      );

      await ref.putFile(_selectedImageFile!);
      return await ref.getDownloadURL();
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.existing?.id.isNotEmpty == true
        ? widget.existing!.id
        : firestore.FirebaseFirestore.instance.collection('tmp').doc().id;

    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;

    final uploadedImageUrl = await _uploadImage(id);

    final item = MenuItem(
      id: id,
      restaurantId: widget.restaurantId,
      name: _nameCtrl.text.trim(),
      price: price,
      category: widget.category,
      isAvailable: _available,
      imageUrl: uploadedImageUrl,
      description: _descriptionCtrl.text.trim(),
      calories: 0,
      optionGroups: _optionGroups,
    );

    if (!mounted) return;
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    final priceValue = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final priceLabel = priceValue > 0
        ? '${priceValue.toStringAsFixed(2)} SAR'
        : '— SAR';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PreviewHeroImage(
                imageFile: _selectedImageFile,
                existingUrl: _existingImageUrl,
                isUploading: _isUploadingImage,
                onTap: _isUploadingImage ? null : _pickImage,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Item Name',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameCtrl,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Cappuccino',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _descriptionCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'Short description',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant,
                      indent: 20,
                      endIndent: 20,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Price (SAR)',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _priceCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: 'Price incl. tax',
                                    ),
                                    validator: (v) {
                                      final t = (v ?? '').trim();
                                      if (t.isEmpty) return 'Required';
                                      final d = double.tryParse(t);
                                      if (d == null || d <= 0) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Switch(
                                      value: _available,
                                      onChanged: (v) =>
                                          setState(() => _available = v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant,
                      indent: 20,
                      endIndent: 20,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Customization Options',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addOptionGroup,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Group'),
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_optionGroups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Text(
                          'No customization groups yet.',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < _optionGroups.length; i++)
                        _PreviewGroupCard(
                          group: _optionGroups[i],
                          onEdit: () => _editOptionGroup(i),
                          onDelete: () => _removeOptionGroup(i),
                        ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isUploadingImage ? null : _save,
                    child: Text(
                      _isUploadingImage
                          ? 'Uploading...'
                          : 'Save  •  $priceLabel',
                    ),
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

class _PreviewHeroImage extends StatelessWidget {
  const _PreviewHeroImage({
    required this.imageFile,
    required this.existingUrl,
    required this.isUploading,
    required this.onTap,
  });

  final File? imageFile;
  final String? existingUrl;
  final bool isUploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget child;
    if (imageFile != null) {
      child = Image.file(imageFile!, fit: BoxFit.cover);
    } else if (existingUrl != null && existingUrl!.isNotEmpty) {
      child = Image.network(
        existingUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(scheme),
      );
    } else {
      child = _placeholder(scheme);
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AspectRatio(aspectRatio: 16 / 10, child: child),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUploading ? Icons.cloud_upload_outlined : Icons.edit,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUploading ? 'Uploading' : 'Change',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
    color: scheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        Icons.add_a_photo_outlined,
        color: scheme.onSurfaceVariant,
        size: 36,
      ),
    ),
  );
}

class _PreviewGroupCard extends StatelessWidget {
  const _PreviewGroupCard({
    required this.group,
    required this.onEdit,
    required this.onDelete,
  });

  final MenuItemOptionGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  group.isRequired ? 'Required' : 'Optional',
                  style: TextStyle(
                    color: group.isRequired
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: scheme.primary),
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: scheme.error),
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (group.choices.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 8),
              child: Text(
                'No choices yet.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            ...group.choices.map(
              (choice) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
                child: Row(
                  children: [
                    _PreviewIndicator(multi: group.multiSelect),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        choice.name,
                        style: TextStyle(
                          fontSize: 15,
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (choice.extraPrice > 0)
                      Text(
                        '+${choice.extraPrice.toStringAsFixed(2)} SAR',
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewIndicator extends StatelessWidget {
  const _PreviewIndicator({required this.multi});

  final bool multi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: multi ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multi ? BorderRadius.circular(4) : null,
        border: Border.all(color: scheme.outline, width: 2),
      ),
    );
  }
}

class _OptionGroupSheet extends StatefulWidget {
  const _OptionGroupSheet({this.existing});

  final MenuItemOptionGroup? existing;

  @override
  State<_OptionGroupSheet> createState() => _OptionGroupSheetState();
}

class _OptionGroupSheetState extends State<_OptionGroupSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  bool _isRequired = false;
  bool _multiSelect = false;

  late List<_EditableChoice> _choices;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _isRequired = widget.existing?.isRequired ?? false;
    _multiSelect = widget.existing?.multiSelect ?? false;

    _choices = (widget.existing?.choices ?? [])
        .map(
          (choice) => _EditableChoice(
            id: choice.id,
            nameCtrl: TextEditingController(text: choice.name),
            priceCtrl: TextEditingController(
              text: choice.extraPrice == 0
                  ? ''
                  : choice.extraPrice.toStringAsFixed(
                      choice.extraPrice.truncateToDouble() == choice.extraPrice
                          ? 0
                          : 2,
                    ),
            ),
          ),
        )
        .toList();

    if (_choices.isEmpty) {
      _choices.add(_EditableChoice.empty());
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final choice in _choices) {
      choice.dispose();
    }
    super.dispose();
  }

  void _addChoice() {
    setState(() {
      _choices.add(_EditableChoice.empty());
    });
  }

  Future<void> _removeChoice(int index) async {
    if (_choices.length == 1) return;

    final name = _choices[index].nameCtrl.text.trim();
    final label = name.isEmpty ? 'this choice' : '"$name"';
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Delete Choice',
      message: 'Delete $label?',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _choices[index].dispose();
      _choices.removeAt(index);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final cleanedChoices = <MenuItemOptionChoice>[];

    for (int i = 0; i < _choices.length; i++) {
      final c = _choices[i];
      final name = c.nameCtrl.text.trim();
      final extraPrice = double.tryParse(c.priceCtrl.text.trim()) ?? 0.0;

      if (name.isEmpty) continue;

      cleanedChoices.add(
        MenuItemOptionChoice(
          id: c.id.isNotEmpty
              ? c.id
              : 'choice_${DateTime.now().microsecondsSinceEpoch}_$i',
          name: name,
          extraPrice: extraPrice,
        ),
      );
    }

    if (cleanedChoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one choice.'),
        ),
      );
      return;
    }

    final group = MenuItemOptionGroup(
      id: widget.existing?.id.isNotEmpty == true
          ? widget.existing!.id
          : 'group_${DateTime.now().microsecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      isRequired: _isRequired,
      multiSelect: _multiSelect,
      choices: cleanedChoices,
    );

    Navigator.pop(context, group);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                widget.existing == null
                    ? 'Add Option Group'
                    : 'Edit Option Group',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Group Title',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Choose Size',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 26),
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          _ToggleRow(
                            title: 'Required',
                            subtitle: 'Customer must select from this group',
                            value: _isRequired,
                            onChanged: (v) =>
                                setState(() => _isRequired = v),
                          ),
                          Divider(
                            height: 1,
                            color: scheme.outlineVariant,
                            indent: 14,
                            endIndent: 14,
                          ),
                          _ToggleRow(
                            title: 'Multi select',
                            subtitle: 'Allow selecting more than one choice',
                            value: _multiSelect,
                            onChanged: (v) =>
                                setState(() => _multiSelect = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Choices',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addChoice,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Choice'),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ..._choices.asMap().entries.map((entry) {
                      final index = entry.key;
                      final choice = entry.value;
                      return _ChoiceEditorRow(
                        nameCtrl: choice.nameCtrl,
                        priceCtrl: choice.priceCtrl,
                        multi: _multiSelect,
                        onDelete: () => _removeChoice(index),
                      );
                    }),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save Group'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ChoiceEditorRow extends StatefulWidget {
  const _ChoiceEditorRow({
    required this.nameCtrl,
    required this.priceCtrl,
    required this.multi,
    required this.onDelete,
  });

  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final bool multi;
  final VoidCallback onDelete;

  @override
  State<_ChoiceEditorRow> createState() => _ChoiceEditorRowState();
}

class _ChoiceEditorRowState extends State<_ChoiceEditorRow> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FormField<String>(
      validator: (_) {
        if (widget.nameCtrl.text.trim().isEmpty) {
          return 'Name required';
        }
        final priceText = widget.priceCtrl.text.trim();
        if (priceText.isNotEmpty) {
          final parsed = double.tryParse(priceText);
          if (parsed == null || parsed < 0) {
            return 'Invalid price';
          }
        }
        return null;
      },
      builder: (state) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: state.hasError
                        ? scheme.error
                        : scheme.outlineVariant,
                    width: state.hasError ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _PreviewIndicator(multi: widget.multi),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: widget.nameCtrl,
                        onChanged: (_) => state.didChange(widget.nameCtrl.text),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Choice name',
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: widget.priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) =>
                            state.didChange(widget.nameCtrl.text),
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: '+0 SAR',
                          hintStyle: TextStyle(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: Icon(
                        Icons.delete_outline,
                        color: scheme.error,
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 0, 0),
                  child: Text(
                    state.errorText!,
                    style: TextStyle(
                      color: scheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

class _EditableChoice {
  _EditableChoice({
    required this.id,
    required this.nameCtrl,
    required this.priceCtrl,
  });

  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;

  factory _EditableChoice.empty() {
    return _EditableChoice(
      id: '',
      nameCtrl: TextEditingController(),
      priceCtrl: TextEditingController(),
    );
  }

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}
