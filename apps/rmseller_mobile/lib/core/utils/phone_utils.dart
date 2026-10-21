/// Phone Number Validation and Normalization Utilities for RMBroker Seller App.
/// Standardizes Indian mobile numbers (+91 standard, 10 digits starting with 6–9).
class PhoneValidationResult {
  final bool isValid;
  final String normalized; // E.164 standard, e.g. +919876543210
  final String formatted; // Display standard, e.g. +91 98765 43210
  final String rawDigits; // 10-digit raw mobile, e.g. 9876543210
  final String? error;

  const PhoneValidationResult({
    required this.isValid,
    required this.normalized,
    required this.formatted,
    required this.rawDigits,
    this.error,
  });
}

class PhoneUtils {
  /// Validates and normalizes Indian mobile numbers (+91 standard).
  /// Accepts formats:
  /// - 9876543210
  /// - 09876543210
  /// - +91 98765 43210
  /// - 919876543210
  /// - +91-98765-43210
  static PhoneValidationResult validateAndNormalize(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      return const PhoneValidationResult(
        isValid: false,
        normalized: '',
        formatted: '',
        rawDigits: '',
        error: 'Phone number is required',
      );
    }

    // Strip all whitespace, hyphens, parentheses, and dots
    final cleaned = rawPhone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '').trim();
    String digits = cleaned;

    // Handle leading +91, 91 (12 digits), or leading 0 (11 digits)
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    // Check if exactly 10 digits
    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
      return PhoneValidationResult(
        isValid: false,
        normalized: '',
        formatted: '',
        rawDigits: digits,
        error: 'Please enter a valid 10-digit mobile number',
      );
    }

    // Indian mobile numbers must start with 6, 7, 8, or 9
    if (!RegExp(r'^[6-9]').hasMatch(digits)) {
      return PhoneValidationResult(
        isValid: false,
        normalized: '',
        formatted: '',
        rawDigits: digits,
        error: 'Mobile number must start with 6, 7, 8, or 9',
      );
    }

    final normalized = '+91$digits';
    final formatted = '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';

    return PhoneValidationResult(
      isValid: true,
      normalized: normalized,
      formatted: formatted,
      rawDigits: digits,
    );
  }

  /// Returns normalized +919876543210 string or null if invalid
  static String? getNormalized(String? rawPhone) {
    final res = validateAndNormalize(rawPhone);
    return res.isValid ? res.normalized : null;
  }

  /// Returns formatted +91 98765 43210 string
  static String? getFormatted(String? rawPhone) {
    final res = validateAndNormalize(rawPhone);
    return res.isValid ? res.formatted : rawPhone;
  }
}
