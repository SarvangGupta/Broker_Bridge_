import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Communication launcher service providing direct Phone and WhatsApp access.
/// STRICT COUNTERPARTY SHIELD INVARIANT:
/// This service is strictly restricted to authorized Mandi Broker communications.
/// Direct Buyer dialing or messaging is prohibited.
class ContactLauncherService {
  const ContactLauncherService();

  /// Launch system phone dialer for authorized Broker contact.
  Future<bool> launchPhone(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      debugPrint('Cannot launch phone: phone number is null or empty');
      return false;
    }

    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        debugPrint('Could not launch dialer for: $cleanNumber');
        return false;
      }
    } catch (e) {
      debugPrint('Error launching phone dialer: $e');
      return false;
    }
  }

  /// Launch WhatsApp chat for authorized Broker contact.
  Future<bool> launchWhatsApp(
    String? phoneNumber, {
    String? defaultMessage,
  }) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      debugPrint('Cannot launch WhatsApp: phone number is null or empty');
      return false;
    }

    var cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    final message =
        defaultMessage ??
        'Hello, I am reaching out regarding a commodity supply lot on the RMSeller Portal.';
    final encodedMessage = Uri.encodeComponent(message);

    final urlString = 'https://wa.me/$cleanNumber?text=$encodedMessage';
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch WhatsApp for: $cleanNumber');
        return false;
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      return false;
    }
  }
}
