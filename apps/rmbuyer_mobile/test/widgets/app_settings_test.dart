import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/core/preferences/app_settings_provider.dart';
import 'package:rmbuyer_mobile/core/security/secure_storage_service.dart';
import 'package:rmbuyer_mobile/features/authentication/domain/buyer_user.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/buyer_profile_screen.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/widgets/app_settings_section.dart';

void main() {
  setUp(() async {
    final storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
  });

  group('RB-APP-SETTINGS-01: RMBuyer AppSettings Provider & Logic', () {
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

    test('Dark theme config is defined and valid', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
    });
  });

  group('RB-APP-SETTINGS-01: RMBuyer AppSettingsSection UI Tests', () {
    testWidgets('Renders all four preferences: Theme, Language, Font Size & Accessibility',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: AppSettingsSection(),
              ),
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
    });

    testWidgets('Tapping Dark theme updates state reactively', (WidgetTester tester) async {
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
            home: const Scaffold(
              body: SingleChildScrollView(
                child: AppSettingsSection(),
              ),
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

    testWidgets('Tapping Hindi updates language and interface labels dynamically',
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
              body: SingleChildScrollView(
                child: AppSettingsSection(),
              ),
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

      final currentSettings = container.read(appSettingsProvider);
      expect(currentSettings.languagePref, AppLanguagePreference.hi);
      expect(currentSettings.locale, const Locale('hi'));

      // Localized header rendered
      expect(find.text('एप्लिकेशन प्राथमिकताएं'), findsOneWidget);
    });

    testWidgets('Tapping Extra Large font size scales live preview without overflow',
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
                  body: SingleChildScrollView(
                    child: AppSettingsSection(),
                  ),
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

      expect(tester.takeException(), isNull);
    });

    testWidgets('BuyerProfileScreen integrates AppSettingsSection and buyer details cleanly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BuyerProfileScreen(
              user: BuyerUser(
                id: 'b-001',
                email: 'buyer@apexprocurement.com',
                fullName: 'Rajesh Singhal',
                role: 'buyer',
                companyName: 'Apex Grain Processors Pvt Ltd',
                companyGst: '08AABCA1234F1Z8',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buyer Profile & Settings'), findsOneWidget);
      expect(find.byType(AppSettingsSection), findsOneWidget);
      expect(find.text('Application Preferences'), findsOneWidget);
      expect(find.text('Sign Out of RMBuyer'), findsOneWidget);
    });
  });
}
