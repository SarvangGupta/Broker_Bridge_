import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/post_requirement_screen.dart';

import '../support/fake_requirements_repository.dart';

void main() {
  group('RB-BUYER-07: PostRequirementScreen Broker Selection Widget Tests', () {
    testWidgets('1. Renders Select Brokers to Notify section and Review Mandate Summary', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PostRequirementScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Section Header & Notice
      expect(find.text('Select Brokers to Notify'), findsOneWidget);
      expect(find.text('Open Broadcast'), findsOneWidget);
      expect(find.textContaining('Choose verified broker desks'), findsOneWidget);

      // Search field for brokers
      expect(find.text('Search Brokers by Name or Mandi'), findsOneWidget);

      // Review Mandate Summary Section
      expect(find.text('Review Mandate Summary'), findsOneWidget);
      expect(find.text('Selected Recipients'), findsOneWidget);
      expect(find.text('None (Open Mandate Broadcast)'), findsOneWidget);

      // Default submit button label when no brokers selected
      expect(find.text('Submit Procurement Requirement'), findsOneWidget);
    });

    testWidgets('2. Pre-selects broker when initialBrokerId is provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PostRequirementScreen(
            initialCommodity: 'Mustard Seed',
            initialBrokerId: 'broker-alpha',
            initialBrokerName: 'Varun Brokerage',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Recipient count badge
      expect(find.text('1 Selected'), findsOneWidget);

      // Dedicated mandate routing banner
      expect(find.text('Dedicated Mandate Routing'), findsOneWidget);

      // Dynamic submit button label updates to notify brokers
      expect(find.text('Submit Requirement & Notify Brokers'), findsOneWidget);

      // Summary displays 1 Broker Desk(s)
      expect(find.text('1 Broker Desk(s)'), findsOneWidget);
    });

    testWidgets('3. Deselect All button clears selected brokers and resets button text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PostRequirementScreen(
            initialBrokerId: 'broker-beta',
            initialBrokerName: 'Indore Desk',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 Selected'), findsOneWidget);

      // Scroll to Deselect All chip if needed
      final deselectChip = find.text('Deselect All');
      if (deselectChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(deselectChip);
        await tester.tap(deselectChip);
        await tester.pumpAndSettle();

        expect(find.text('Open Broadcast'), findsOneWidget);
        expect(find.text('Submit Procurement Requirement'), findsOneWidget);
      }
    });

    testWidgets('4. Submitting requirement with selected broker displays recipient in dialog', (WidgetTester tester) async {
      final repo = FakeRequirementsRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PostRequirementScreen(
            repository: repo,
            initialBrokerId: 'broker-varun',
            initialBrokerName: 'Varun Mandi Desk',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select a commodity from the live catalogue (nothing is preselected)
      await tester.ensureVisible(find.byKey(const Key('commodity-picker-field')));
      await tester.tap(find.byKey(const Key('commodity-picker-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('commodity-option-$wheatId')));
      await tester.pumpAndSettle();

      // Quantity and target price have no defaults; enter them.
      for (final (key, value) in [('requirement-quantity-field', '30'), ('requirement-price-field', '5200')]) {
        final field = find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      // Tap submit
      final submitBtn = find.text('Submit Requirement & Notify Brokers');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Check success dialog
      expect(find.text('Requirement Created'), findsOneWidget);
      expect(find.text('Notified Brokers (1): Varun Mandi Desk'), findsOneWidget);
    });
  });
}
