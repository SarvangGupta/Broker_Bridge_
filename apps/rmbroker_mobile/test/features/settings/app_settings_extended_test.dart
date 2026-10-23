import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/app.dart';
import 'package:rmbroker_mobile/app/theme/app_theme.dart';
import 'package:rmbroker_mobile/core/preferences/app_settings_provider.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/settings/presentation/settings_screen.dart';

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
  });

  group('Feature B & C: App Settings & Asterisk Icon-Only Mode Tests', () {
    test('Initializes with eyeProtectionMode = false and iconOnlyMode = false', () {
      const state = AppSettingsState();
      expect(state.eyeProtectionMode, isFalse);
      expect(state.iconOnlyMode, isFalse);
    });

    test('Eye-Protection Mode and Asterisk Mode toggle independently', () {
      var state = const AppSettingsState();
      state = state.copyWith(eyeProtectionMode: true);
      expect(state.eyeProtectionMode, isTrue);
      expect(state.iconOnlyMode, isFalse);

      state = state.copyWith(iconOnlyMode: true);
      expect(state.eyeProtectionMode, isTrue);
      expect(state.iconOnlyMode, isTrue);

      state = state.copyWith(eyeProtectionMode: false);
      expect(state.eyeProtectionMode, isFalse);
      expect(state.iconOnlyMode, isTrue);
    });

    test('Preferences persist across container restarts', () async {
      final container1 = ProviderContainer();
      final notifier1 = container1.read(appSettingsProvider.notifier);

      await notifier1.setEyeProtectionMode(true);
      await notifier1.setIconOnlyMode(true);
      await notifier1.setThemeMode(AppThemeModePreference.dark);
      await notifier1.setLanguage(AppLanguagePreference.hi);

      // Verify stored in SecureStorage
      expect(await storage.getPreference('rb_pref_eye_protection'), 'true');
      expect(await storage.getPreference('rb_pref_icon_only'), 'true');
      expect(await storage.getPreference('rb_pref_theme_mode'), 'dark');
      expect(await storage.getPreference('rb_pref_language'), 'hi');

      // Create new container simulating app restart
      final container2 = ProviderContainer();
      container2.read(appSettingsProvider);
      // Allow async loading of persisted preferences
      await pumpEventQueue();
      final state2 = container2.read(appSettingsProvider);

      expect(state2.eyeProtectionMode, isTrue);
      expect(state2.iconOnlyMode, isTrue);
      expect(state2.themeModePref, AppThemeModePreference.dark);
      expect(state2.languagePref, AppLanguagePreference.hi);
    });
  });

  group('Feature B & C: SettingsScreen Widget Tests', () {
    testWidgets('Renders Eye-Protection Mode and Asterisk Mode toggles',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('Eye-Protection Mode'), findsOneWidget);
      expect(find.text('Asterisk (*) Icon-Only Mode'), findsOneWidget);

      // Verify Asterisk button exists in AppBar
      expect(find.text('*'), findsWidgets);
    });

    testWidgets('RMBrokerApp applies eye-protection overlay when enabled',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      container.read(appSettingsProvider.notifier).setEyeProtectionMode(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RMBrokerApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      // Find DecoratedBox with warm tint (0x12FF9800)
      final decoratedBoxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      final hasEyeProtectionOverlay = decoratedBoxes.any((box) {
        final dec = box.decoration;
        if (dec is BoxDecoration) {
          return dec.color == const Color(0x12FF9800);
        }
        return false;
      });

      expect(hasEyeProtectionOverlay, isTrue);
    });
  });
}
