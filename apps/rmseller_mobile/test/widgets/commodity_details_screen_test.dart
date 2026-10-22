import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/commodities/presentation/commodity_details_screen.dart';

void main() {
  group('RB-SELLER-02: CommodityDetailsScreen Widget Tests', () {
    final testCommodity = SellerCommodity(
      id: 'AVL-TEST-9001',
      lotNumber: 'LOT-CHANA-01',
      commodityName: 'Desi Chana (Gram)',
      gradeName: 'Bold Size FAQ (Count 60-65)',
      totalQuantity: 100.0,
      availableQuantity: 75.0,
      reservedQuantity: 25.0,
      soldQuantity: 0.0,
      unit: 'MT',
      askingPrice: 5850.0,
      confidentialMinimumPrice: 5750.0,
      stateName: 'Rajasthan',
      districtName: 'Bikaner Mandi Hub',
      loadingStatus: 'Ready to Load',
      status: 'Active',
      availableFrom: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 7)),
      brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
      brokerName: 'Bikaner Mandi Broker Desk',
      brokerPhone: '+919829012345',
      brokerLocation: 'Krishi Upaj Mandi Yard B-Block',
      paymentTerms: 'Payment on Delivery (CAD)',
      officeLocation: 'Bikaner Commercial Head Office',
      loadingRemarks: 'Krishi Upaj Mandi Yard Warehouse A-4',
      labReportNumber: 'AGMARK-RAL-2026-9021',
      createdAt: DateTime.now(),
    );

    testWidgets(
      'Renders complete lot details, volumes, pricing, and locations',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: CommodityDetailsScreen(
              commodityId: testCommodity.id,
              initialCommodity: testCommodity,
            ),
          ),
        );

        expect(find.text('LOT-CHANA-01'), findsAtLeastNWidgets(1));
        expect(find.text('Desi Chana (Gram)'), findsOneWidget);
        expect(find.text('Bold Size FAQ (Count 60-65)'), findsOneWidget);
        expect(find.text('Ready to Load'), findsOneWidget);

        // Inventory Pills
        expect(find.text('Total Lot'), findsOneWidget);
        expect(find.text('100 MT'), findsOneWidget);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('75 MT'), findsOneWidget);

        // Pricing & Terms
        expect(find.textContaining('5,850'), findsOneWidget);
        expect(find.text('Payment on Delivery (CAD)'), findsOneWidget);
        expect(
          find.text('Krishi Upaj Mandi Yard Warehouse A-4'),
          findsOneWidget,
        );
        expect(find.text('Bikaner Commercial Head Office'), findsOneWidget);
        expect(find.text('AGMARK-RAL-2026-9021'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders assigned broker desk with mediated communication actions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: CommodityDetailsScreen(
              commodityId: testCommodity.id,
              initialCommodity: testCommodity,
            ),
          ),
        );

        expect(find.text('Mandi Broker Desk'), findsOneWidget);
        expect(find.text('Bikaner Mandi Broker Desk'), findsOneWidget);
        expect(find.text('Call Broker'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
        expect(find.textContaining('Counterparty Shield'), findsOneWidget);
      },
    );

    testWidgets(
      'Active lot displays management actions (Price edit, Fulfill, Cancel)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: CommodityDetailsScreen(
              commodityId: testCommodity.id,
              initialCommodity: testCommodity,
            ),
          ),
        );

        expect(find.text('Update Asking Price'), findsOneWidget);
        expect(find.text('Mark as Fulfilled / Dispatched'), findsOneWidget);
        expect(find.text('Withdraw / Cancel Lot'), findsOneWidget);
      },
    );
  });
}
