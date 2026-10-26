import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/negotiation/data/negotiation_repository.dart';
import 'package:rmseller_mobile/features/negotiation/presentation/broker_communication_screen.dart';

void main() {
  group('RB-SELLER-03: BrokerCommunicationScreen Widget Tests', () {
    late SecureStorageService storage;

    final testCommodity = SellerCommodity(
      id: 'AVL-TEST-CHANA-01',
      lotNumber: 'LOT-CHANA-01',
      commodityName: 'Desi Chana (Gram)',
      gradeName: 'Bold Size FAQ',
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
      createdAt: DateTime.now(),
    );

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
      NegotiationRepository.clearSessionCache();
    });

    Widget createScreen() {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: BrokerCommunicationScreen(
          requestId: testCommodity.id,
          brokerId: testCommodity.brokerId!,
          brokerName: testCommodity.brokerName,
          brokerPhone: testCommodity.brokerPhone,
          brokerLocation: testCommodity.brokerLocation,
          commodityContext:
              '${testCommodity.name} • ${testCommodity.quantityTotal} ${testCommodity.unit}',
          commodity: testCommodity,
        ),
      );
    }

    testWidgets('Renders compact header, short tabs and mediated bar', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Bikaner Mandi Broker Desk'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Trust'), findsOneWidget);
      expect(find.byTooltip('Call Broker'), findsOneWidget);
      expect(find.byKey(const Key('broker_chat_menu')), findsOneWidget);

      // Short tab labels
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Broker Chat'), findsNothing);
      expect(find.text('Commission Terms'), findsNothing);

      expect(find.textContaining('Broker-mediated trading'), findsOneWidget);

      // Composer pinned at the bottom
      expect(find.byKey(const Key('broker_chat_input')), findsOneWidget);
      expect(find.byKey(const Key('broker_chat_send')), findsOneWidget);
    });

    testWidgets('WhatsApp remains available from the header menu', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      await tester.tap(find.byKey(const Key('broker_chat_menu')));
      await tester.pumpAndSettle();
      expect(find.text('WhatsApp Broker'), findsOneWidget);
    });

    testWidgets('Chat input accepts a message', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      final inputFinder = find.byKey(const Key('broker_chat_input'));
      await tester.enterText(
        inputFinder,
        'Broker Ji, dispatch is ready for tomorrow morning.',
      );
      await tester.pump();

      expect(
        find.text('Broker Ji, dispatch is ready for tomorrow morning.'),
        findsOneWidget,
      );
    });

    testWidgets('Terms tab shows status, offer action and Offer History', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      await tester.tap(find.text('Terms'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terms_status_card')), findsOneWidget);
      expect(find.text('Offer History'), findsOneWidget);
      expect(find.text('Negotiation History & Audit Trail'), findsNothing);
      expect(find.text('Current Active Proposal'), findsNothing);
      expect(find.byKey(const Key('terms_send_offer_button')), findsOneWidget);
    });

    testWidgets('Send Offer opens the existing proposal form', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      await tester.tap(find.text('Terms'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('terms_send_offer_button')));
      await tester.pumpAndSettle();

      expect(find.text('Proposed Commission Rate *'), findsOneWidget);
      expect(find.text('Commission Calculation Basis *'), findsOneWidget);
      expect(find.text('Submit Proposal to Broker'), findsOneWidget);
    });

    testWidgets('No overflow on a 320dp screen in either tab', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terms'));
      await tester.pumpAndSettle();

      // Any RenderFlex overflow is reported by the framework and fails here.
      expect(find.byKey(const Key('terms_status_card')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Offer History'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Offer History'), findsOneWidget);
    });
  });
}
