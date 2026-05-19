import 'package:flutter/material.dart';
import 'package:yjeek/pages/customer/card_form_fields.dart';

class CardInput {
  const CardInput({
    required this.number,
    required this.expiry,
    required this.holderName,
  });

  final String number;
  final String expiry;
  final String holderName;
}

class CardFormSheet extends StatefulWidget {
  const CardFormSheet({super.key});

  @override
  State<CardFormSheet> createState() => _CardFormSheetState();
}

class _CardFormSheetState extends State<CardFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _holderController = TextEditingController();

  @override
  void dispose() {
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CardInput(
        number: _numberController.text.trim(),
        expiry: _expiryController.text.trim(),
        holderName: _holderController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add Card',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CardFormFields(
                numberController: _numberController,
                expiryController: _expiryController,
                cvvController: _cvvController,
                holderController: _holderController,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text(
                    'Save Card',
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
      ),
    );
  }
}
