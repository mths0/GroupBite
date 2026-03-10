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

    });

    group('validateOTP', () {

      test('returns error if empty', () {
        final result = Validators.validateOTP('');
        expect(result, 'OTP is required');
      });

      test('returns error if not 6 digits', () {
        final result = Validators.validateOTP('123');
        expect(result, 'OTP must be 6 digits');
      });

      test('returns error if OTP is wrong', () {
        final result = Validators.validateOTP('654321');
        expect(result, 'Invalid OTP');
      });

      test('returns null for correct OTP', () {
        final result = Validators.validateOTP('123456');
        expect(result, null);
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

  });
}