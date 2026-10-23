import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/theme/app_theme.dart';
import 'package:rmbroker_mobile/core/preferences/app_settings_provider.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/more/presentation/more_screen.dart';
import 'package:rmbroker_mobile/features/more/presentation/widgets/app_settings_section.dart';

class MockBrokerAuthRepository extends AuthRepository {
  @override
  Future<BrokerUser?> getCurrentBroker() async {
    return const BrokerUser(
      id: 'b-001',
      email: 'varun@brokerbridge.in',
      fullName: 'Varun Broker Desk',
      role: 'broker',
      companyId: 'comp-001',
    );
  }
}

void main() {
  setUp(() async {
    final storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
  });

  group('RB-APP-SETTINGS-01: RMBroker AppSettings Provider & Logic', () {
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
      final darkTheme = AppTheme.dark;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
    });
  });

  group('RB-APP-SETTINGS-01: RMBroker AppSettingsSection UI Tests', () {
    testWidgets('Renders all four preferences: Theme, Language, Font Size & Accessibility',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
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

      // Verify Accessibility toggle & switches
      expect(find.text('High Contrast Outlines'), findsOneWidget);
      expect(find.text('Eye-Protection Mode'), findsOneWidget);
      expect(find.text('Asterisk (*) Icon-Only Mode'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(3));
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
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: AppSettingsSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkButton = find.text('Dark');
      expect(darkButton, findsOneWidget);
      await tester.tap(darkButton);
      await tester.pumpAndSettle();

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
            theme: AppTheme.light,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: AppSettingsSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hindiButton = find.text('हिन्दी (Hindi)');
      expect(hindiButton, findsOneWidget);
      await tester.tap(hindiButton);
      await tester.pumpAndSettle();

      final currentSettings = container.read(appSettingsProvider);
      expect(currentSettings.languagePref, AppLanguagePreference.hi);
      expect(currentSettings.locale, const Locale('hi'));

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
                theme: AppTheme.light,
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

      final extraLargeButton = find.text('Extra Large');
      expect(extraLargeButton, findsOneWidget);
      await tester.tap(extraLargeButton);
      await tester.pumpAndSettle();

      final currentSettings = container.read(appSettingsProvider);
      expect(currentSettings.fontSizePref, AppFontSizePreference.extraLarge);
      expect(currentSettings.fontScale, 1.30);

      expect(tester.takeException(), isNull);
    });

    testWidgets('MoreScreen integrates AppSettingsSection cleanly with existing tools list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAuth = MockBrokerAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MoreScreen(authRepository: mockAuth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('More Tools & Settings'), findsOneWidget);
      expect(find.text('Language / भाषा'), findsOneWidget);
      expect(find.byType(AppSettingsSection), findsOneWidget);
      expect(find.text('Application Preferences'), findsOneWidget);
      expect(find.text('Sign Out from Desk'), findsOneWidget);
    });
  });
}
