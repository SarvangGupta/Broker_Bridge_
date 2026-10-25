import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/core/preferences/app_settings_provider.dart';
import 'package:rmbuyer_mobile/core/security/secure_storage_service.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/display_settings_screen.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/widgets/app_settings_section.dart';
import 'package:rmbuyer_mobile/l10n/app_localizations.dart';

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
    testWidgets('Renders Theme, Font Size & Accessibility (language has its own screen)',
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

      // Language moved to Profile & Settings → Language
      expect(find.text('हिन्दी (Hindi)'), findsNothing);

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

    testWidgets('Section labels follow the app locale (Hindi)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('hi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: SingleChildScrollView(child: AppSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('एप्लिकेशन प्राथमिकताएँ'), findsOneWidget);
      expect(find.text('डार्क'), findsOneWidget);
      expect(find.text('Application Preferences'), findsNothing);
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

    testWidgets('Display & Accessibility screen hosts the settings section',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: DisplaySettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Display & Accessibility'), findsOneWidget);
      expect(find.byType(AppSettingsSection), findsOneWidget);
      expect(find.text('Application Preferences'), findsOneWidget);
    });
  });
}
