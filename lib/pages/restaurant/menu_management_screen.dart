import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/models/menu_item.dart';
import 'package:food_delivery_platform/models/menu_item_option.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:image_picker/image_picker.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ["Mains", "Appetizers", "Desserts", "Drinks"];

  firestore.CollectionReference<Map<String, dynamic>> get _itemsCol => firestore
      .FirebaseFirestore
      .instance
      .collection("users")
      .doc(widget.restaurant.id)
      .collection("menu_items");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _activeCategory() => _tabs[_tabController.index];

  Future<void> _addOrEditItem({MenuItem? existing}) async {
    final result = await showModalBottomSheet<MenuItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddEditItemSheet(
        restaurantId: widget.restaurant.id,
        category: _activeCategory(),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete item?"),
        content: Text("Are you sure you want to delete “${item.name}”?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _itemsCol.doc(item.id).delete();
  }

  Future<void> _toggleAvailable(MenuItem item, bool available) async {
    await _itemsCol.doc(item.id).update({
      "updatedAt": firestore.FieldValue.serverTimestamp(),
      "available": available,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Menu Management"),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          onTap: (_) => setState(() {}),
        ),
      ),

      // قائمة العناصر حسب التب
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((category) {
          final query = _itemsCol.where("category", isEqualTo: category);

          return StreamBuilder<firestore.QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snap) {
              // Loading state
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return Center(child: Text("Error ${snap.error}"));
              }

              final data = snap.data?.docs ?? [];
              if (data.isEmpty) {
                return const Center(child: Text("No items yet"));
              }

              final items = data
                  .map((doc) => MenuItem.fromFirestore(doc))
                  .toList();

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return _MenuItemCard(
                    item: item,
                    onEdit: () => _addOrEditItem(existing: item),
                    onDelete: () => _deleteItem(item),
                    onToggleAvailable: (v) => _toggleAvailable(item, v),
                  );
                },
              );
            },
          );
        }).toList(),
      ),

      // زر إضافة
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _addOrEditItem(),
              icon: const Icon(Icons.add),
              label: const Text("Add New Item"),
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
    final priceText = "${item.price.toStringAsFixed(0)} SAR";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Colors.black12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 96,
                              height: 96,
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported,
                                color: scheme.outline,
                              ),
                            ),
                          )
                        : Container(
                            width: 96,
                            height: 96,
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.fastfood, color: scheme.outline),
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Texts
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
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                priceText,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.description.trim().isEmpty
                              ? "No description."
                              : item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Availability row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: item.isAvailable
                                    ? const Color(0xFF16A34A).withOpacity(0.12)
                                    : Colors.grey.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: item.isAvailable
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.isAvailable
                                        ? "Available"
                                        : "Unavailable",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: item.isAvailable
                                          ? const Color(0xFF16A34A)
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: item.isAvailable,
                              onChanged: onToggleAvailable,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom actions bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  _actionChip(
                    icon: Icons.edit,
                    label: "Edit",
                    fg: scheme.primary,
                    bg: const Color(0xFFE8F1FF),
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 10),
                  _actionChip(
                    icon: Icons.delete,
                    label: "Delete",
                    fg: const Color(0xFFFF3B30),
                    bg: const Color(0xFFFFE9E9),
                    onTap: onDelete,
                  ),
                  const Spacer(),
                  Text(
                    item.category,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.outline,
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

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color fg,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w900),
            ),
          ],
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
      builder: (_) => _OptionGroupSheet(existing: _optionGroups[index]),
    );

    if (result == null) return;

    setState(() {
      _optionGroups[index] = result;
    });
  }

  void _removeOptionGroup(int index) {
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? "Add Item" : "Edit Item",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Item NAME
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Item name"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
            const SizedBox(height: 10),
            // Item DESCRIPTION
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(labelText: "Description"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
            const SizedBox(height: 10),
            // Item PRICE
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Price (SAR)"),
              validator: (v) {
                final t = (v ?? "").trim();
                if (t.isEmpty) return "Required";
                final d = double.tryParse(t);
                if (d == null || d <= 0) return "Enter a valid price";
                return null;
              },
            ),
            const SizedBox(height: 10),
            // Item IMAGE
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Item Image",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _selectedImageFile != null
                        ? Image.file(
                            _selectedImageFile!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          )
                        : (_existingImageUrl != null &&
                              _existingImageUrl!.isNotEmpty)
                        ? Image.network(
                            _existingImageUrl!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          )
                        : Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingImage ? null : _pickImage,
                    icon: const Icon(Icons.upload),
                    label: Text(
                      _isUploadingImage ? "Uploading..." : "Upload Image",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            SwitchListTile(
              value: _available,
              onChanged: (v) => setState(() => _available = v),
              title: const Text("Available"),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Customization Options',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addOptionGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Group'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_optionGroups.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('No customization groups yet.'),
              )
            else
              ..._optionGroups.asMap().entries.map((entry) {
                final index = entry.key;
                final group = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(group.title),
                    subtitle: Text(
                      '${group.isRequired ? "Required" : "Optional"} • '
                      '${group.multiSelect ? "Multi select" : "Single select"} • '
                      '${group.choices.length} choices',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editOptionGroup(index),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => _removeOptionGroup(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 10),
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text("Save"),
                ),
              ),
            ),
          ],
        ),
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

  void _removeChoice(int index) {
    if (_choices.length == 1) return;

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
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existing == null
                      ? 'Add Option Group'
                      : 'Edit Option Group',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Group title',
                    hintText: 'Example: Choose Size',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                SwitchListTile(
                  value: _isRequired,
                  onChanged: (value) {
                    setState(() {
                      _isRequired = value;
                    });
                  },
                  title: const Text('Required'),
                  subtitle: const Text('Customer must select from this group'),
                  contentPadding: EdgeInsets.zero,
                ),

                SwitchListTile(
                  value: _multiSelect,
                  onChanged: (value) {
                    setState(() {
                      _multiSelect = value;
                    });
                  },
                  title: const Text('Multi select'),
                  subtitle: const Text('Allow selecting more than one choice'),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Text(
                      'Choices',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addChoice,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Choice'),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                ..._choices.asMap().entries.map((entry) {
                  final index = entry.key;
                  final choice = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                'Choice ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => _removeChoice(index),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: choice.nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Choice name',
                              hintText: 'Example: Large',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: choice.priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Extra price (SAR)',
                              hintText: '0',
                            ),
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return null;

                              final parsed = double.tryParse(text);
                              if (parsed == null || parsed < 0) {
                                return 'Enter valid price';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save Group'),
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
