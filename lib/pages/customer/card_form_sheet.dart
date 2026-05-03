import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  String? _validateNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 16) {
      return 'Enter a 16-digit card number';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    final v = (value ?? '').trim();
    final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(v);
    if (match == null) return 'Format MM/YY';

    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final endOfMonth = DateTime(year, month + 1, 0);

    if (endOfMonth.isBefore(DateTime.now())) return 'Card expired';
    return null;
  }

  String? _validateCvv(String? value) {
    final v = (value ?? '').trim();
    if (!RegExp(r'^\d{3}$').hasMatch(v)) return '3 digits';
    return null;
  }

  String? _validateHolder(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
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

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Card',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              inputFormatters: [_CardNumberFormatter()],
              decoration: const InputDecoration(
                labelText: 'Card Number',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
              ),
              validator: _validateNumber,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ExpiryFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Expiry MM/YY',
                      hintText: 'MM/YY',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateExpiry,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateCvv,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _holderController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Holder Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: _validateHolder,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Save Card'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 16 ? digits.substring(0, 16) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(capped[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 1 && int.parse(digits) >= 2) {
      digits = '0$digits';
    }

    final capped = digits.length > 4 ? digits.substring(0, 4) : digits;

    final formatted = capped.length >= 3
        ? '${capped.substring(0, 2)}/${capped.substring(2)}'
        : capped;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
