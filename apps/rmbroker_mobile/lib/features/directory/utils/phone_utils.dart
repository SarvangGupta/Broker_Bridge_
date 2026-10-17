import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result container for phone validation.
class PhoneValidationResult {
  final bool isValid;
  final String normalized; // E.164-like e.g. +919876543210
  final String formatted; // e.g. +91 98765 43210
  final String rawDigits; // 10 digits e.g. 9876543210
  final String? error;

  const PhoneValidationResult({
    required this.isValid,
    required this.normalized,
    required this.formatted,
    required this.rawDigits,
    this.error,
  });

  factory PhoneValidationResult.invalid(String error, [String raw = '']) {
    return PhoneValidationResult(
      isValid: false,
      normalized: '',
      formatted: '',
      rawDigits: raw,
      error: error,
    );
  }
}

/// Phone number validation and normalization utilities for RMBroker.
/// Standardizes Indian mobile numbers (+91 standard, 10 digits starting with 6, 7, 8, or 9).
class PhoneUtils {
  const PhoneUtils._();

  /// Validates and normalizes Indian mobile numbers (+91 standard).
  /// Accepts formats:
  /// - 9876543210
  /// - 09876543210
  /// - +91 98765 43210
  /// - 919876543210
  /// - +91-98765-43210
  static PhoneValidationResult validateAndNormalize(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      return PhoneValidationResult.invalid('Mobile number is required');
    }

    // Strip whitespace, hyphens, parentheses, and dots
    final cleaned = rawPhone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '').trim();
    var digits = cleaned;

    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    // Must be exactly 10 digits
    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
      return PhoneValidationResult.invalid(
        'Please enter a valid 10-digit mobile number',
        digits,
      );
    }

    // Indian mobile numbers must start with 6, 7, 8, or 9
    if (!RegExp(r'^[6-9]').hasMatch(digits)) {
      return PhoneValidationResult.invalid(
        'Mobile number must start with 6, 7, 8, or 9',
        digits,
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

  /// Returns safe tel: URI for device dialler.
  static String? getSafeTelUri(String? phone) {
    final res = validateAndNormalize(phone);
    if (!res.isValid) return null;
    return 'tel:${res.normalized}';
  }

  /// Returns safe wa.me URL for WhatsApp conversation.
  static String? getSafeWhatsAppUri(String? phone, {String? initialMessage}) {
    final res = validateAndNormalize(phone);
    if (!res.isValid) return null;
    final base = 'https://wa.me/91${res.rawDigits}';
    if (initialMessage != null && initialMessage.trim().isNotEmpty) {
      return '$base?text=${Uri.encodeComponent(initialMessage.trim())}';
    }
    return base;
  }

  /// Launches phone dialler with user-initiated action and error callback.
  static Future<bool> launchDialler(
    BuildContext context,
    String? phone, {
    void Function(String error)? onError,
  }) async {
    final uriString = getSafeTelUri(phone);
    if (uriString == null) {
      final msg = 'Invalid contact number. Cannot open dialler.';
      onError?.call(msg);
      _showToast(context, msg, isError: true);
      return false;
    }

    final uri = Uri.parse(uriString);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        final msg = 'Unable to launch phone dialler on this device.';
        onError?.call(msg);
        if (context.mounted) _showToast(context, msg, isError: true);
        return false;
      }
      return true;
    } catch (e) {
      final msg = 'Device failed to open dialler: $e';
      onError?.call(msg);
      if (context.mounted) _showToast(context, msg, isError: true);
      return false;
    }
  }

  /// Alias for launchDialler for developer ergonomics.
  static Future<bool> launchCall(
    BuildContext context,
    String? phone, {
    void Function(String error)? onError,
  }) => launchDialler(context, phone, onError: onError);

  /// Launches WhatsApp with verified number and error fallback.
  /// Note: Never claims a message was delivered or read. Deal negotiations remain broker-mediated.
  static Future<bool> launchWhatsApp(
    BuildContext context,
    String? phone, {
    String? initialMessage,
    void Function(String error)? onError,
  }) async {
    final uriString = getSafeWhatsAppUri(phone, initialMessage: initialMessage);
    if (uriString == null) {
      final msg = 'Invalid contact number. Cannot open WhatsApp.';
      onError?.call(msg);
      _showToast(context, msg, isError: true);
      return false;
    }

    final uri = Uri.parse(uriString);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        final msg = 'WhatsApp is not installed or could not be opened.';
        onError?.call(msg);
        if (context.mounted) _showToast(context, msg, isError: true);
        return false;
      }
      return true;
    } catch (e) {
      final msg = 'Could not open WhatsApp: $e';
      onError?.call(msg);
      if (context.mounted) _showToast(context, msg, isError: true);
      return false;
    }
  }

  static void _showToast(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.teal.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
