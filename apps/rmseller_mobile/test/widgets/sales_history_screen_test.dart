import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/reports/presentation/sales_history_screen.dart';

void main() {
  group('RB-SELLER-04: SalesHistoryScreen Widget Tests', () {
    late SecureStorageService storage;

    setUp(() async {
      storage = SecureStorageService();
      storage.enableMemoryFallbackForTesting();
      await storage.saveUserInfo(
        id: '20000000-0000-0000-0000-000000000001',
        role: 'seller',
        email: 'seller@agroenterprises.in',
        fullName: 'Bikaner Agro Commercials',
        companyId: '20000000-0000-0000-0000-000000000101',
      );
    });

    Widget createScreen() {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SalesHistoryScreen(),
      );
    }

    testWidgets('Renders reporting period filters and header actions', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      expect(find.text('Sales History & Financials'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Quarterly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('Renders revenue summary cards and commission breakdown', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Summary Cards
      expect(find.textContaining('Gross Sales Revenue'), findsOneWidget);
      expect(find.textContaining('Total Sold Volume'), findsOneWidget);
      expect(find.textContaining('Completed Deals'), findsOneWidget);

      // Receivables
      expect(find.text('Settled Receivables'), findsOneWidget);
      expect(find.text('Pending Invoices'), findsOneWidget);

      // Commission Breakdown Card
      expect(find.text('Broker Commission Breakdown'), findsOneWidget);
      expect(find.text('Total Agreed Comm.'), findsOneWidget);
      expect(find.text('Commission Paid'), findsOneWidget);
      expect(find.text('Outstanding Comm.'), findsOneWidget);
    });

    testWidgets(
      'Renders transaction list with commodity, rate, and broker desk',
      (tester) async {
        await tester.pumpWidget(createScreen());
        await tester.pumpAndSettle();

        expect(find.text('Mustard Seeds'), findsOneWidget);
        expect(find.textContaining('40.0 MT'), findsOneWidget);
        expect(find.textContaining('Kota Agro Brokerage'), findsOneWidget);
        expect(find.text('INV-2026-0042'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping export button opens statement dialog with shield disclaimer',
      (tester) async {
        await tester.pumpWidget(createScreen());
        await tester.pumpAndSettle();

        // Tap Export icon
        await tester.tap(find.byTooltip('Export Statement'));
        await tester.pumpAndSettle();

        expect(find.text('Export Sales Statement'), findsOneWidget);
        expect(find.textContaining('Reporting Period'), findsOneWidget);
        expect(
          find.textContaining('Counterparty Shield Notice'),
          findsOneWidget,
        );
        expect(find.text('Download PDF Statement'), findsOneWidget);
      },
    );
  });
}
