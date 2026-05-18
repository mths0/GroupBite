import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yjeek/utils/validators.dart';

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
        _Label('Card Number'),
        const SizedBox(height: 8),
        TextFormField(
          controller: numberController,
          keyboardType: TextInputType.number,
          inputFormatters: [CardNumberFormatter()],
          decoration: const InputDecoration(
            hintText: '0000 0000 0000 0000',
            prefixIcon: Icon(Icons.credit_card),
          ),
          validator: Validators.validateCardNumber,
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Label('Expiry Date'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ExpiryFormatter()],
                    decoration: const InputDecoration(
                      hintText: 'MM/YY',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    validator: Validators.validateExpiry,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Label('CVV'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      hintText: '123',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: Validators.validateCardCvv,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Label('Cardholder Name'),
        const SizedBox(height: 8),
        TextFormField(
          controller: holderController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Name on card',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: Validators.validateCardHolder,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
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
