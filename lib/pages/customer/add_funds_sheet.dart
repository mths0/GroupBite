import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/saved_card.dart';
import 'package:food_delivery_platform/pages/customer/card_form_fields.dart';

/// Bottom sheet that captures the amount to add and which card to "charge".
///
/// The card data for a one-off "use another card" is validated but never
/// stored — only the amount is returned to the caller via Navigator.pop.
/// Caller is responsible for actually crediting the wallet.
class AddFundsSheet extends StatefulWidget {
  const AddFundsSheet({
    super.key,
    required this.customerId,
    this.title = 'Add funds',
  });

  final String customerId;
  final String title;

  @override
  State<AddFundsSheet> createState() => _AddFundsSheetState();
}

enum _CardChoice { saved, newCard }

class _AddFundsSheetState extends State<AddFundsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _holderController = TextEditingController();

  _CardChoice _choice = _CardChoice.saved;

  @override
  void dispose() {
    _amountController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return 'Enter an amount';
    final parsed = double.tryParse(v);
    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
    return null;
  }

  void _confirm({required bool useNewCard}) {
    final form = _formKey.currentState;
    if (form == null) return;

    // The CardFormFields are only mounted when "use new card" is active,
    // so validation only checks them in that branch — Form.validate runs
    // every mounted FormField.
    if (!form.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: StreamBuilder<List<SavedCard>>(
          stream: DatabaseService().streamCustomerCards(widget.customerId),
          builder: (context, snap) {
            final cards = snap.data ?? const <SavedCard>[];
            final savedCard = cards.isEmpty ? null : cards.first;
            final hasSaved = savedCard != null;

            // Force "new" when there's no saved card.
            final useNewCard = !hasSaved || _choice == _CardChoice.newCard;

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.payments_outlined),
                        suffixText: 'SAR',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateAmount,
                    ),

                    if (hasSaved) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Pay with',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _CardChoiceTile(
                        title: '${savedCard.brand}  ••••  ${savedCard.last4}',
                        subtitle: savedCard.holderName,
                        icon: Icons.credit_card_rounded,
                        isSelected: _choice == _CardChoice.saved,
                        onTap: () =>
                            setState(() => _choice = _CardChoice.saved),
                      ),
                      const SizedBox(height: 8),
                      _CardChoiceTile(
                        title: 'Use another card',
                        subtitle: 'Won’t be saved to your account',
                        icon: Icons.add_card,
                        isSelected: _choice == _CardChoice.newCard,
                        onTap: () =>
                            setState(() => _choice = _CardChoice.newCard),
                      ),
                    ],

                    if (useNewCard) ...[
                      const SizedBox(height: 16),
                      if (!hasSaved)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Card details',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                        ),
                      CardFormFields(
                        numberController: _numberController,
                        expiryController: _expiryController,
                        cvvController: _cvvController,
                        holderController: _holderController,
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _confirm(useNewCard: useNewCard),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardChoiceTile extends StatelessWidget {
  const _CardChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 1.8 : 0.8,
          ),
          color: isSelected
              ? scheme.primaryContainer.withOpacity(0.25)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? scheme.primary : scheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: isSelected ? true : null,
              onChanged: (_) => onTap(),
              activeColor: scheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
