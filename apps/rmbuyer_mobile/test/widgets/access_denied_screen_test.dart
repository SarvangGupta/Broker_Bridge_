import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/authentication/presentation/access_denied_screen.dart';

void main() {
  group('RB-BUYER-01: AccessDeniedScreen Widget Tests', () {
    testWidgets('Renders unauthorized message, account email, and detected role badge',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AccessDeniedScreen(
            email: 'seller.user@agrofarms.com',
            role: 'seller',
            message:
                'Buyer Portal Access Restricted: Your account role (seller) does not have commodity buyer permissions.',
          ),
        ),
      );

      // Verify Header and Title
      expect(find.text('Buyer Access Restricted'), findsOneWidget);

      // Verify Message
      expect(
        find.textContaining('Your account role (seller) does not have commodity buyer permissions.'),
        findsOneWidget,
      );

      // Verify Account and Role Badges
      expect(find.text('seller.user@agrofarms.com'), findsOneWidget);
      expect(find.text('SELLER'), findsOneWidget);

      // Verify Action Button
      expect(find.text('Return to Login'), findsOneWidget);
    });

    testWidgets('Renders broker role denial clearly with fiduciary notice',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AccessDeniedScreen(
            email: 'broker.desk@jaipurmandi.com',
            role: 'broker',
          ),
        ),
      );

      expect(find.text('Buyer Access Restricted'), findsOneWidget);
      expect(find.text('broker.desk@jaipurmandi.com'), findsOneWidget);
      expect(find.text('BROKER'), findsOneWidget);
      expect(find.text('Return to Login'), findsOneWidget);
    });
  });
}
