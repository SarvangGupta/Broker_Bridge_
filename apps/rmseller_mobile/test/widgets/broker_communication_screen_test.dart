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
          commodityContext: '${testCommodity.name} • ${testCommodity.quantityTotal} ${testCommodity.unit}',
          commodity: testCommodity,
        ),
      );
    }

    testWidgets('Renders broker header, tabs, and counterparty shield disclaimer', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      // Broker name and header
      expect(find.text('Bikaner Mandi Broker Desk'), findsOneWidget);
      expect(find.text('+919829012345'), findsOneWidget);

      // Counterparty shield badge/disclaimer
      expect(find.textContaining('Counterparty Shield'), findsAtLeastNWidgets(1));

      // Dual tab structure
      expect(find.text('Broker Chat'), findsOneWidget);
      expect(find.text('Commission Terms'), findsOneWidget);

      // Chat input bar
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Chat tab displays message input bar and quick communication info', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);

      // Enter message text
      await tester.enterText(inputFinder, 'Broker Ji, dispatch is ready for tomorrow morning.');
      await tester.pump();

      expect(find.text('Broker Ji, dispatch is ready for tomorrow morning.'), findsOneWidget);
    });

    testWidgets('Commission Terms tab renders status banner and proposal actions', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      // Tap on Commission Terms Tab
      await tester.tap(find.text('Commission Terms'));
      await tester.pumpAndSettle();

      // Status banner
      expect(find.textContaining('Commission Status'), findsOneWidget);

      // Propose Commission action button
      expect(find.textContaining('Propose Commission Terms'), findsOneWidget);
    });

    testWidgets('Tapping Propose Commission opens modal sheet with validation fields', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      // Go to Commission tab
      await tester.tap(find.text('Commission Terms'));
      await tester.pumpAndSettle();

      // Tap Propose Commission button
      await tester.tap(find.textContaining('Propose Commission Terms'));
      await tester.pumpAndSettle();

      // Modal bottom sheet should appear with proposal fields
      expect(find.text('Propose Broker Commission'), findsOneWidget);
      expect(find.text('Proposed Commission Rate *'), findsOneWidget);
      expect(find.text('Commission Calculation Basis *'), findsOneWidget);
      expect(find.text('₹/MT (Per Metric Ton)'), findsOneWidget);
      expect(find.text('Submit Proposal to Broker'), findsOneWidget);
    });
  });
}
