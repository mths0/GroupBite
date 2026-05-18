import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:food_delivery_platform/widgets/confirm_dialog.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key, required this.restaurantId});
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Promotions"),
      ),
      body: StreamBuilder<firestore.QuerySnapshot<Map<String, dynamic>>>(
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
            return const Center(child: Text("No promotions yet"));
          }

          final promos = docs.map((d) {
            final data = d.data();
            return {
              ...data,
              "id": d.id,
            };
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: promos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final p = promos[i];
              final status = _calcStatus(p);

              return _PromotionCard(
                primary: primary,
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
        },
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () => _openAddEdit(),
              child: const Text(
                "Create Promotion",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({
    required this.primary,
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

  final Color primary;

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

  Color get _badgeColor {
    switch (status) {
      case "active":
        return const Color(0xFF33C26B);
      case "scheduled":
        return primary;
      case "expired":
        return const Color(0xFFFF3B30);
      case "disabled":
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String get _badgeText {
    switch (status) {
      case "active":
        return "Active";
      case "scheduled":
        return "Scheduled";
      case "expired":
        return "Expired";
      case "disabled":
        return "Disabled";
      default:
        return status;
    }
  }

  String get _discountLine {
    if (discountType == "free_delivery") return "0 SAR off (Free delivery)";
    if (discountType == "fixed") return "${discountValue.toString()} SAR off";
    return "${discountValue.toString()}% off";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // title + badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _badgeText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.percent, size: 16),
                const SizedBox(width: 8),
                Text(
                  _discountLine,
                ),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$startAt - $endAt",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Divider(height: 22),

            Row(
              children: [
                Expanded(
                  child: Text(
                    "Min. order: ${minOrder.toString()} SAR",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (code.trim().isNotEmpty)
                  Text(
                    code,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        "Enabled",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Switch(value: enabled, onChanged: onToggleEnabled),
                    ],
                  ),
                ),
                _circleAction(
                  icon: Icons.edit,
                  bg: const Color(0xFFE8F1FF),
                  fg: primary,
                  onTap: onEdit,
                ),
                const SizedBox(width: 10),
                _circleAction(
                  icon: Icons.delete,
                  bg: const Color(0xFFFFE9E9),
                  fg: const Color(0xFFFF3B30),
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleAction({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 18),
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

    _titleCtrl = TextEditingController(text: (e?['title'] ?? '').toString());
    _codeCtrl = TextEditingController(text: (e?['code'] ?? '').toString());
    _discountValueCtrl = TextEditingController(
      text: (e?['discountValue'] ?? '').toString(),
    );
    _minOrderCtrl = TextEditingController(
      text: (e?['minOrder'] ?? '').toString(),
    );
    _startCtrl = TextEditingController(text: (e?['startAt'] ?? '').toString());
    _endCtrl = TextEditingController(text: (e?['endAt'] ?? '').toString());

    final rawType = (e?['discountType'] ?? 'percentage').toString();
    const allowedTypes = {'percentage', 'fixed', 'free_delivery'};
    _type = allowedTypes.contains(rawType) ? rawType : 'percentage';

    _enabled = (e?['enabled'] ?? true) == true;
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

    final discountValue = double.tryParse(_discountValueCtrl.text.trim()) ?? 0;
    final minOrder = double.tryParse(_minOrderCtrl.text.trim()) ?? 0;

    Navigator.pop<Map<String, dynamic>>(context, {
      "title": _titleCtrl.text.trim(),
      "code": _codeCtrl.text.trim().toUpperCase(),
      "discountType": _type,
      "discountValue": _type == "free_delivery" ? 0 : discountValue,
      "minOrder": minOrder,
      "startAt": _startCtrl.text.trim(),
      "endAt": _endCtrl.text.trim(),
      "enabled": _enabled,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.existing == null ? "Create Promotion" : "Edit Promotion",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: "Title"),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: "Coupon Code",
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(
                    value: "percentage",
                    child: Text("Percent (%)"),
                  ),
                  DropdownMenuItem(value: "fixed", child: Text("Fixed (SAR)")),
                  DropdownMenuItem(
                    value: "free_delivery",
                    child: Text("Free delivery"),
                  ),
                ],
                onChanged: (v) => setState(() => _type = v ?? "percentage"),
                decoration: const InputDecoration(labelText: "Discount type"),
              ),
              const SizedBox(height: 10),

              if (_type != "free_delivery")
                TextFormField(
                  controller: _discountValueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _type == "percentage"
                        ? "Discount % (e.g. 20)"
                        : "Discount SAR (e.g. 15)",
                  ),
                  validator: (v) {
                    if (_type == "free_delivery") return null;
                    final t = (v ?? "").trim();
                    final d = double.tryParse(t);
                    if (d == null || d <= 0) return "Enter a valid value";
                    return null;
                  },
                ),
              if (_type != "free_delivery") const SizedBox(height: 10),

              TextFormField(
                controller: _minOrderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Minimum order (SAR)",
                ),
                validator: (v) {
                  final d = double.tryParse((v ?? "").trim());
                  if (d == null || d < 0) return "Enter a valid number";
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _startCtrl,
                onTap: () => _pickDate(_startCtrl),
                decoration: const InputDecoration(
                  labelText: "Start date ",
                  hintText: "Select date",
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _endCtrl,
                onTap: () => _pickDate(_endCtrl),
                decoration: const InputDecoration(
                  labelText: "End date ",
                  hintText: "Select date",
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 10),

              SwitchListTile(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: const Text("Enabled"),
              ),

              const SizedBox(height: 10),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Save"),
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
