import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    Widget buildScreen() => MaterialApp(
      theme: AppTheme.lightTheme,
      home: CommodityDetailsScreen(
        commodityId: testCommodity.id,
        initialCommodity: testCommodity,
      ),
    );

    Future<void> tapSection(WidgetTester tester, String title) async {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    // RB-SELLER-PRICE-SYNC-FIX-01: this lot is not saved anywhere, so the
    // update cannot be confirmed and must not be reported as done.
    testWidgets('an unconfirmed price update shows an error and keeps the price', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final action = find.byKey(const Key('lot_action_update_price'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        '6100',
      );
      await tester.tap(find.text('Save Price'));
      // The repository waits up to 500 ms for the stored company id.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.textContaining('updated to'), findsNothing);
      expect(find.textContaining('cannot be updated'), findsOneWidget);

      await tapSection(tester, 'Inventory & Asking Price');
      expect(find.textContaining('5,850'), findsOneWidget);
      expect(find.textContaining('6,100'), findsNothing);
    });

    // RB-SELLER-POST-INTEGRITY-02: Fulfil / Withdraw are shown only when the
    // server confirms; this lot is saved nowhere, so both must fail visibly.
    for (final (key, button) in [
      ('lot_action_fulfill', 'Fulfill'),
      ('lot_action_withdraw', 'Cancel'),
    ]) {
      testWidgets('unconfirmed $button shows an error with Retry, lot unchanged', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final action = find.byKey(Key(key));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, button));
        // The repository waits up to 500 ms for the stored company id.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        expect(find.textContaining('Lot status updated'), findsNothing);
        expect(find.textContaining('cannot be changed'), findsOneWidget);
        expect(find.widgetWithText(SnackBarAction, 'Retry'), findsOneWidget);
        // Still active: the management actions are still offered.
        expect(find.byKey(Key(key)), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });
    }

    testWidgets(
      'Renders summary card and inventory; pricing and dispatch expand on tap',
      (tester) async {
        await tester.pumpWidget(buildScreen());

        expect(find.text('LOT-CHANA-01'), findsAtLeastNWidgets(1));
        expect(find.text('Desi Chana (Gram)'), findsOneWidget);
        expect(find.text('Bold Size FAQ (Count 60-65)'), findsOneWidget);
        expect(find.text('Ready to Load'), findsOneWidget);

        // Inventory summary visible while collapsed
        expect(find.text('Inventory & Asking Price'), findsOneWidget);
        expect(find.text('Total Lot'), findsOneWidget);
        expect(find.text('100 MT'), findsOneWidget);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('75 MT'), findsOneWidget);
        expect(find.textContaining('5,850'), findsNothing);
        expect(find.text('Bikaner Commercial Head Office'), findsNothing);

        await tapSection(tester, 'Inventory & Asking Price');
        expect(find.textContaining('5,850'), findsOneWidget);
        expect(find.text('Payment on Delivery (CAD)'), findsOneWidget);

        await tapSection(tester, 'Dispatch & Warehouse Location');
        expect(
          find.text('Krishi Upaj Mandi Yard Warehouse A-4'),
          findsAtLeastNWidgets(1),
        );
        expect(find.text('Bikaner Commercial Head Office'), findsOneWidget);
        expect(find.text('AGMARK-RAL-2026-9021'), findsOneWidget);

        await tapSection(tester, 'Dispatch & Warehouse Location');
        expect(find.text('Bikaner Commercial Head Office'), findsNothing);
      },
    );

    testWidgets('Quality Document section is collapsible', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('Quality Document'), findsOneWidget);
      expect(find.text('Quality & Assay Document'), findsNothing);
      expect(find.text('Certificate Reference'), findsNothing);

      await tapSection(tester, 'Quality Document');
      expect(find.text('Certificate Reference'), findsOneWidget);
    });

    testWidgets(
      'Broker card uses broker name heading and icon-only contact actions',
      (tester) async {
        await tester.pumpWidget(buildScreen());

        expect(find.text('My Trusted Broker'), findsNothing);
        expect(find.text('Bikaner Mandi Broker Desk'), findsOneWidget);
        expect(find.text('Licensed Broker'), findsOneWidget);
        expect(find.textContaining('Counterparty Shield'), findsNothing);
        expect(find.byKey(const Key('lot_broker_call')), findsOneWidget);
        expect(find.byKey(const Key('lot_broker_whatsapp')), findsOneWidget);
        expect(find.byKey(const Key('lot_broker_chat')), findsOneWidget);
        expect(find.byTooltip('Call Broker'), findsOneWidget);
        expect(find.text('Change Broker'), findsOneWidget);
      },
    );

    testWidgets(
      'Active lot shows Update Price, Mark Fulfilled, Withdraw Lot in one row',
      (tester) async {
        await tester.pumpWidget(buildScreen());

        final labels = ['Update Price', 'Mark Fulfilled', 'Withdraw Lot'];
        for (final label in labels) {
          expect(find.text(label), findsOneWidget);
        }
        final y = tester.getCenter(find.text(labels.first)).dy;
        for (final label in labels.skip(1)) {
          expect(tester.getCenter(find.text(label)).dy, closeTo(y, 1));
        }
      },
    );

    testWidgets('No overflow on a narrow 320dp screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildScreen());
      await tapSection(tester, 'Inventory & Asking Price');
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      // Any RenderFlex overflow is reported by the framework and fails here.
      expect(find.text('Withdraw Lot'), findsOneWidget);
    });
  });
}
