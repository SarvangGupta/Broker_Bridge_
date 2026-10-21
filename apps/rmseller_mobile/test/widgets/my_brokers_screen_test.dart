import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmseller_mobile/features/brokers/presentation/my_brokers_screen.dart';

void main() {
  testWidgets('MyBrokersScreen renders FAB and opens Add Broker options bottom sheet', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MyBrokersScreen(),
      ),
    );

    // Initial load
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('My Mandi Brokers'), findsOneWidget);

    // Verify FAB presence with label "Add Broker"
    final fabFinder = find.byType(FloatingActionButton);
    expect(fabFinder, findsOneWidget);
    expect(find.text('Add Broker'), findsOneWidget);
    expect(find.byIcon(LucideIcons.userPlus), findsOneWidget);

    // Tap FAB to open bottom sheet
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    // Verify bottom sheet title and options
    expect(find.text('Add Mandi Broker'), findsOneWidget);
    expect(find.text('Select from Phone Contacts'), findsOneWidget);
    expect(find.text('Add Number Manually'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap "Cancel" to dismiss sheet
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Bottom sheet is dismissed
    expect(find.text('Add Mandi Broker'), findsNothing);
  });

  testWidgets('Add Number Manually opens mobile entry modal', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MyBrokersScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Tap FAB
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Tap "Add Number Manually"
    await tester.tap(find.text('Add Number Manually'));
    await tester.pumpAndSettle();

    // Verify manual entry dialog
    expect(find.text('Enter Broker Mobile Number'), findsOneWidget);
    expect(find.text('+91 (IN)'), findsOneWidget);
    expect(find.text('Verify & Add'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Enter Broker Mobile Number'), findsNothing);
  });
}
