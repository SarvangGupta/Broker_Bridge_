import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/authentication/presentation/login_screen.dart';

void main() {
  group('RB-SELLER-01: LoginScreen Widget Tests', () {
    testWidgets(
      'Renders RMSeller branding, input fields, test quick-fill and action button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
        );

        expect(find.text('RMSeller'), findsOneWidget);
        expect(find.text('Commodity Seller & Supply Desk'), findsOneWidget);
        expect(find.text('Seller Email or Mobile'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Sign In to Seller Desk'), findsOneWidget);
        expect(find.text('Authorized Seller'), findsOneWidget);
      },
    );

    testWidgets('Quick fill button updates email field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
      );

      // Tap on Buyer Account (Deny Test)
      await tester.tap(find.text('Buyer Account (Deny Test)'));
      await tester.pump();

      expect(find.text('buyer@demo.com'), findsOneWidget);
    });
  });
}
