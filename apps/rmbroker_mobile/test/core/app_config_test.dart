import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/config/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('AppConfig has correct branding constants', () {
      expect(AppConfig.appName, equals('RMBroker'));
      expect(AppConfig.appVersion, isNotEmpty);
      expect(AppConfig.appTagline, contains('Broker Desk'));
    });

    test('AppConfig has non-empty Supabase configuration', () {
      expect(AppConfig.supabaseUrl, startsWith('https://'));
      expect(AppConfig.supabaseAnonKey, isNotEmpty);
    });

    test('AppConfig has sensible network timeouts', () {
      expect(AppConfig.connectTimeout.inSeconds, equals(15));
      expect(AppConfig.receiveTimeout.inSeconds, equals(15));
    });

    test(
      'AppConfig has mandatory broker fiduciary disclaimer in English & Hindi',
      () {
        expect(
          AppConfig.fiduciaryNoticeEn,
          contains('does not own or store physical commodity inventory'),
        );
        expect(AppConfig.fiduciaryNoticeHi, contains('भौतिक माल का स्वामित्व'));
      },
    );
  });
}
