import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/theme/app_theme.dart';
import 'package:rmbroker_mobile/features/authentication/presentation/access_denied_screen.dart';

void main() {
  Widget buildTestableAccessDeniedScreen({
    required String email,
    required String role,
    String? message,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: AccessDeniedScreen(email: email, role: role, message: message),
    );
  }

  group('AccessDeniedScreen Widget Tests', () {
    testWidgets(
      'renders role restriction details, badges, and action buttons',
      (tester) async {
        await tester.pumpWidget(
          buildTestableAccessDeniedScreen(
            email: 'buyer.ramesh@agrotraders.in',
            role: 'buyer',
            message: 'Access restricted to licensed commodity brokers.',
          ),
        );

        expect(find.text('Access Restricted'), findsOneWidget);
        expect(find.text('Broker Desk Access Restricted'), findsOneWidget);
        expect(
          find.text('Access restricted to licensed commodity brokers.'),
          findsOneWidget,
        );
        expect(find.text('buyer.ramesh@agrotraders.in'), findsOneWidget);
        expect(find.text('BUYER'), findsOneWidget);
        expect(find.text('BROKER or ADMIN'), findsOneWidget);
        expect(find.text('Sign Out & Switch Account'), findsOneWidget);
        expect(find.text('Contact Desk Administrator'), findsOneWidget);
      },
    );

    testWidgets('shows administrator contact dialog on help button tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableAccessDeniedScreen(
          email: 'seller.lot@mandi.in',
          role: 'seller',
        ),
      );

      final helpButton = find.text('Contact Desk Administrator');
      await tester.tap(helpButton);
      await tester.pumpAndSettle();

      expect(find.text('Administrator Support'), findsOneWidget);
      expect(find.textContaining('support@brokerbridge.com'), findsOneWidget);

      final closeButton = find.text('Close');
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.text('Administrator Support'), findsNothing);
    });
  });
}
