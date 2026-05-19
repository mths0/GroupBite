class Validators {
  static RegExp regExpLettersOnly = RegExp(r'^[A-Za-z\s]+$');
  static RegExp regExpRestaurantName = RegExp(r'^[A-Za-z\s&]+$');
  static RegExp regExpNumbersOnly = RegExp(r'^\d+$');
  static RegExp regExpSpecialChars = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  static String? validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Name is required';
    }
    // only letters
    final nameRegex = regExpLettersOnly;
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Name must contain letters only';
    }

    final splitName = trimmed.split(RegExp(r'\s+'));
    if (splitName.length < 2) {
      return "Enter full name";
    }
    return null;
  }

  static String? validateRestaurantName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Restaurant name is required';
    }
    if (!regExpRestaurantName.hasMatch(trimmed)) {
      return 'Restaurant name can only contain letters, spaces, and &';
    }
    return null;
  }

  static String? validatePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Phone number is required';
    }
    if (!regExpNumbersOnly.hasMatch(trimmed)) {
      return 'Phone number must contain digits only';
    }
    if (trimmed.length != 9) {
      return 'Phone number must be 9 digits';
    }
    if (!trimmed.startsWith('5')) {
      return 'Phone number must start with 5';
    }
    return null;
  }

  static String? validateNationalId(String value) {
    String trimmed = value.trim();

    if (trimmed.isEmpty) {
      return "National ID is required";
    }
    if (!regExpNumbersOnly.hasMatch(trimmed)) {
      return 'National ID must contain digits only';
    }
    if (trimmed.length != 10) {
      return 'National ID must be 10 digits';
    }
    return null;
  }

  static String? validateOTP(String value) {
    if (value.isEmpty) {
      return "OTP is required";
    }
    if (value.length != 6) {
      return "OTP must be 6 digits";
    }
    //! Mock OTP check
    // later change to firebase
    if (value != '123456') {
      return 'Invalid OTP';
    }
    return null;
  }

  static String? validateEmail(String v) {
    final value = v.trim();
    if (value.isEmpty) return "Email is required";
    final emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
    if (!emailRegex.hasMatch(value)) return "Enter a valid email";
    return null;
  }

  static String? validateExpiry(String? value) {
    final v = (value ?? '').trim();

    final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(v);
    if (match == null) return 'Format MM/YY';

    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);

    final now = DateTime.now();
    final endOfMonth = DateTime(year, month + 1, 0);

    if (endOfMonth.isBefore(DateTime(now.year, now.month, 1))) {
      return 'Card expired';
    }

    final maxAllowedYear = now.year + 15;

    if (year > maxAllowedYear) {
      return 'Invalid expiry year';
    }

    return null;
  }

  static String? validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 16) {
      return 'Enter a 16-digit card number';
    }
    return null;
  }

  static String? validateCardCvv(String? value) {
    final v = (value ?? '').trim();
    if (!RegExp(r'^\d{3}$').hasMatch(v)) return '3 digits';
    return null;
  }

  static String? validateCardHolder(String? value) {
    final v = (value ?? '').trim();

    if (v.isEmpty) {
      return 'Holder name is required';
    }

    final nameRegex = RegExp(r'^[A-Za-z\s]+$');
    if (!nameRegex.hasMatch(v)) {
      return 'Holder name must contain letters only';
    }

    final parts = v.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return 'Enter full holder name';
    }

    return null;
  }
}
