import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:food_delivery_platform/pages/restaurant/restaurant_dashboard.dart';
import 'package:food_delivery_platform/themes/app_theme.dart';
import 'package:food_delivery_platform/widgets/confirm_dialog.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({
    super.key,
    required this.restaurantId,
  });
  final String restaurantId;

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  firestore.CollectionReference<Map<String, dynamic>> get _promosCol =>
      firestore.FirebaseFirestore.instance
          .collection("users")
          .doc(widget.restaurantId)
          .collection("promotions");

  Future<void> _openAddEdit({Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (_) => _AddEditPromotionSheet(existing: existing),
    );
    if (result == null) return;

    final docId = (existing?['id']?.toString().trim().isNotEmpty ?? false)
        ? existing!['id'].toString()
        : _promosCol.doc().id;

    await _promosCol.doc(docId).set({
      ...result,
      "id": docId,
      "createdAt":
          existing?['createdAt'] ?? firestore.FieldValue.serverTimestamp(),
      "updatedAt": firestore.FieldValue.serverTimestamp(),
    }, firestore.SetOptions(merge: true));
  }

  Future<void> _delete(String promoId, String title) async {
    final ok = await showDestructiveConfirmDialog(
      context: context,
      title: "Delete promotion?",
      message: "Delete “$title”?",
      confirmLabel: "Delete",
    );
    if (ok != true) return;
    await _promosCol.doc(promoId).delete();
  }

  String _calcStatus(Map<String, dynamic> p) {
    final enabled = (p['enabled'] ?? true) == true;
    if (!enabled) return "disabled";

    final start = DateTime.tryParse((p['startAt'] ?? "").toString());
    final end = DateTime.tryParse((p['endAt'] ?? "").toString());
    final now = DateTime.now();

    if (start != null && now.isBefore(start)) return "scheduled";
    if (end != null && now.isAfter(end)) return "expired";
    return "active";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          const RestaurantPageHeader(title: 'Promotions'),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => _openAddEdit(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Create Promotion',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<firestore.QuerySnapshot<Map<String, dynamic>>>(
        stream: _promosCol.orderBy("createdAt", descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No promotions yet'));
          }

          final promos = docs.map((d) {
            final data = d.data();
            return {
              ...data,
              "id": d.id,
            };
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            itemCount: promos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final p = promos[i];
              final status = _calcStatus(p);

              return _PromotionCard(
                title: (p['title'] ?? '').toString(),
                status: status,
                discountType: (p['discountType'] ?? 'percentage').toString(),
                discountValue: (p['discountValue'] ?? 0),
                startAt: (p['startAt'] ?? '').toString(),
                endAt: (p['endAt'] ?? '').toString(),
                minOrder: (p['minOrder'] ?? 0),
                code: (p['code'] ?? '').toString(),
                enabled: (p['enabled'] ?? true) == true,
                onToggleEnabled: (v) => _promosCol.doc(p['id']).update({
                  "enabled": v,
                  "updatedAt": firestore.FieldValue.serverTimestamp(),
                }),
                onEdit: () => _openAddEdit(existing: p),
                onDelete: () => _delete(
                  p['id'].toString(),
                  (p['title'] ?? '').toString(),
                ),
              );
            },
          );
        });
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({
    required this.title,
    required this.status,
    required this.discountType,
    required this.discountValue,
    required this.startAt,
    required this.endAt,
    required this.minOrder,
    required this.code,
    required this.enabled,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String status; // active/scheduled/expired/disabled
  final String discountType; // percent/fixed/free_delivery
  final dynamic discountValue;
  final String startAt;
  final String endAt;
  final dynamic minOrder;
  final String code;
  final bool enabled;

  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  ({Color background, Color foreground}) _badgeColors(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = Theme.of(context).extension<BrandColors>()!;
    switch (status) {
      case 'active':
        return (background: brand.success, foreground: brand.onSuccess);
      case 'scheduled':
        return (
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
        );
      case 'expired':
        return (background: scheme.errorContainer, foreground: scheme.error);
      case 'disabled':
      default:
        return (
          background: scheme.surfaceContainerHigh,
          foreground: scheme.onSurfaceVariant,
        );
    }
  }

  String get _badgeText {
    switch (status) {
      case 'active':
        return 'Active';
      case 'scheduled':
        return 'Scheduled';
      case 'expired':
        return 'Expired';
      case 'disabled':
        return 'Disabled';
      default:
        return status;
    }
  }

  String get _discountLine {
    if (discountType == 'free_delivery') return 'Free delivery';
    if (discountType == 'fixed') {
      final v = (discountValue is num) ? discountValue as num : 0;
      final formatted = v == v.toInt() ? v.toInt().toString() : v.toString();
      return '$formatted SAR off';
    }
    final v = (discountValue is num) ? discountValue as num : 0;
    return '${v.toInt()}% off';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badge = _badgeColors(context);
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
          padding: const EdgeInsets.all(16),
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
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (code.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            code,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badge.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _badgeText,
                      style: TextStyle(
                        color: badge.foreground,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Divider(height: 16, color: scheme.outlineVariant),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _discountLine,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 15,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '$startAt – $endAt',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Min. order: ${minOrder.toString()} SAR',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: onDelete,
                          icon: Icon(
                            Icons.delete_outline,
                            color: scheme.error,
                            size: 28,
                          ),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        Switch(value: enabled, onChanged: onToggleEnabled),
                      ],
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

class _AddEditPromotionSheet extends StatefulWidget {
  const _AddEditPromotionSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_AddEditPromotionSheet> createState() => _AddEditPromotionSheetState();
}

class _AddEditPromotionSheetState extends State<_AddEditPromotionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _discountValueCtrl;
  late final TextEditingController _minOrderCtrl;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;

  String _type = "percentage"; // percent | fixed | free_delivery
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    final rawType = (e?['discountType'] ?? 'percentage').toString();
    const allowedTypes = {'percentage', 'fixed', 'free_delivery'};
    _type = allowedTypes.contains(rawType) ? rawType : 'percentage';

    _titleCtrl = TextEditingController(text: (e?['title'] ?? '').toString());
    _codeCtrl = TextEditingController(text: (e?['code'] ?? '').toString());
    _discountValueCtrl = TextEditingController(
      text: _formatDiscountValue(e?['discountValue']),
    );
    _minOrderCtrl = TextEditingController(
      text: (e?['minOrder'] ?? '').toString(),
    );
    _startCtrl = TextEditingController(text: (e?['startAt'] ?? '').toString());
    _endCtrl = TextEditingController(text: (e?['endAt'] ?? '').toString());

    _enabled = (e?['enabled'] ?? true) == true;
  }

  String _formatDiscountValue(dynamic raw) {
    if (raw == null) return '';
    if (_type == 'percentage') {
      final n = (raw is num) ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
      return n.toString();
    }
    return raw.toString();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _codeCtrl.dispose();
    _discountValueCtrl.dispose();
    _minOrderCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  //Todo : use a proper date picker.
  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final formatted =
          "${picked.year.toString().padLeft(4, '0')}-"
          "${picked.month.toString().padLeft(2, '0')}-"
          "${picked.day.toString().padLeft(2, '0')}";

      controller.text = formatted;
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final discountText = _discountValueCtrl.text.trim();
    final num discountValue;
    if (_type == 'free_delivery') {
      discountValue = 0;
    } else if (_type == 'percentage') {
      discountValue = int.tryParse(discountText) ?? 0;
    } else {
      discountValue = double.tryParse(discountText) ?? 0.0;
    }
    final minOrder = double.tryParse(_minOrderCtrl.text.trim()) ?? 0;

    Navigator.pop<Map<String, dynamic>>(context, {
      "title": _titleCtrl.text.trim(),
      "code": _codeCtrl.text.trim().toUpperCase(),
      "discountType": _type,
      "discountValue": discountValue,
      "minOrder": minOrder,
      "startAt": _startCtrl.text.trim(),
      "endAt": _endCtrl.text.trim(),
      "enabled": _enabled,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? 'Create Promotion'
                    : 'Edit Promotion',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),

              _FieldLabel(label: 'Title'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(hintText: 'Promo title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              _FieldLabel(label: 'Coupon Code'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'e.g. SUMMER20'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              _FieldLabel(label: 'Discount Type'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(
                    value: 'percentage',
                    child: Text('Percent (%)'),
                  ),
                  DropdownMenuItem(
                    value: 'fixed',
                    child: Text('Fixed (SAR)'),
                  ),
                  DropdownMenuItem(
                    value: 'free_delivery',
                    child: Text('Free delivery'),
                  ),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'percentage'),
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 14),

              if (_type != 'free_delivery') ...[
                _FieldLabel(
                  label: _type == 'percentage'
                      ? 'Discount %'
                      : 'Discount Amount (SAR)',
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _discountValueCtrl,
                  keyboardType: _type == 'percentage'
                      ? TextInputType.number
                      : const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: false,
                        ),
                  inputFormatters: _type == 'percentage'
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    hintText: _type == 'percentage' ? 'e.g. 20' : 'e.g. 15',
                  ),
                  validator: (v) {
                    if (_type == 'free_delivery') return null;
                    final t = (v ?? '').trim();
                    if (_type == 'percentage') {
                      final n = int.tryParse(t);
                      if (n == null || n < 1 || n > 100) {
                        return 'Enter a whole number from 1 to 100';
                      }
                      return null;
                    }
                    final d = double.tryParse(t);
                    if (d == null || d <= 0) return 'Enter a valid value';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              _FieldLabel(label: 'Minimum Order (SAR)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _minOrderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '0'),
                validator: (v) {
                  final d = double.tryParse((v ?? '').trim());
                  if (d == null || d < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              _FieldLabel(label: 'Start Date'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _startCtrl,
                onTap: () => _pickDate(_startCtrl),
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              _FieldLabel(label: 'End Date'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _endCtrl,
                onTap: () => _pickDate(_endCtrl),
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: const Text(
                  'Enabled',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 14),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
