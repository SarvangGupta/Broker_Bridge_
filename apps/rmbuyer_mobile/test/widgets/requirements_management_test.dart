import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/requirements_screen.dart';

void main() {
  group('RB-BUYER-03: RequirementsScreen Management & Details Tests', () {
    testWidgets('Tapping requirement card opens detailed bottom sheet with metrics & broker desk', (WidgetTester tester) async {
      final repo = RequirementsRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RequirementsScreen(repository: repo),
        ),
      );

      await tester.pumpAndSettle();

      // Find first requirement card
      final firstReq = find.text('Yellow Soybean');
      expect(firstReq, findsOneWidget);

      await tester.tap(firstReq);
      await tester.pumpAndSettle();

      // Detailed Bottom Sheet
      expect(find.text('Requirement ID: REQ-2026-081'), findsOneWidget);
      expect(find.text('Target Quantity'), findsWidgets);
      expect(find.text('Est. Mandate Value'), findsOneWidget);
      expect(find.text('Assigned Mandi Broker Desk'), findsOneWidget);
      expect(find.text('Jaipur Grain Broker Desk'), findsWidgets);
      expect(find.text('Payment Terms'), findsWidgets);
      expect(find.text('Payment on Delivery (CAD)'), findsWidgets);
      expect(find.textContaining('Direct seller identities are protected and broker-mediated'), findsOneWidget);
      expect(find.text('Cancel Procurement Mandate'), findsOneWidget);
    });

    testWidgets('Cancelling open requirement requires reason and updates status', (WidgetTester tester) async {
      final repo = RequirementsRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RequirementsScreen(repository: repo),
        ),
      );

      await tester.pumpAndSettle();

      // Tap first requirement
      await tester.tap(find.text('Yellow Soybean'));
      await tester.pumpAndSettle();

      // Tap Cancel button in modal
      final cancelBtn = find.text('Cancel Procurement Mandate');
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog rendered
      expect(find.text('Cancel Requirement'), findsOneWidget);
      expect(find.text('Reason for Cancellation *'), findsOneWidget);
      expect(find.text('Confirm Cancellation'), findsOneWidget);

      // Enter cancellation reason
      await tester.enterText(
        find.byType(TextField).last,
        'Requirement fulfilled through local mandi auction',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Cancellation'));
      await tester.pumpAndSettle();

      // Snackbar confirmation
      expect(find.textContaining('cancelled successfully'), findsOneWidget);
    });
  });
}
