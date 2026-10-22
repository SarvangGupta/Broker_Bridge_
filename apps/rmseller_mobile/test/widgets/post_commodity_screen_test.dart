import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/commodities/presentation/post_commodity_screen.dart';

void main() {
  group('RB-SELLER-02: PostCommodityScreen Widget Tests', () {
    testWidgets(
      'Renders all 5 trading workflow sections including review summary after master catalog load',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostCommodityScreen(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Post Commodity Lot'), findsOneWidget);
        expect(find.text('1. Commodity & Specification'), findsOneWidget);
        expect(find.text('2. Quantity & Commercial Pricing'), findsOneWidget);
        expect(find.text('3. Warehouse Location & Loading'), findsOneWidget);
        expect(find.text('4. Broker Mandate Assignment'), findsOneWidget);
        expect(
          find.text('5. Review Mandate & Listing Summary'),
          findsOneWidget,
        );
        expect(find.text('List Commodity on Desk'), findsOneWidget);
      },
    );

    testWidgets('Renders dedicated review summary card fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PostCommodityScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Supply Quantity'), findsOneWidget);
      expect(find.text('Asking Price'), findsOneWidget);
      expect(find.text('Office HQ'), findsOneWidget);
      expect(find.text('Commercial Terms'), findsOneWidget);
      expect(find.text('Mandate Routing'), findsOneWidget);
    });

    testWidgets('Form validation catches empty quantity submission', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PostCommodityScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap submit without filling required fields
      final submitButton = find.text('List Commodity on Desk');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Form validation error indicator should appear
      expect(find.text('Required'), findsWidgets);
    });
  });
}
