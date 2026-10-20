import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/post_requirement_screen.dart';

void main() {
  group('RB-BUYER-03: PostRequirementScreen Widget Tests', () {
    testWidgets('Renders all required fields, master dropdowns, payment terms, and submit button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PostRequirementScreen(),
        ),
      );

      // Loading master data
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Title & Security banner
      expect(find.text('Post Procurement Requirement'), findsOneWidget);
      expect(find.textContaining('Counterparty Shield Protected'), findsOneWidget);

      // Core Form Fields
      expect(find.text('Select Commodity *'), findsOneWidget);
      expect(find.text('Quality Grade'), findsOneWidget);
      expect(find.text('Required Quantity *'), findsOneWidget);
      expect(find.text('Unit *'), findsOneWidget);
      expect(find.textContaining('Target Price'), findsOneWidget);
      expect(find.text('Delivery Location *'), findsOneWidget);
      expect(find.text('Required Delivery Date *'), findsOneWidget);
      expect(find.text('Preferred Commercial Terms'), findsOneWidget);

      // Submit Button
      expect(find.text('Submit Procurement Requirement'), findsOneWidget);
    });

    testWidgets('Renders dedicated broker desk routing banner when broker parameters supplied', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PostRequirementScreen(
            initialCommodity: 'Yellow Maize',
            initialBrokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
            initialBrokerName: 'Jaipur Grain Broker Desk',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dedicated Mandate Routing'), findsOneWidget);
      expect(find.text('Jaipur Grain Broker Desk'), findsOneWidget);
      expect(find.text('Direct Desk'), findsOneWidget);
    });

    testWidgets('Submitting valid requirement opens authoritative confirmation dialog', (WidgetTester tester) async {
      final repo = RequirementsRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PostRequirementScreen(repository: repo),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Submit button
      final submitButton = find.text('Submit Procurement Requirement');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);

      await tester.pumpAndSettle();

      // Authoritative dialog displayed
      expect(find.text('Requirement Created'), findsOneWidget);
      expect(find.textContaining('Requirement ID:'), findsOneWidget);
      expect(find.text('View In Requirements'), findsOneWidget);
    });
  });
}
