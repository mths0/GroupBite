import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/pages/support/support_device_info_collector.dart';
import 'package:food_delivery_platform/themes/app_theme.dart';
import 'package:intl/intl.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.userEmail,
  });

  final String userId;
  final String userRole;
  final String userName;
  final String userEmail;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  final DatabaseService _db = DatabaseService();
  final SupportDeviceInfoCollector _deviceInfoCollector =
      SupportDeviceInfoCollector();

  bool _isSending = false;

  String _selectedType = 'bug_report';
  Order? _selectedOrder;

  final Map<String, Map<String, dynamic>> _issueTypes = {
    'bug_report': {'label': 'Bug Report', 'icon': Icons.bug_report_outlined},
    'order_problem': {
      'label': 'Order Problem',
      'icon': Icons.shopping_bag_outlined,
    },
    'payment_problem': {
      'label': 'Payment Problem',
      'icon': Icons.payment_outlined,
    },
    'account_problem': {
      'label': 'Account Problem',
      'icon': Icons.person_outline,
    },
    'other': {'label': 'Other', 'icon': Icons.help_outline},
  };

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Stream<List<Order>> _ordersStream() {
    switch (widget.userRole) {
      case 'customer':
        return _db.getOrdersForCustomer(widget.userId);
      case 'driver':
        return _db.getOrdersForDriver(widget.userId);
      case 'restaurant':
        return _db.getOrdersForRestaurant(widget.userId);
      default:
        return const Stream.empty();
    }
  }

  String _shortOrderId(String id) {
    if (id.length <= 4) return id;
    return id.substring(id.length - 4);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == 'order_problem' && _selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an order related to this issue'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final deviceInfo = await _deviceInfoCollector.collect(context);

      await _db.createSupportTicket(
        userId: widget.userId,
        userRole: widget.userRole,
        userName: widget.userName,
        userEmail: widget.userEmail,
        type: _selectedType,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        orderId: _selectedOrder?.id,
        orderStatus: _selectedOrder?.status.name,
        deviceInfo: deviceInfo,
      );

      if (!mounted) return;
      final brand = Theme.of(context).extension<BrandColors>()!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request submitted!',
            style: TextStyle(color: brand.onSuccess),
          ),
          backgroundColor: brand.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showOrderPicker() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (context) {
        return StreamBuilder<List<Order>>(
          stream: _ordersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text('No orders found')),
              );
            }

            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Order',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 1,
                        color: scheme.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _OrderPickerTile(
                          order: order,
                          shortId: _shortOrderId(order.id),
                          onTap: () {
                            setState(() => _selectedOrder = order);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickIssueCategory() async {
    final scheme = Theme.of(context).colorScheme;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Issue Category',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            for (final entry in _issueTypes.entries)
              ListTile(
                leading: Icon(
                  entry.value['icon'] as IconData,
                  color: _selectedType == entry.key
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                title: Text(
                  entry.value['label'] as String,
                  style: TextStyle(
                    fontWeight: _selectedType == entry.key
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                trailing: _selectedType == entry.key
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _selectedType = selected;
        if (selected != 'order_problem') _selectedOrder = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOrderProblem = _selectedType == 'order_problem';
    final currentType = _issueTypes[_selectedType]!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Support',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.contact_support_rounded,
                        size: 36,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How can we help?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please fill out the form below and our team will get back to you shortly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),

                  _FieldLabel(label: 'Issue Category'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _PillSelector(
                          icon: currentType['icon'] as IconData,
                          label: currentType['label'] as String,
                          trailingIcon: Icons.keyboard_arrow_down,
                          onTap: _pickIssueCategory,
                          bold: true,
                        ),
                      ),
                      if (isOrderProblem) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OrderSelector(
                            order: _selectedOrder,
                            shortId: _selectedOrder == null
                                ? null
                                : _shortOrderId(_selectedOrder!.id),
                            onTap: _showOrderPicker,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  _FieldLabel(label: 'Subject'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      hintText: 'Brief description of the issue',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) => v?.trim().isEmpty ?? true
                        ? 'Please enter a subject'
                        : null,
                  ),
                  const SizedBox(height: 22),

                  _FieldLabel(label: 'Details'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Please provide as much detail as possible...',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Message is required';
                      }
                      if (v.trim().length < 10) {
                        return 'Detail needs 10 characters minimum';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isSending ? null : _submit,
                  child: _isSending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Request',
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
    );
  }
}

class _PillSelector extends StatelessWidget {
  const _PillSelector({
    required this.icon,
    required this.label,
    required this.trailingIcon,
    required this.onTap,
    this.bold = false,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final IconData trailingIcon;
  final VoidCallback onTap;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = muted ? scheme.onSurfaceVariant : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(trailingIcon, size: 18, color: foreground),
          ],
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
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OrderSelector extends StatelessWidget {
  const _OrderSelector({
    required this.order,
    required this.shortId,
    required this.onTap,
  });

  final Order? order;
  final String? shortId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (order == null) {
      return _PillSelector(
        icon: Icons.receipt_long_outlined,
        label: 'select an order',
        trailingIcon: Icons.chevron_right,
        onTap: onTap,
        muted: true,
      );
    }

    return _PillSelector(
      icon: Icons.receipt_long_outlined,
      label: '#order_${shortId ?? ''}',
      trailingIcon: Icons.keyboard_arrow_down,
      onTap: onTap,
      bold: true,
    );
  }
}

class _OrderPickerTile extends StatelessWidget {
  const _OrderPickerTile({
    required this.order,
    required this.shortId,
    required this.onTap,
  });

  final Order order;
  final String shortId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: _OrderTile(order: order, shortId: shortId),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.shortId});

  final Order order;
  final String shortId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMM dd, yyyy').format(order.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: scheme.onSecondaryContainer,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#order_$shortId',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$dateStr  ·  ${order.status.name.toUpperCase()}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${order.totalPrice.toStringAsFixed(2)} SAR',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
