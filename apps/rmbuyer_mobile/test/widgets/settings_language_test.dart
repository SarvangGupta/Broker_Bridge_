import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/app.dart';
import 'package:rmbuyer_mobile/app/router/app_router.dart';
import 'package:rmbuyer_mobile/core/preferences/app_settings_provider.dart';
import 'package:rmbuyer_mobile/core/security/secure_storage_service.dart';

/// Mounts the real app (router, settings provider, localization delegates).
Future<void> _mountApp(WidgetTester tester, String location) async {
  await tester.pumpWidget(const ProviderScope(child: RMBuyerApp()));
  await tester.pump();
  AppRouter.router.go(location);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    final storage = SecureStorageService()..enableMemoryFallbackForTesting();
    await storage.clearAll();
    AppRouter.authNotifier.setStatus(AuthStatus.authenticated);
  });
  tearDown(() => AppRouter.resetForTesting());

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  testWidgets(
    'top-right profile icon opens Profile & Settings; back returns home',
    (tester) async {
      phone(tester);
      await _mountApp(tester, '/home');

      await tester.tap(find.byKey(const Key('home-profile-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.byKey(const Key('settings-edit-profile')), findsOneWidget);
      expect(find.byKey(const Key('settings-language')), findsOneWidget);
      expect(find.byKey(const Key('settings-display')), findsOneWidget);
      expect(find.byKey(const Key('settings-sign-out')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-profile-settings')), findsOneWidget);
    },
  );

  testWidgets('menu items open Edit Profile, Language and Display', (
    tester,
  ) async {
    phone(tester);
    await _mountApp(tester, '/settings');

    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    expect(find.text('Choose the app language'), findsOneWidget);
    for (final lang in AppLanguagePreference.values) {
      expect(find.byKey(Key('language-${lang.code}')), findsOneWidget);
    }
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-display')));
    await tester.pumpAndSettle();
    expect(find.text('Application Preferences'), findsOneWidget);
  });

  testWidgets(
    'choosing Tamil applies immediately and survives an app restart',
    (tester) async {
      phone(tester);
      await _mountApp(tester, '/settings/language');

      await tester.tap(find.byKey(const Key('language-ta')));
      await tester.pumpAndSettle();
      expect(find.text('மொழி'), findsOneWidget); // AppBar title "Language"
      expect(find.text('மொழி மாற்றப்பட்டது'), findsOneWidget); // confirmation
      expect(
        await SecureStorageService().getPreference('rb_pref_language'),
        'ta',
      );

      AppRouter.router.go('/more');
      await tester.pumpAndSettle();
      expect(find.text('முகப்பு'), findsOneWidget); // bottom nav "Home"
      expect(find.text('Home'), findsNothing);

      // Restart: tear the whole app down and mount a fresh provider scope.
      await tester.pumpWidget(const SizedBox());
      await _mountApp(tester, '/more');
      expect(find.text('முகப்பு'), findsOneWidget);
      expect(find.text('சுயவிவரம்'), findsOneWidget); // More tile "Profile"
    },
  );

  for (final (lang, home) in [
    (AppLanguagePreference.hi, 'होम'),
    (AppLanguagePreference.pa, 'ਹੋਮ'),
    (AppLanguagePreference.te, 'హోమ్'),
    (AppLanguagePreference.kn, 'ಮುಖಪುಟ'),
    (AppLanguagePreference.ml, 'ഹോം'),
  ]) {
    testWidgets(
      '${lang.englishName} renders the navigation without layout errors',
      (tester) async {
        phone(tester);
        await SecureStorageService().savePreference(
          'rb_pref_language',
          lang.code,
        );
        await _mountApp(tester, '/settings');
        expect(tester.takeException(), isNull);
        AppRouter.router.go('/more');
        await tester.pumpAndSettle();
        expect(find.text(home), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
