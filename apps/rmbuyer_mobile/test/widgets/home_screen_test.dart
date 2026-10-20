import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders RMBuyer header, search, requirement CTA, and catalogs', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );

    // Verify application identity
    expect(find.text('RMBuyer'), findsOneWidget);
    expect(find.text('Buyer Procurement Workstation'), findsOneWidget);

    // Verify search trigger field
    expect(find.text('Search commodity or broker'), findsOneWidget);

    // Verify Primary Action
    expect(find.text('Post Your Requirement'), findsOneWidget);

    // Verify Mandi Catalogs
    expect(find.text('Browse Commodity Mandi Catalogs'), findsOneWidget);
    expect(find.text('Yellow Soybean'), findsOneWidget);
    expect(find.text('Desi Chana (Gram)'), findsOneWidget);
    expect(find.text('Wheat (Sharbati)'), findsOneWidget);
    expect(find.text('Mustard Seeds'), findsOneWidget);

    // Verify Fiduciary Notice
    expect(find.text('Regulated Broker-Mediated Procurement'), findsOneWidget);
  });
}
