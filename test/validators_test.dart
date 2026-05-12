import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery_platform/utils/validators.dart';

void main() {
  group('Validators', () {
    group('validateName', () {
      test('returns error if name is empty', () {
        final result = Validators.validateName('');
        expect(result, 'Name is required');
      });

      test('returns error if name contains numbers', () {
        final result = Validators.validateName('John123 Doe');
        expect(result, 'Name must contain letters only');
      });

      test('returns error if only one name provided', () {
        final result = Validators.validateName('John');
        expect(result, 'Enter full name');
      });

      test('returns null for valid full name', () {
        final result = Validators.validateName('  John Doe  ');
        expect(result, null);
      });
    });

    group('validatePhone', () {
      test('returns error if phone is empty', () {
        final result = Validators.validatePhone('');
        expect(result, 'Phone number is required');
      });

      test('returns error for invalid phone format', () {
        final result = Validators.validatePhone('123456789');
        expect(result, 'Enter a valid phone number');
      });

      test('returns null for valid phone', () {
        final result = Validators.validatePhone('512345878');
        expect(result, null);
      });
    });

    group('validateNationalId', () {
      test('returns error if empty', () {
        final result = Validators.validateNationalId('');
        expect(result, 'National ID is required');
      });

      test('returns error if not 10 digits', () {
        final result = Validators.validateNationalId('12345');
        expect(result, 'National ID must be 10 digits');
      });

      test('returns null if valid', () {
        final result = Validators.validateNationalId('1234567890');
        expect(result, null);
      });

      test('returns null if valid with spaces', () {
        final result = Validators.validateNationalId('  1234567890  ');
        expect(result, null);
      });

      test('returns error if contains non-digit characters', () {
        final result = Validators.validateNationalId('12345abcde');
        expect(result, 'National ID must contain digits only');
      });
    });

    group('validateEmail', () {
      test('returns error if empty', () {
        final result = Validators.validateEmail('');
        expect(result, 'Email is required');
      });

      test('returns error if invalid email', () {
        final result = Validators.validateEmail('invalid-email');
        expect(result, 'Enter a valid email');
      });

      test('returns null if email valid', () {
        final result = Validators.validateEmail('user@test.com');
        expect(result, null);
      });
    });
    group('validateExpiry', () {
      test('returns format error for null', () {
        expect(Validators.validateExpiry(null), 'Format MM/YY');
      });

      test('returns format error for empty string', () {
        expect(Validators.validateExpiry(''), 'Format MM/YY');
      });

      test('returns format error for invalid month', () {
        expect(Validators.validateExpiry('13/25'), 'Format MM/YY');

        expect(Validators.validateExpiry('00/25'), 'Format MM/YY');
      });

      test('returns format error for invalid shape', () {
        expect(Validators.validateExpiry('1/25'), 'Format MM/YY');

        expect(Validators.validateExpiry('01/2025'), 'Format MM/YY');

        expect(Validators.validateExpiry('ab/cd'), 'Format MM/YY');
      });

      test('returns card expired for past month', () {
        final now = DateTime.now();

        final past = DateTime(now.year, now.month - 1, 1);

        final value =
            '${past.month.toString().padLeft(2, '0')}/${(past.year % 100).toString().padLeft(2, '0')}';

        expect(Validators.validateExpiry(value), 'Card expired');
      });

      test('returns invalid expiry year for too-far future year', () {
        final now = DateTime.now();

        final tooFarYear = now.year + 16;

        final value = '12/${(tooFarYear % 100).toString().padLeft(2, '0')}';

        expect(Validators.validateExpiry(value), 'Invalid expiry year');
      });

      test('returns null for current month', () {
        final now = DateTime.now();

        final value =
            '${now.month.toString().padLeft(2, '0')}/${(now.year % 100).toString().padLeft(2, '0')}';

        expect(Validators.validateExpiry(value), null);
      });

      test('returns null for valid future date within allowed range', () {
        final now = DateTime.now();

        final future = DateTime(now.year + 1, 6, 1);

        final value =
            '${future.month.toString().padLeft(2, '0')}/${(future.year % 100).toString().padLeft(2, '0')}';

        expect(Validators.validateExpiry(value), null);
      });
    });

    group('validateCardNumber', () {
      test('returns error for null', () {
        expect(
          Validators.validateCardNumber(null),

          'Enter a 16-digit card number',
        );
      });

      test('returns error for empty value', () {
        expect(
          Validators.validateCardNumber(''),

          'Enter a 16-digit card number',
        );
      });

      test('returns error for less than 16 digits', () {
        expect(
          Validators.validateCardNumber('123456789012345'),

          'Enter a 16-digit card number',
        );
      });

      test('returns error for more than 16 digits', () {
        expect(
          Validators.validateCardNumber('12345678901234567'),

          'Enter a 16-digit card number',
        );
      });

      test('accepts 16 digits only', () {
        expect(
          Validators.validateCardNumber('1234567890123456'),

          null,
        );
      });

      test('accepts formatted card number with spaces or dashes', () {
        expect(
          Validators.validateCardNumber('1234 5678 9012 3456'),

          null,
        );

        expect(
          Validators.validateCardNumber('1234-5678-9012-3456'),

          null,
        );
      });
    });

    group('validateCardCvv', () {
      test('returns error for null', () {
        expect(Validators.validateCardCvv(null), '3 digits');
      });

      test('returns error for empty value', () {
        expect(Validators.validateCardCvv(''), '3 digits');
      });

      test('returns error for less than 3 digits', () {
        expect(Validators.validateCardCvv('12'), '3 digits');
      });

      test('returns error for more than 3 digits', () {
        expect(Validators.validateCardCvv('1234'), '3 digits');
      });

      test('returns error for non-numeric value', () {
        expect(Validators.validateCardCvv('12a'), '3 digits');
      });

      test('accepts valid 3-digit cvv', () {
        expect(Validators.validateCardCvv('123'), null);
      });

      test('accepts valid 3-digit cvv with surrounding spaces', () {
        expect(Validators.validateCardCvv(' 123 '), null);
      });
    });

    group('validateCardHolder', () {
      test('returns error for null', () {
        expect(
          Validators.validateCardHolder(null),

          'Holder name is required',
        );
      });

      test('returns error for empty value', () {
        expect(
          Validators.validateCardHolder(''),

          'Holder name is required',
        );
      });

      test('returns error for spaces only', () {
        expect(
          Validators.validateCardHolder('   '),

          'Holder name is required',
        );
      });

      test('returns error when name contains numbers', () {
        expect(
          Validators.validateCardHolder('Mohaned 123'),

          'Holder name must contain letters only',
        );
      });

      test('returns error when name contains symbols', () {
        expect(
          Validators.validateCardHolder('Mohaned! Ali'),

          'Holder name must contain letters only',
        );
      });

      test('returns error for one word only', () {
        expect(
          Validators.validateCardHolder('Mohaned'),

          'Enter full holder name',
        );
      });

      test('accepts valid full holder name', () {
        expect(
          Validators.validateCardHolder('Mohaned Alshahrani'),

          null,
        );
      });

      test('accepts valid full holder name with extra spaces', () {
        expect(
          Validators.validateCardHolder('  Mohaned   Alshahrani  '),

          null,
        );
      });
    });
  });
}
