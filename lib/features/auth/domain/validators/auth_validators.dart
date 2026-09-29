class PhoneValidator {
  static String? validateNational(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 'Phone number is required.';
    }
    if (digits.length != 10) {
      return 'Enter a 10-digit mobile number.';
    }
    return null;
  }

  static String toE164(String dialCode, String nationalNumber) {
    final digits = nationalNumber.replaceAll(RegExp(r'\D'), '');
    return '$dialCode$digits';
  }
}

class EmailValidator {
  static final _pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? validate(String value) {
    final email = value.trim();
    if (email.isEmpty) {
      return 'Email is required.';
    }
    if (!_pattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class PasswordValidator {
  static String? validate(String value) {
    if (value.length < 10) {
      return 'Password must be at least 10 characters.';
    }
    return null;
  }
}

class DisplayNameValidator {
  static String? validate(String value) {
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters.';
    }
    return null;
  }
}

class OtpValidator {
  static String? validate(String value) {
    final otp = value.trim();
    if (otp.length < 6) {
      return 'Enter the 6-digit code.';
    }
    return null;
  }
}
