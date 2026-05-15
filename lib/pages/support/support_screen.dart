import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/order.dart';
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
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support request submitted! We\'ll be in touch.'),
          backgroundColor: Colors.green,
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select Order',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final dateStr = DateFormat(
                        'MMM dd, yyyy • HH:mm',
                      ).format(order.createdAt);
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.orange,
                          ),
                        ),
                        title: Text(
                          'Order #${order.id.substring(0, 8).toUpperCase()}',
                        ),
                        subtitle: Text(
                          '$dateStr\n\$${order.totalPrice.toStringAsFixed(2)} • ${order.status.name.toUpperCase()}',
                        ),
                        isThreeLine: true,
                        onTap: () {
                          setState(() => _selectedOrder = order);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOrderProblem = _selectedType == 'order_problem';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            const Icon(
              Icons.contact_support_rounded,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              "How can we help?",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            // Issue Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Issue Category',
                prefixIcon: Icon(
                  _issueTypes[_selectedType]?['icon'] ?? Icons.help_outline,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.cardColor,
              ),
              items: _issueTypes.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value['label']),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedType = val;
                    _selectedOrder = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Order Selection (Contextual)
            if (isOrderProblem) ...[
              InkWell(
                onTap: _showOrderPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.cardColor,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedOrder == null
                              ? "Tap to select an order"
                              : "Order #${_selectedOrder!.id.substring(0, 8).toUpperCase()} - \$${_selectedOrder!.totalPrice}",
                          style: TextStyle(
                            color: _selectedOrder == null
                                ? Colors.grey
                                : theme.colorScheme.onSurface,
                            fontWeight: _selectedOrder == null
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Subject Field
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Subject',
                hintText: 'Brief summary',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.cardColor,
              ),
              validator: (v) =>
                  v?.trim().isEmpty ?? true ? 'Please enter a subject' : null,
            ),
            const SizedBox(height: 16),

            // Details Field
            TextFormField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Details',
                hintText: 'Describe your issue...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.cardColor,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Message is required';
                if (v.trim().length < 10) return 'Please provide more detail';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
