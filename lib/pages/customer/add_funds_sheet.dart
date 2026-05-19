import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/saved_card.dart';
import 'package:yjeek/pages/customer/card_form_fields.dart';

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
          left: 20,
          right: 20,
          top: 4,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: StreamBuilder<List<SavedCard>>(
          stream: DatabaseService().streamCustomerCards(widget.customerId),
          builder: (context, snap) {
            final cards = snap.data ?? const <SavedCard>[];
            final savedCard = cards.isEmpty ? null : cards.first;
            final hasSaved = savedCard != null;

            final useNewCard = !hasSaved || _choice == _CardChoice.newCard;

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Amount',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: _validateAmount,
                    ),

                    if (hasSaved) ...[
                      const SizedBox(height: 22),
                      _SectionLabel('PAY WITH'),
                      const SizedBox(height: 10),
                      _CardChoiceTile(
                        title: 'Card ••••  ${savedCard.last4}',
                        subtitle: savedCard.holderName,
                        icon: Icons.credit_card_rounded,
                        isSelected: _choice == _CardChoice.saved,
                        onTap: () =>
                            setState(() => _choice = _CardChoice.saved),
                      ),
                      const SizedBox(height: 10),
                      _CardChoiceTile(
                        title: 'Use another card',
                        subtitle: "Won't be saved to your account",
                        icon: Icons.add_card,
                        isSelected: _choice == _CardChoice.newCard,
                        onTap: () =>
                            setState(() => _choice = _CardChoice.newCard),
                      ),
                    ],

                    if (useNewCard) ...[
                      const SizedBox(height: 22),
                      if (hasSaved) ...[
                        _SectionLabel('CARD DETAILS'),
                        const SizedBox(height: 12),
                      ],
                      CardFormFields(
                        numberController: _numberController,
                        expiryController: _expiryController,
                        cvvController: _cvvController,
                        holderController: _holderController,
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: () => _confirm(useNewCard: useNewCard),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
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
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
          color: isSelected
              ? scheme.primaryContainer.withValues(alpha: 0.18)
              : scheme.surfaceContainerLowest,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? scheme.primary : scheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
