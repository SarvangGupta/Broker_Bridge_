import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/core/preferences/app_settings_provider.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';
import 'package:rmseller_mobile/features/profile/presentation/widgets/app_settings_section.dart';

void main() {
  setUp(() async {
    final storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
  });

  group('RB-APP-SETTINGS-01: AppSettings Provider & Logic', () {
    test('Initializes with accessible defaults', () {
      const state = AppSettingsState();
      expect(state.themeModePref, AppThemeModePreference.system);
      expect(state.themeMode, ThemeMode.system);
      expect(state.fontSizePref, AppFontSizePreference.normal);
      expect(state.fontScale, 1.0);
      expect(state.languagePref, AppLanguagePreference.en);
      expect(state.locale, const Locale('en'));
      expect(state.highContrast, isFalse);
    });

    test('Font scaling tiers evaluate to exact factors', () {
      expect(AppFontSizePreference.small.scaleFactor, 0.85);
      expect(AppFontSizePreference.normal.scaleFactor, 1.0);
      expect(AppFontSizePreference.large.scaleFactor, 1.15);
      expect(AppFontSizePreference.extraLarge.scaleFactor, 1.30);
    });

    test('ThemeMode conversion maps accurately', () {
      expect(AppThemeModePreference.light.toThemeMode(), ThemeMode.light);
      expect(AppThemeModePreference.dark.toThemeMode(), ThemeMode.dark);
      expect(AppThemeModePreference.system.toThemeMode(), ThemeMode.system);
    });

    test('Language conversion produces correct Locales', () {
      expect(AppLanguagePreference.en.toLocale(), const Locale('en'));
      expect(AppLanguagePreference.hi.toLocale(), const Locale('hi'));
    });
  });

  group('RB-APP-SETTINGS-01: AppSettingsSection Widget UI Tests', () {
    testWidgets(
      'Renders all four preferences: Theme, Language, Font Size & Accessibility',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.light,
              home: const Scaffold(
                body: SingleChildScrollView(child: AppSettingsSection()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Header
        expect(find.text('Application Preferences'), findsOneWidget);

        // Verify Theme options
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);
        expect(find.text('System Default'), findsOneWidget);

        // Verify Languages
        expect(find.text('English (Default)'), findsOneWidget);
        expect(find.text('हिन्दी (Hindi)'), findsOneWidget);

        // Verify Font sizes
        expect(find.text('Small'), findsOneWidget);
        expect(find.text('Default'), findsOneWidget);
        expect(find.text('Large'), findsOneWidget);
        expect(find.text('Extra Large'), findsOneWidget);

        // Verify Accessibility toggle
        expect(find.text('High Contrast Outlines'), findsOneWidget);
        expect(find.byType(Switch), findsOneWidget);
      },
    );

    testWidgets('Tapping Dark theme updates state reactively', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: const Scaffold(
              body: SingleChildScrollView(child: AppSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Dark theme button
      final darkButton = find.text('Dark');
      expect(darkButton, findsOneWidget);
      await tester.tap(darkButton);
      await tester.pumpAndSettle();

      // Verify provider state updated
      final currentSettings = container.read(appSettingsProvider);
      expect(currentSettings.themeModePref, AppThemeModePreference.dark);
      expect(currentSettings.themeMode, ThemeMode.dark);
    });

    testWidgets(
      'Tapping Hindi updates language and interface labels dynamically',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: AppSettingsSection()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on Hindi button
        final hindiButton = find.text('हिन्दी (Hindi)');
        expect(hindiButton, findsOneWidget);
        await tester.tap(hindiButton);
        await tester.pumpAndSettle();

        // Verify state changed
        final currentSettings = container.read(appSettingsProvider);
        expect(currentSettings.languagePref, AppLanguagePreference.hi);
        expect(currentSettings.locale, const Locale('hi'));

        // Verify localized section header is rendered
        expect(find.text('एप्लिकेशन प्राथमिकताएं'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Extra Large font size scales live preview without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, _) {
                final settings = ref.watch(appSettingsProvider);
                return MaterialApp(
                  theme: AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(settings.fontScale),
                    ),
                    child: child!,
                  ),
                  home: const Scaffold(
                    body: SingleChildScrollView(child: AppSettingsSection()),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on Extra Large size
        final extraLargeButton = find.text('Extra Large');
        expect(extraLargeButton, findsOneWidget);
        await tester.tap(extraLargeButton);
        await tester.pumpAndSettle();

        final currentSettings = container.read(appSettingsProvider);
        expect(currentSettings.fontSizePref, AppFontSizePreference.extraLarge);
        expect(currentSettings.fontScale, 1.30);

        // Verify no overflow occurred
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('SellerProfileScreen integrates AppSettingsSection cleanly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SellerProfileScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Verify Profile and Settings both present
      expect(find.text('Seller Profile & Mandi Desk'), findsOneWidget);
      expect(find.byType(AppSettingsSection), findsOneWidget);
      expect(find.text('Application Preferences'), findsOneWidget);
      expect(find.text('Sign Out of Seller Desk'), findsOneWidget);
    });
  });
}
