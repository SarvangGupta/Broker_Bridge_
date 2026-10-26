import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmseller_mobile/features/home/presentation/navigation_shell.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_more_screen.dart';

void main() {
  group('SELLER-BOTTOM-NAV-UI-01: NavigationShell', () {
    GoRouter buildRouter() {
      Widget page(String name) => Scaffold(
        appBar: AppBar(title: Text('$name page')),
        body: ListView(
          children: [
            for (var i = 0; i < 40; i++) ListTile(title: Text('$name row $i')),
          ],
        ),
      );

      StatefulShellBranch branch(String path, String name) =>
          StatefulShellBranch(
            routes: [
              GoRoute(path: path, builder: (context, state) => page(name)),
            ],
          );

      return GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                NavigationShell(navigationShell: shell),
            branches: [
              branch('/home', 'Home'),
              branch('/commodities', 'Commodities'),
              branch('/brokers', 'Brokers'),
              branch('/deals', 'Deals'),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/more',
                    builder: (context, state) => const SellerMoreScreen(),
                    routes: [
                      GoRoute(
                        path: 'reports',
                        builder: (context, state) => page('Reports'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    testWidgets('Shows exactly five items in order, Brokers centred', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
      await tester.pumpAndSettle();

      const labels = ['Home', 'Commodities', 'Brokers', 'Deals', 'More'];
      final xs = <double>[];
      for (final label in labels) {
        final item = find.byKey(Key('nav_item_$label'));
        expect(item, findsOneWidget);
        xs.add(tester.getCenter(item).dx);
      }
      // Left-to-right order
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
      }
      // Brokers is horizontally centred in the bar
      final bar = tester.getRect(find.byKey(const Key('seller_bottom_nav')));
      expect(xs[2], closeTo(bar.center.dx, 2));

      expect(find.byKey(const Key('nav_item_Reports')), findsNothing);
    });

    testWidgets('Each item switches to its branch', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
      await tester.pumpAndSettle();
      expect(find.text('Home page'), findsOneWidget);

      for (final label in ['Commodities', 'Brokers', 'Deals', 'Home']) {
        await tester.tap(find.byKey(Key('nav_item_$label')));
        await tester.pumpAndSettle();
        expect(find.text('$label page'), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('nav_item_More')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('more_menu_profile')), findsOneWidget);
    });

    testWidgets('Reports is reachable from More and has a back arrow', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav_item_More')));
      await tester.pumpAndSettle();

      for (final key in [
        'more_menu_profile',
        'more_menu_settings',
        'more_menu_reports',
        'more_menu_help',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('more_menu_reports')));
      await tester.pumpAndSettle();
      expect(find.text('Reports page'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('more_menu_reports')), findsOneWidget);
    });

    testWidgets('Fits a 320dp screen; centre button stays inside the bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
      await tester.pumpAndSettle();

      // Any RenderFlex overflow is reported by the framework and fails here.
      final bar = tester.getRect(find.byKey(const Key('seller_bottom_nav')));
      final brokers = tester.getRect(
        find.byKey(const Key('nav_item_Brokers')),
      );
      expect(brokers.top, greaterThanOrEqualTo(bar.top));

      // The page's scrollable ends above the bar, so no content is hidden.
      final list = tester.getRect(find.byType(ListView).first);
      expect(list.bottom, lessThanOrEqualTo(bar.top + 0.5));
    });
  });
}
