import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/widgets/app_button.dart';
import 'package:rmbroker_mobile/core/widgets/app_card.dart';
import 'package:rmbroker_mobile/core/widgets/app_empty_state.dart';
import 'package:rmbroker_mobile/core/widgets/status_badge.dart';

void main() {
  group('Reusable Foundation Widgets Tests', () {
    testWidgets('AppButton renders label and triggers callback on tap', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Submit Deal',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Submit Deal'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(tapped, isTrue);
    });

    testWidgets('AppButton displays loading indicator when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Submit Deal',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit Deal'), findsNothing);
    });

    testWidgets('StatusBadge renders appropriate text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(status: 'Open'),
                StatusBadge(status: 'Finalized'),
                StatusBadge(status: 'Cancelled'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Finalized'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('AppCard renders child and padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppCard(child: Text('Card Content'))),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('AppEmptyState renders icon, title, description, and button', (
      tester,
    ) async {
      bool actionClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.inbox,
              title: 'Empty List',
              description: 'Nothing here yet',
              actionLabel: 'Add Item',
              onAction: () => actionClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Empty List'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);

      await tester.tap(find.text('Add Item'));
      expect(actionClicked, isTrue);
    });
  });
}
