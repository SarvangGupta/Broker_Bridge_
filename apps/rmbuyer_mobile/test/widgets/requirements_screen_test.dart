import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/requirements_screen.dart';

void main() {
  testWidgets('RequirementsScreen renders title, status filter chips, and requirement cards', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const RequirementsScreen(),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pump to resolve future
    await tester.pumpAndSettle();

    // Verify Title & Floating Action Button
    expect(find.text('Procurement Requirements'), findsOneWidget);
    expect(find.text('Post Requirement'), findsOneWidget);

    // Verify filter chips
    expect(find.text('All Requirements'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('In Negotiation'), findsOneWidget);
    expect(find.text('Fulfilled'), findsOneWidget);

    // Verify requirement items rendered
    expect(find.text('Yellow Soybean'), findsOneWidget);
    expect(find.text('Desi Chana (Gram)'), findsOneWidget);
    expect(find.text('Mustard Seeds'), findsOneWidget);
  });
}
