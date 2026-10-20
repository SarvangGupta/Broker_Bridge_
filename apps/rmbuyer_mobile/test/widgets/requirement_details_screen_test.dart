import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/requirement_details_screen.dart';

void main() {
  group('RB-BUYER-04: RequirementDetailsScreen Widget Tests', () {
    testWidgets('Renders authoritative requirement details, commercial terms, and timeline', (WidgetTester tester) async {
      final repo = RequirementsRepository();
      final req = BuyerRequirement(
        id: 'REQ-2026-TEST',
        commodityName: 'Yellow Soybean',
        gradeName: 'Grade A FAQ',
        quantity: 50.0,
        unit: 'MT',
        targetPrice: 4850.0,
        status: 'Open',
        targetDate: DateTime.now().add(const Duration(days: 7)),
        deliveryTerms: 'FOR Factory Depot, Indore',
        brokerName: 'Jaipur Grain Broker Desk',
        paymentTerms: 'Payment on Delivery (CAD)',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RequirementDetailsScreen(
            requirementId: req.id,
            initialRequirement: req,
            repository: repo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Screen Header & Status
      expect(find.text('Mandate: REQ-2026-TEST'), findsOneWidget);
      expect(find.text('Status: Open'), findsOneWidget);
      expect(find.textContaining('Mandate is active on the verified mandi broker floor'), findsOneWidget);

      // Commodity & Commercial Metrics
      expect(find.text('Yellow Soybean'), findsOneWidget);
      expect(find.text('Grade A FAQ'), findsOneWidget);
      expect(find.text('50.0 MT'), findsOneWidget);
      expect(find.textContaining('4,850/MT'), findsOneWidget);
      expect(find.textContaining('2,42,500'), findsOneWidget); // 50 * 4850

      // Logistics & Terms
      expect(find.text('FOR Factory Depot, Indore'), findsOneWidget);
      expect(find.textContaining('Payment on Delivery (CAD)'), findsOneWidget);

      // Broker Desk & Counterparty Security
      expect(find.text('Jaipur Grain Broker Desk'), findsOneWidget);
      expect(find.textContaining('Counterparty Shield Active'), findsOneWidget);

      // Activity Timeline
      expect(find.text('Activity Timeline & Status History'), findsOneWidget);
      expect(find.text('Requirement Created'), findsOneWidget);
      expect(find.text('Broker Desk Assigned'), findsOneWidget);

      // Cancel button available for Open status
      expect(find.text('Cancel Procurement Mandate'), findsOneWidget);
    });

    testWidgets('Non-open requirement displays locked message disabling direct cancellation', (WidgetTester tester) async {
      final repo = RequirementsRepository();
      final req = BuyerRequirement(
        id: 'REQ-LOCKED-TEST',
        commodityName: 'Sharbati Wheat',
        gradeName: 'Premium Sharbati',
        quantity: 100.0,
        unit: 'MT',
        targetPrice: 2800.0,
        status: 'In Negotiation',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        deliveryTerms: 'Ex-Warehouse Jaipur Central Depot',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RequirementDetailsScreen(
            requirementId: req.id,
            initialRequirement: req,
            repository: repo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Status: In Negotiation'), findsOneWidget);
      expect(find.textContaining('Assigned broker desk is currently negotiating'), findsOneWidget);
      expect(find.textContaining('locked in active trade operations and cannot be cancelled directly'), findsOneWidget);
      expect(find.text('Cancel Procurement Mandate'), findsNothing);
    });

    testWidgets('Handles unknown or newly introduced status without crashing', (WidgetTester tester) async {
      final repo = RequirementsRepository();
      final req = BuyerRequirement(
        id: 'REQ-UNKNOWN-TEST',
        commodityName: 'Mustard Seeds',
        gradeName: 'Standard',
        quantity: 40.0,
        unit: 'MT',
        targetPrice: 5400.0,
        status: 'Arbitration Pending', // Non-standard status
        targetDate: DateTime.now().add(const Duration(days: 8)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RequirementDetailsScreen(
            requirementId: req.id,
            initialRequirement: req,
            repository: repo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Status: Arbitration Pending'), findsOneWidget);
      expect(find.textContaining('Mandate is in authoritative state "Arbitration Pending"'), findsOneWidget);
    });

    testWidgets('Requirement not found or unauthorized access renders clean empty state', (WidgetTester tester) async {
      final repo = RequirementsRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RequirementDetailsScreen(
            requirementId: 'REQ-NONEXISTENT-999',
            repository: repo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Requirement Not Found'), findsOneWidget);
      expect(find.textContaining('does not exist or you do not have authorization to view it'), findsOneWidget);
      expect(find.text('Return to Requirements'), findsOneWidget);
    });

    testWidgets('Cancelling open requirement opens reason dialog and updates UI', (WidgetTester tester) async {
      final repo = RequirementsRepository();
      final req = BuyerRequirement(
        id: 'REQ-CANCEL-WIDGET-TEST',
        commodityName: 'Yellow Maize',
        gradeName: 'Grade A',
        quantity: 20.0,
        unit: 'MT',
        targetPrice: 2200.0,
        status: 'Open',
        targetDate: DateTime.now().add(const Duration(days: 5)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RequirementDetailsScreen(
            requirementId: req.id,
            initialRequirement: req,
            repository: repo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap cancel button
      final cancelButton = find.text('Cancel Procurement Mandate');
      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Dialog rendered
      expect(find.text('Cancel Requirement'), findsOneWidget);
      expect(find.text('Reason for Cancellation *'), findsOneWidget);

      // Enter cancellation reason
      await tester.enterText(
        find.byType(TextField).first,
        'Found alternate supplier lot in Kota Mandi',
      );
      await tester.pumpAndSettle();

      // Confirm cancellation
      await tester.tap(find.text('Confirm Cancellation'));
      await tester.pumpAndSettle();

      // Snackbar displayed
      expect(find.textContaining('cancelled successfully'), findsOneWidget);
    });
  });
}
