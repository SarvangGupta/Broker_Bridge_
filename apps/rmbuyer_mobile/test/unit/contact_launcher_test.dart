import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/core/services/contact_launcher_service.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('RB-BUYER-02: ContactLauncherService Tests', () {
    test('launchCall parses tel: URI cleanly with digits and plus symbol', () async {
      Uri? capturedUri;

      final launcher = ContactLauncherService(
        launchUrlFn: (uri, {mode = LaunchMode.platformDefault}) async {
          capturedUri = uri;
          return true;
        },
      );

      final success = await launcher.launchCall('+91 (982) 901-2345');

      expect(success, isTrue);
      expect(capturedUri, isNotNull);
      expect(capturedUri.toString(), 'tel:+919829012345');
    });

    test('launchCall returns false on empty or invalid phone numbers', () async {
      final launcher = ContactLauncherService(
        launchUrlFn: (uri, {mode = LaunchMode.platformDefault}) async => true,
      );

      expect(await launcher.launchCall(''), isFalse);
      expect(await launcher.launchCall('    '), isFalse);
      expect(await launcher.launchCall('abc-def'), isFalse);
    });

    test('launchWhatsApp formats https://wa.me/ URI with country code and message', () async {
      Uri? capturedUri;
      LaunchMode? capturedMode;

      final launcher = ContactLauncherService(
        launchUrlFn: (uri, {mode = LaunchMode.platformDefault}) async {
          capturedUri = uri;
          capturedMode = mode;
          return true;
        },
      );

      // 10-digit phone should automatically prepend 91 country code
      final success = await launcher.launchWhatsApp(
        '9829012345',
        prefilledMessage: 'Inquiry regarding Soybean 500 MT',
      );

      expect(success, isTrue);
      expect(capturedUri, isNotNull);
      expect(capturedUri!.scheme, 'https');
      expect(capturedUri!.host, 'wa.me');
      expect(capturedUri!.path, '/919829012345');
      expect(capturedUri!.queryParameters['text'], 'Inquiry regarding Soybean 500 MT');
      expect(capturedMode, LaunchMode.externalApplication);
    });

    test('launchWhatsApp returns false on empty phone numbers', () async {
      final launcher = ContactLauncherService(
        launchUrlFn: (uri, {mode = LaunchMode.platformDefault}) async => true,
      );

      expect(await launcher.launchWhatsApp(''), isFalse);
      expect(await launcher.launchWhatsApp('---'), isFalse);
    });

    test('Captures exceptions gracefully and returns false without crashing', () async {
      final launcher = ContactLauncherService(
        launchUrlFn: (uri, {mode = LaunchMode.platformDefault}) async {
          throw Exception('Platform channel unavailable on test runner');
        },
      );

      final callResult = await launcher.launchCall('+919829012345');
      final waResult = await launcher.launchWhatsApp('9829012345');

      expect(callResult, isFalse);
      expect(waResult, isFalse);
    });
  });
}
