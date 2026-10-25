import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbroker_mobile/app/router/app_router.dart';
import 'package:rmbroker_mobile/core/preferences/app_settings_provider.dart';
import 'package:rmbroker_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/more/presentation/more_screen.dart';
import 'package:rmbroker_mobile/features/more/presentation/more_section_screens.dart';
import 'package:rmbroker_mobile/features/more/presentation/widgets/app_settings_section.dart';

class MockAuthRepository extends AuthRepository {
  final BrokerUser? mockUser;
  MockAuthRepository({this.mockUser});

  @override
  Future<BrokerUser?> getCurrentBroker() async {
    return mockUser ??
        const BrokerUser(
          id: 'b-001',
          email: 'varun@brokerbridge.in',
          fullName: 'Varun Broker Desk',
          role: 'broker',
          companyId: 'comp-001',
        );
  }
}

/// Mirrors the app's More branch: section pages are children of /more and
/// items open separate top-level routes.
GoRouter testRouter(List<String> opened) {
  GoRoute leaf(String path) => GoRoute(
        path: path,
        builder: (_, _) {
          opened.add(path);
          return Scaffold(appBar: AppBar(), body: Text('DEST $path'));
        },
      );
  return GoRouter(
    initialLocation: '/more',
    routes: [
      GoRoute(
        path: '/more',
        builder: (_, _) => MoreScreen(authRepository: MockAuthRepository()),
        routes: [
          GoRoute(path: 'tools', builder: (_, _) => const ToolsMenuScreen()),
          GoRoute(path: 'finance', builder: (_, _) => const FinanceMenuScreen()),
          GoRoute(
            path: 'settings',
            builder: (_, _) => const SettingsMenuScreen(),
            routes: [
              GoRoute(
                path: ':group',
                builder: (_, s) => PreferenceGroupScreen(group: PreferenceGroupScreen.fromSlug(s.pathParameters['group'])!),
              ),
            ],
          ),
        ],
      ),
      for (final p in ['/profile', '/broadcast/market-price', '/broadcast/history', '/tasks', '/notifications',
        '/commission', '/invoices', '/login'])
        leaf(p),
    ],
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<GoRouter> pump(WidgetTester tester, List<String> opened, {Size size = const Size(1080, 2160), double dpr = 2.75}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final router = testRouter(opened);
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  testWidgets('More shows exactly the four sections; no settings controls or submenu items', (tester) async {
    await pump(tester, []);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Tools & account settings'), findsOneWidget);
    for (final k in ['more_profile', 'more_tools', 'more_finance', 'more_settings']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.text('V'), findsOneWidget, reason: 'initial from the stored broker, not hardcoded');
    expect(find.byType(AppSettingsSection), findsNothing);
    for (final t in ['Market Price Broadcast', 'Brokerage & Commission Ledger', 'Security & Access Logs',
      'Language / भाषा', 'Application Preferences']) {
      expect(find.text(t), findsNothing, reason: t);
    }
    expect(find.text('Sign Out from Desk'), findsOneWidget);
  });

  testWidgets('Profile opens the existing profile route', (tester) async {
    final opened = <String>[];
    await pump(tester, opened);
    await tapAndSettle(tester, find.byKey(const Key('more_profile')));
    expect(opened, ['/profile']);
  });

  testWidgets('Tools lists its four items and each opens its existing route; back returns', (tester) async {
    final opened = <String>[];
    await pump(tester, opened);
    await tapAndSettle(tester, find.byKey(const Key('more_tools')));
    expect(find.byType(ToolsMenuScreen), findsOneWidget);

    const expected = {
      'broadcast': '/broadcast/market-price',
      'broadcast_history': '/broadcast/history',
      'tasks': '/tasks',
      'notifications': '/notifications',
    };
    for (final e in expected.entries) {
      await tapAndSettle(tester, find.byKey(Key('more_item_${e.key}')));
      expect(opened.last, e.value);
      await back(tester);
      expect(find.byType(ToolsMenuScreen), findsOneWidget, reason: 'back to Tools');
    }
    await back(tester);
    expect(find.byKey(const Key('more_tools')), findsOneWidget, reason: 'back to More');
  });

  testWidgets('Finance lists commission ledger and invoices', (tester) async {
    final opened = <String>[];
    await pump(tester, opened);
    await tapAndSettle(tester, find.byKey(const Key('more_finance')));
    await tapAndSettle(tester, find.byKey(const Key('more_item_commission')));
    expect(opened.last, '/commission');
    await back(tester);
    await tapAndSettle(tester, find.byKey(const Key('more_item_invoices')));
    expect(opened.last, '/invoices');
  });

  testWidgets('Settings: preference groups use the existing controls and persist; info items honest', (tester) async {
    await pump(tester, []);
    await tapAndSettle(tester, find.byKey(const Key('more_settings')));
    for (final k in ['language', 'theme', 'font', 'accessibility', 'security', 'audit', 'fiduciary']) {
      expect(find.byKey(Key('more_item_$k')), findsOneWidget, reason: k);
    }

    // Theme group: only theme controls; selecting Dark updates the shared provider.
    await tapAndSettle(tester, find.byKey(const Key('more_item_theme')));
    expect(find.byType(AppSettingsSection), findsOneWidget);
    expect(find.text('Appearance & Theme'), findsOneWidget);
    expect(find.text('Language Selection'), findsNothing);
    await tapAndSettle(tester, find.text('Dark').first);
    final container = ProviderScope.containerOf(tester.element(find.byType(AppSettingsSection)));
    expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
    await back(tester);

    // The other groups render their existing sections.
    for (final (k, title) in [
      ('language', 'Language Selection'),
      ('font', 'Font Size & Text Scaling'),
      ('accessibility', 'Accessibility & Contrast'),
    ]) {
      await tapAndSettle(tester, find.byKey(Key('more_item_$k')));
      expect(find.text(title), findsOneWidget, reason: k);
      expect(tester.takeException(), isNull);
      await back(tester);
    }
    expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark, reason: 'kept after navigating');

    await tapAndSettle(tester, find.byKey(const Key('more_item_security')));
    expect(find.text('Security & Access Logs is not available yet.'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('more_item_fiduciary')));
    expect(find.text('Broker Fiduciary Boundary'), findsOneWidget);
  });

  testWidgets('section pages keep the bottom navigation with More selected (app router)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final router = AppRouter.router;
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    for (final path in ['/more/tools', '/more/finance', '/more/settings', '/more/settings/font']) {
      router.go(path);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 4, reason: path);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('small 320dp screen: More and Settings pages do not overflow', (tester) async {
    await pump(tester, [], size: const Size(640, 1136), dpr: 2.0);
    expect(tester.takeException(), isNull);
    await tapAndSettle(tester, find.byKey(const Key('more_settings')));
    expect(tester.takeException(), isNull);
  });
}
