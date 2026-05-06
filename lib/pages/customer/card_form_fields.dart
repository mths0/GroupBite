import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/utils/validators.dart';

/// The four card-input fields (number / expiry / CVV / holder name) bundled
/// as a reusable widget. The parent owns the controllers and the form key.
class CardFormFields extends StatelessWidget {
  const CardFormFields({
    super.key,
    required this.numberController,
    required this.expiryController,
    required this.cvvController,
    required this.holderController,
  });

  final TextEditingController numberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final TextEditingController holderController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: numberController,
          keyboardType: TextInputType.number,
          inputFormatters: [CardNumberFormatter()],
          decoration: const InputDecoration(
            labelText: 'Card Number',
            hintText: '1234 5678 9012 3456',
            prefixIcon: Icon(Icons.credit_card),
            border: OutlineInputBorder(),
          ),
          validator: Validators.validateCardNumber,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: expiryController,
                keyboardType: TextInputType.number,
                inputFormatters: [ExpiryFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Expiry MM/YY',
                  hintText: 'MM/YY',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: Validators.validateExpiry,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: cvvController,
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
                validator: Validators.validateCardCvv,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: holderController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Holder Name',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          validator: Validators.validateCardHolder,
        ),
      ],
    );
  }
}

class CardNumberFormatter extends TextInputFormatter {
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

class ExpiryFormatter extends TextInputFormatter {
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
