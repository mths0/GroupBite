class Validators {
  //! data must be trimmed before valid
  static String? validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Name is required';
    }
    // only letters
    final nameRegex = RegExp(r'^[A-Za-z\s]+$');
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Name must contain letters only';
    }

    var splitName = value.split(RegExp(r'\s+'));
    if (splitName.length < 2) {
      return "Enter full name";
    }
    return null;
  }

  static String? validatePhone(String value) {
    if (value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^5\d{8}$').hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? validateNationalId(String value) {
    if (value.isEmpty) {
      return "National ID is required";
    }
    if (value.length != 10) {
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
}
