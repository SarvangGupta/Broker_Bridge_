import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/deals/presentation/buyer_deals_screen.dart';

void main() {
  testWidgets('BuyerDealsScreen renders counterparty shield banner, status filters, and deal cards', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const BuyerDealsScreen(),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // Verify Title & Counterparty Shield
    expect(find.text('Procurement Deals'), findsOneWidget);
    expect(find.textContaining('Counterparty Shield:'), findsOneWidget);

    // Verify filter chips
    expect(find.text('All Deals'), findsOneWidget);
    expect(find.text('In Transit'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);

    // Verify Deal Cards
    expect(find.text('Mustard Seeds'), findsOneWidget);
    expect(find.text('Yellow Soybean'), findsOneWidget);
    expect(find.text('Desi Chana (Gram)'), findsOneWidget);

    // Verify Broker Desk label
    expect(find.textContaining('Broker Desk:'), findsWidgets);
  });
}
