import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/brokers/data/seller_broker_repository.dart';
import 'package:rmseller_mobile/features/brokers/domain/seller_broker_model.dart';
import 'package:rmseller_mobile/features/deals/domain/seller_deal_model.dart';
import 'package:rmseller_mobile/features/deals/presentation/deal_details_screen.dart';

class _FakeBrokerRepository extends SellerBrokerRepository {
  final SellerBrokerModel? broker;
  _FakeBrokerRepository(this.broker);

  @override
  Future<SellerBrokerModel?> getBrokerById(String id) async =>
      broker?.id == id ? broker : null;
}

void main() {
  group('SELLER-DEAL-DETAILS-UI-01: DealDetailsScreen', () {
    final deal = SellerDealModel(
      id: 'deal-1',
      requirementId: 'req-1',
      quotationId: 'quo-1',
      commodityName: 'Yellow Soybean',
      gradeName: 'Grade A FAQ (Moisture < 10%)',
      agreedQuantity: 50.0,
      unit: 'MT',
      agreedPrice: 4850.0,
      status: 'Dispatch Pending',
      brokerDeskName: 'Jaipur Grain Broker Desk',
      brokerId: 'broker-1',
      bookingReference: 'BKG-2026-0881',
      createdAt: DateTime(2026, 10, 25, 15, 4),
      invoiceNo: 'INV-2026-0051',
      invoiceId: 'inv-51',
      invoiceAmount: 242500,
      invoiceStatus: 'Pending',
      vehicleNumber: 'RJ-14-EA-9081',
      dispatchDate: DateTime(2026, 10, 25, 21, 4),
      commissionRate: 35,
      commissionBasis: '₹/MT',
      commissionStatus: 'Agreed',
      commissionAmount: 1750,
      commissionPaid: 0,
      commissionOutstanding: 1750,
    );

    const broker = SellerBrokerModel(
      id: 'broker-1',
      name: 'Jaipur Grain Broker Desk',
      mobile: '+919876500001',
      location: 'Jaipur, Rajasthan',
      isVerified: true,
    );

    Widget buildScreen({SellerBrokerModel? withBroker = broker}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: DealDetailsScreen(
        dealId: deal.id,
        initialDeal: deal,
        brokerRepository: _FakeBrokerRepository(withBroker),
      ),
    );

    void useTallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(412, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('Shows compact summary, invoice, commission and logistics', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('BKG-2026-0881'), findsNWidgets(2)); // app bar + card
      expect(find.text('Yellow Soybean'), findsOneWidget);
      expect(find.text('₹242500'), findsNWidgets(2)); // total + invoice
      expect(find.text('INV-2026-0051'), findsOneWidget);
      expect(find.text('View Invoice'), findsOneWidget);

      // Commission is a summary only
      expect(find.text('Broker Commission'), findsOneWidget);
      expect(find.text('₹1750'), findsNWidgets(2)); // payable + outstanding
      expect(find.text('Outstanding Commission'), findsNothing);

      // Logistics summary
      expect(find.text('RJ-14-EA-9081'), findsOneWidget);

      // Single commission chat action, at the bottom
      expect(find.text('Chat with Commission Desk'), findsOneWidget);
      expect(find.text('Broker Chat & Commission Desk'), findsNothing);
    });

    testWidgets('Commission card opens the full breakdown page', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Broker Commission'));
      await tester.pumpAndSettle();

      expect(find.text('Commission Breakdown'), findsOneWidget);
      expect(find.text('Agreed Commission Rate'), findsOneWidget);
      expect(find.text('₹35 (₹/MT)'), findsOneWidget);
      expect(find.text('Outstanding Commission'), findsOneWidget);
    });

    testWidgets('Logistics card opens the logistics page', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Logistics & Vehicle Entry'));
      await tester.tap(find.text('Logistics & Vehicle Entry'));
      await tester.pumpAndSettle();

      expect(find.text('Dispatch Record'), findsOneWidget);
      expect(find.text('RJ-14-EA-9081'), findsOneWidget);
    });

    testWidgets('Broker contact icons use the real broker record', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Broker Details'), findsOneWidget);
      expect(find.text('Licensed Broker'), findsOneWidget);
      expect(find.text('Jaipur, Rajasthan'), findsOneWidget);
      expect(find.byTooltip('Call Broker'), findsOneWidget);
      expect(find.byTooltip('WhatsApp'), findsOneWidget);
      expect(find.byTooltip('Broker Chat'), findsOneWidget);
      expect(find.text('Rate Broker'), findsOneWidget);
    });

    testWidgets('Call and WhatsApp are disabled when no broker record exists', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(withBroker: null));
      await tester.pumpAndSettle();

      final call = tester.widget<IconButton>(
        find.byKey(const Key('deal_broker_call')),
      );
      final whatsapp = tester.widget<IconButton>(
        find.byKey(const Key('deal_broker_whatsapp')),
      );
      expect(call.onPressed, isNull);
      expect(whatsapp.onPressed, isNull);
      expect(find.text('Licensed Broker'), findsNothing);
    });

    testWidgets('No overflow on a 320dp screen; content scrolls above bottom bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final lastCardBottom = tester
          .getBottomLeft(find.byKey(const Key('deal_logistics_section')))
          .dy;
      final chatTop = tester
          .getTopLeft(find.byKey(const Key('deal_commission_chat_button')))
          .dy;
      expect(lastCardBottom, lessThanOrEqualTo(chatTop));
    });
  });
}
