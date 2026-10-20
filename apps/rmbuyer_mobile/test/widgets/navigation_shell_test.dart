import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/router/app_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';

void main() {
  testWidgets('Navigation routing and shell tabs render correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    AppRouter.authNotifier.setStatus(AuthStatus.authenticated);
    addTearDown(() {
      AppRouter.resetForTesting();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: AppRouter.router,
        ),
      ),
    );

    // Initial frame on splash screen or directly on home
    AppRouter.router.go('/home');
    await tester.pumpAndSettle();

    // Verify Bottom Navigation Bar items
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Requirements'), findsOneWidget);
    expect(find.text('Deals'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Tap Requirements tab in bottom nav
    await tester.tap(find.text('Requirements'));
    await tester.pumpAndSettle();

    expect(find.text('Procurement Requirements'), findsOneWidget);

    // Tap Deals tab in bottom nav
    await tester.tap(find.text('Deals'));
    await tester.pumpAndSettle();

    expect(find.text('Procurement Deals'), findsOneWidget);

    // Tap Profile tab in bottom nav
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Buyer Profile & Settings'), findsOneWidget);
  });
}
