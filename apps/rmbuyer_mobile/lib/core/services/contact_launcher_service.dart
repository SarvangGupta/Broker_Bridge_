import 'package:url_launcher/url_launcher.dart';

/// Service responsible for launching verified broker contact actions
/// (Direct Phone Call and WhatsApp chat) using system external handlers.
class ContactLauncherService {
  final Future<bool> Function(Uri uri, {LaunchMode mode})? _customLaunchUrl;

  ContactLauncherService({
    Future<bool> Function(Uri uri, {LaunchMode mode})? launchUrlFn,
  }) : _customLaunchUrl = launchUrlFn;

  /// Initiate an authorized telephone call to the broker desk.
  Future<bool> launchCall(String rawPhoneNumber) async {
    try {
      final clean = rawPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (clean.isEmpty) return false;

      final uri = Uri.parse('tel:$clean');
      final customLaunch = _customLaunchUrl;
      if (customLaunch != null) {
        return await customLaunch(uri);
      }

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Open an authorized WhatsApp conversation with the broker desk.
  Future<bool> launchWhatsApp(
    String rawPhoneNumber, {
    String? prefilledMessage,
  }) async {
    try {
      // WhatsApp requires pure numeric digits (with country code, e.g. 919876543210)
      String clean = rawPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (clean.isEmpty) return false;

      // Default to India (+91) if 10 digits provided
      if (clean.length == 10) {
        clean = '91$clean';
      }

      final messageQuery = prefilledMessage != null && prefilledMessage.isNotEmpty
          ? '?text=${Uri.encodeComponent(prefilledMessage)}'
          : '';

      final uri = Uri.parse('https://wa.me/$clean$messageQuery');
      final customLaunch = _customLaunchUrl;
      if (customLaunch != null) {
        return await customLaunch(uri, mode: LaunchMode.externalApplication);
      }

      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
