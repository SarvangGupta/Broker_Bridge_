import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/authentication/presentation/access_denied_screen.dart';

void main() {
  group('RB-SELLER-01: AccessDeniedScreen Widget Tests', () {
    testWidgets(
      'Renders access restricted warning and user email/role details',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AccessDeniedScreen(
              email: 'buyer@demo.com',
              role: 'buyer',
            ),
          ),
        );

        expect(find.text('Access Restricted'), findsOneWidget);
        expect(find.textContaining('buyer@demo.com'), findsOneWidget);
        expect(find.textContaining('role "buyer"'), findsOneWidget);
        expect(find.byIcon(LucideIcons.shieldAlert), findsOneWidget);
        expect(find.text('Sign Out & Return to Login'), findsOneWidget);
      },
    );

    testWidgets('Custom message override is respected when provided', (
      tester,
    ) async {
      const customMsg =
          'Custom Security Restriction: Counterparty access prohibited.';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AccessDeniedScreen(
            email: 'broker@demo.com',
            role: 'broker',
            message: customMsg,
          ),
        ),
      );

      expect(find.text(customMsg), findsOneWidget);
      expect(find.text('Access Restricted'), findsOneWidget);
    });
  });
}
