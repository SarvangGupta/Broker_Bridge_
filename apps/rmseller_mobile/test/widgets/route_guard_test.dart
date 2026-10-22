import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmseller_mobile/app/router/app_router.dart';

void main() {
  group('RB-SELLER-01: AppRouter Route Guard Unit Tests', () {
    setUp(() {
      AppRouter.resetForTesting(status: AuthStatus.initial);
    });

    test(
      'Initial uninitialized status redirects any protected path to splash /',
      () {
        final state = GoRouterState(
          GoRouter(routes: []),
          location: '/commodities',
          uri: Uri.parse('/commodities'),
          matchedLocation: '/commodities',
        );
        final redirect = AppRouter.redirectLogic(_MockBuildContext(), state);
        expect(redirect, equals('/'));
      },
    );

    test(
      'Unauthenticated user attempting to access /home is redirected to /login',
      () {
        AppRouter.authNotifier.setUnauthenticated();
        final state = GoRouterState(
          GoRouter(routes: []),
          location: '/home',
          uri: Uri.parse('/home'),
          matchedLocation: '/home',
        );
        final redirect = AppRouter.redirectLogic(_MockBuildContext(), state);
        expect(redirect, equals('/login'));
      },
    );

    test('Access denied user is redirected to /access-denied', () {
      AppRouter.authNotifier.setAccessDenied(
        email: 'buyer@demo.com',
        role: 'buyer',
      );
      final state = GoRouterState(
        GoRouter(routes: []),
        location: '/commodities',
        uri: Uri.parse('/commodities'),
        matchedLocation: '/commodities',
      );
      final redirect = AppRouter.redirectLogic(_MockBuildContext(), state);
      expect(redirect, equals('/access-denied'));
    });

    test('Authenticated seller accessing /login is redirected to /home', () {
      AppRouter.authNotifier.setAuthenticated(
        token: 'seller_jwt',
        role: 'seller',
      );
      final state = GoRouterState(
        GoRouter(routes: []),
        location: '/login',
        uri: Uri.parse('/login'),
        matchedLocation: '/login',
      );
      final redirect = AppRouter.redirectLogic(_MockBuildContext(), state);
      expect(redirect, equals('/home'));
    });

    test('Authenticated seller accessing /commodities is allowed through', () {
      AppRouter.authNotifier.setAuthenticated(
        token: 'seller_jwt',
        role: 'seller',
      );
      final state = GoRouterState(
        GoRouter(routes: []),
        location: '/commodities',
        uri: Uri.parse('/commodities'),
        matchedLocation: '/commodities',
      );
      final redirect = AppRouter.redirectLogic(_MockBuildContext(), state);
      expect(redirect, isNull);
    });
  });
}

class _MockBuildContext extends Fake implements BuildContext {}
