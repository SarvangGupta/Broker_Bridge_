import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/router/app_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/authentication/domain/buyer_user.dart';

void main() {
  group('RB-BUYER-01: GoRouter Route Guard & Session Protection Tests', () {
    setUp(() {
      AppRouter.resetForTesting(status: AuthStatus.unauthenticated);
    });

    tearDown(() {
      AppRouter.resetForTesting();
    });

    testWidgets('Scenario 1: Signed-out user navigating to /home is redirected to /login',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppRouter.authNotifier.setStatus(AuthStatus.unauthenticated);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      );

      // Attempt navigation to protected /home
      AppRouter.router.go('/home');
      await tester.pumpAndSettle();

      // Verified: Protected home screen was NOT rendered, user redirected to Login
      expect(find.text('Procurement Buyer Workstation Login'), findsOneWidget);
      expect(find.text('Sign In to RMBuyer'), findsOneWidget);
    });

    testWidgets('Scenario 1b: Signed-out user navigating to /requirements is redirected to /login',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppRouter.authNotifier.setStatus(AuthStatus.unauthenticated);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      );

      AppRouter.router.go('/requirements');
      await tester.pumpAndSettle();

      expect(find.text('Procurement Buyer Workstation Login'), findsOneWidget);
    });

    testWidgets('Scenario 1c: Signed-out user navigating to /deals is redirected to /login',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppRouter.authNotifier.setStatus(AuthStatus.unauthenticated);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      );

      AppRouter.router.go('/deals');
      await tester.pumpAndSettle();

      expect(find.text('Procurement Buyer Workstation Login'), findsOneWidget);
    });

    testWidgets('Scenario 1d: Signed-out user navigating to /profile is redirected to /login',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppRouter.authNotifier.setStatus(AuthStatus.unauthenticated);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      );

      AppRouter.router.go('/profile');
      await tester.pumpAndSettle();

      expect(find.text('Procurement Buyer Workstation Login'), findsOneWidget);
    });

    testWidgets('Scenario 1e: Signed-out user navigating to /search is redirected to /login',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppRouter.authNotifier.setStatus(AuthStatus.unauthenticated);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      );

      AppRouter.router.go('/search?q=soybean');
      await tester.pumpAndSettle();

      expect(find.text('Procurement Buyer Workstation Login'), findsOneWidget);
    });

    testWidgets('Scenario 1f: Signed-out user navigating to /notifications is redirected to /login',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppRouter.authNotifier.setStatus(AuthStatus.unauthenticated);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      );

      AppRouter.router.go('/notifications');
      await tester.pumpAndSettle();

      expect(find.text('Procurement Buyer Workstation Login'), findsOneWidget);
    });

    testWidgets('Unauthorized user (role rejected) navigating to /home is redirected to /access-denied',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppRouter.authNotifier.setAccessDenied(
        email: 'seller@agrofarms.com',
        role: 'seller',
        message: 'Account role (seller) does not have commodity buyer permissions.',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      );

      AppRouter.router.go('/home');
      await tester.pumpAndSettle();

      expect(find.text('Buyer Access Restricted'), findsOneWidget);
      expect(find.text('SELLER'), findsOneWidget);
      expect(find.text('seller@agrofarms.com'), findsOneWidget);
    });

    testWidgets('Preflight resolution: Protected routes redirect to / during initial session check',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppRouter.authNotifier.setStatus(AuthStatus.initial);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      );

      // Attempt navigation to /home while still in preflight
      AppRouter.router.go('/home');
      await tester.pump();

      // Protected screen does not flash, held at splash
      expect(find.text('RMBuyer'), findsOneWidget);
      expect(find.text('Enterprise Commodity Buyer Portal'), findsOneWidget);

      // Flush splash timer to ensure clean tearDown
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    });

    testWidgets('Authorized buyer is allowed to access /home and redirected away from /login',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppRouter.authNotifier.setAuthenticated(
        const BuyerUser(
          id: 'usr-100',
          email: 'buyer@apexgrain.com',
          fullName: 'Rajesh Singhal',
          role: 'buyer',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      );

      // Attempting to visit /login while already authenticated redirects to /home
      AppRouter.router.go('/login');
      await tester.pumpAndSettle();

      expect(find.text('Buyer Procurement Workstation'), findsOneWidget);
      expect(find.text('Procurement Buyer Workstation Login'), findsNothing);
    });
  });
}
