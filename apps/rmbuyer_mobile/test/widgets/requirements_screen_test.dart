import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/requirements_screen.dart';

void main() {
  testWidgets('RequirementsScreen renders title, status filter chips, and requirement cards', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    // Verify summary cards + filter chips (each label appears in both)
    expect(find.text('All'), findsNWidgets(2));
    expect(find.text('Open'), findsWidgets);
    expect(find.text('In Negotiation'), findsWidgets);
    expect(find.text('Proposal Received'), findsNWidgets(2));
    expect(find.text('Confirmed'), findsNWidgets(2));
    expect(find.text('Completed'), findsNWidgets(2));
    expect(find.text('Search commodity or requirement ID'), findsOneWidget);

    // Verify requirement items rendered
    expect(find.text('Yellow Soybean'), findsOneWidget);
    expect(find.text('Desi Chana (Gram)'), findsOneWidget);
    expect(find.text('Mustard Seeds'), findsOneWidget);
  });
}
