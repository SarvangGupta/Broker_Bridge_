import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbroker_mobile/app/theme/app_theme.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/broadcast/data/broadcast_history_repository.dart';
import 'package:rmbroker_mobile/features/broadcast/domain/broadcast_history_models.dart';
import 'package:rmbroker_mobile/features/broadcast/domain/market_broadcast_models.dart';
import 'package:rmbroker_mobile/features/broadcast/presentation/broadcast_detail_screen.dart';
import 'package:rmbroker_mobile/features/broadcast/presentation/broadcast_history_screen.dart';

class MockAuthorizedAuthRepo extends AuthRepository {
  final String brokerId;
  final String role;
  MockAuthorizedAuthRepo({this.brokerId = 'broker-demo-user', this.role = 'broker'});

  @override
  Future<BrokerUser?> getCurrentBroker() async {
    return BrokerUser(
      id: brokerId,
      email: 'varun@brokerbridge.in',
      fullName: 'Varun Broker Desk',
      role: role,
      companyId: 'comp-varun-01',
    );
  }
}

class MockUnauthorizedAuthRepo extends AuthRepository {
  @override
  Future<BrokerUser?> getCurrentBroker() async {
    return const BrokerUser(
      id: 'buyer-user-01',
      email: 'buyer@sharma.in',
      fullName: 'Sunil Sharma',
      role: 'buyer', // Not a broker or admin!
      companyId: 'comp-sharma-01',
    );
  }
}

void main() {
  setUp(() async {
    final storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
  });

  group('BB-MARKET-05: BroadcastHistoryRepository Unit & Security Tests', () {
    test('Rejects access when user is not an authorized broker', () async {
      final unauthRepo = MockUnauthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: unauthRepo);
      historyRepo.enableMemoryFallbackForTesting();

      expect(
        () => historyRepo.getBroadcastHistory(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Unauthorized'),
        )),
      );
    });

    test('Loads seeded historical records for authorized broker', () async {
      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      final history = await historyRepo.getBroadcastHistory();
      expect(history, isNotEmpty);
      expect(history.length, 3);

      // Verify tenant broker ID
      for (final item in history) {
        expect(item.brokerId, 'broker-demo-user');
      }
    });

    test('Same-day price changes preserve separate immutable records with correct timestamps', () async {
      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      final history = await historyRepo.getBroadcastHistory();

      // Find the two same-day broadcasts
      final bc1 = history.firstWhere((h) => h.id == 'BC-2026-1023-001'); // Morning: ₹5,450
      final bc2 = history.firstWhere((h) => h.id == 'BC-2026-1023-002'); // Afternoon: ₹5,480

      expect(bc1.sentAt.isBefore(bc2.sentAt), isTrue);

      final mustardOffer1 = bc1.priceSnapshots.firstWhere((o) => o.commodityName.contains('Mustard'));
      final mustardOffer2 = bc2.priceSnapshots.firstWhere((o) => o.commodityName.contains('Mustard'));

      expect(mustardOffer1.askingPrice, 5450.0);
      expect(mustardOffer1.version, 1);

      expect(mustardOffer2.askingPrice, 5480.0);
      expect(mustardOffer2.version, 2);

      // Verify that bc1 was NOT overwritten by bc2
      expect(bc1.priceSnapshots.first.askingPrice, isNot(bc2.priceSnapshots.first.askingPrice));
    });

    test('Recipient-level records accurately associate individual prices, status & failure reasons', () async {
      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      final history = await historyRepo.getBroadcastHistory();
      final pastBroadcast = history.firstWhere((h) => h.id == 'BC-2026-1020-001');

      expect(pastBroadcast.totalRecipients, 3);
      expect(pastBroadcast.successfulCount, 2);
      expect(pastBroadcast.failedCount, 1);
      expect(pastBroadcast.hasFailure, isTrue);

      final failedRecipient = pastBroadcast.recipients.firstWhere((r) => r.deliveryStatus == BroadcastDeliveryStatus.failed);
      expect(failedRecipient.buyerName, 'Gaurav Khandelwal');
      expect(failedRecipient.failureReason, isNotNull);
      expect(failedRecipient.failureReason, contains('expired'));

      final readRecipient = pastBroadcast.recipients.firstWhere((r) => r.deliveryStatus == BroadcastDeliveryStatus.read);
      expect(readRecipient.readAt, isNotNull);
    });

    test('Filter by Date Range: Today returns only broadcasts sent today', () async {
      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      final todayFiltered = await historyRepo.getBroadcastHistory(
        filter: const BroadcastHistoryFilter(dateFilter: HistoryDateFilter.today),
      );

      expect(todayFiltered.length, 2); // bc1 and bc2 are today
      for (final item in todayFiltered) {
        expect(item.id.contains('1023'), isTrue);
      }
    });

    test('Filter by Commodity: returns only broadcasts containing specified raw material', () async {
      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      final chanaFiltered = await historyRepo.getBroadcastHistory(
        filter: const BroadcastHistoryFilter(commodity: 'Chana (Gram Desi)'),
      );

      expect(chanaFiltered.length, 1);
      expect(chanaFiltered.first.id, 'BC-2026-1020-001');
      expect(chanaFiltered.first.commodityNames, contains('Chana (Gram Desi)'));
    });

    test('Filter by Price Range: returns broadcasts falling within min and max price', () async {
      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      // Only Chana is above 6000
      final highPriceFiltered = await historyRepo.getBroadcastHistory(
        filter: const BroadcastHistoryFilter(minPrice: 6000.0),
      );

      expect(highPriceFiltered.length, 1);
      expect(highPriceFiltered.first.id, 'BC-2026-1020-001');
      expect(highPriceFiltered.first.priceSnapshots.first.askingPrice, 6100.0);
    });

    test('Filter by Delivery Status: failed status returns broadcasts with failure count > 0', () async {
      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      final failedOnly = await historyRepo.getBroadcastHistory(
        filter: const BroadcastHistoryFilter(status: BroadcastDeliveryStatus.failed),
      );

      expect(failedOnly.length, 1);
      expect(failedOnly.first.id, 'BC-2026-1020-001');
      expect(failedOnly.first.failedCount, 1);
    });

    test('Search query matches across ID, commodity, seller, and buyer names', () async {
      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      // Search by buyer name 'Krishna'
      final searchBuyer = await historyRepo.getBroadcastHistory(
        filter: const BroadcastHistoryFilter(searchQuery: 'Krishna'),
      );
      expect(searchBuyer.length, 2);

      // Search by lot number
      final searchLot = await historyRepo.getBroadcastHistory(
        filter: const BroadcastHistoryFilter(searchQuery: 'CHN-2026-015'),
      );
      expect(searchLot.length, 1);
    });

    test('Recording a newly sent broadcast prepends it immediately to history', () async {
      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      // The seeded fixture includes broadcasts at fixed times *today* (09:30,
      // 14:45). Before 14:45 a `DateTime.now()` send is older than one of them
      // and correctly sorts below it, so stamp the new send after every seeded
      // record instead of depending on the clock.
      final seeded = await historyRepo.getBroadcastHistory();
      final latestSeeded = seeded
          .map((b) => b.sentAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final now = latestSeeded.add(const Duration(minutes: 1));
      final newOffer = SellerOfferPriceRevision(
        offerId: 'off-wht-01',
        lotNumber: 'LOT-WHT-001',
        sellerCompanyId: 'comp-sel-wht',
        sellerCompanyName: 'Punjab Wheat Mandi',
        commodityId: 'comm-wht-01',
        commodityName: 'Wheat (Sharbati)',
        gradeId: 'grd-wht-sup',
        gradeName: 'Superfine',
        askingPrice: 2850.0,
        unitSymbol: 'Qtl',
        availableQuantity: 100.0,
        location: 'Khanna Mandi, Punjab',
        version: 1,
        priceUpdatedAt: now,
      );

      final newItem = BroadcastHistoryItem(
        id: 'BC-2026-NEW-001',
        brokerId: 'broker-demo-user',
        brokerName: 'Varun Broker Desk',
        brokerageName: 'Varun Desk',
        sentAt: now,
        totalRecipients: 1,
        successfulCount: 1,
        failedCount: 0,
        priceSnapshots: [newOffer],
        recipients: [
          BroadcastRecipientDetail(
            recipientUserId: 'usr-buyer-01',
            buyerName: 'Sunil Sharma',
            companyName: 'Sharma Agro',
            mobile: '+91 98290 11223',
            deliveryStatus: BroadcastDeliveryStatus.sent,
            sentAt: now,
            items: [RecipientOfferSnapshot.fromRevision(newOffer)],
          ),
        ],
        fullMessage: 'TEST MESSAGE',
      );

      await historyRepo.recordBroadcast(newItem);

      final updated = await historyRepo.getBroadcastHistory();
      expect(updated.length, 4);
      expect(updated.first.id, 'BC-2026-NEW-001');
      expect(updated.first.commodityNames, contains('Wheat (Sharbati)'));
    });
  });

  group('BB-MARKET-05: Broadcast History Presentation Widgets Tests', () {
    testWidgets('BroadcastHistoryScreen renders title, search, date presets, and broadcast list cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            broadcastHistoryRepositoryProvider.overrideWithValue(historyRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const BroadcastHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Actions
      expect(find.text('Broadcast Price History'), findsOneWidget);
      expect(find.byIcon(LucideIcons.slidersHorizontal), findsOneWidget);

      // Verify Quick Date Chips
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Last 7 Days'), findsOneWidget);
      expect(find.text('Last 30 Days'), findsOneWidget);

      // Verify Broadcast Cards Rendered
      expect(find.text('BC-2026-1023-001'), findsOneWidget);
      expect(find.text('BC-2026-1023-002'), findsOneWidget);
      expect(find.text('BC-2026-1020-001'), findsOneWidget);

      // Verify Commodities and Prices
      expect(find.textContaining('Mustard Seed (Sarson)'), findsWidgets);
      expect(find.text('₹5,480'), findsOneWidget);
      expect(find.text('₹5,450'), findsOneWidget);
      expect(find.text('4 Associated Buyers'), findsWidgets);
    });

    testWidgets('Tapping Date Preset filters list reactively', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            broadcastHistoryRepositoryProvider.overrideWithValue(historyRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const BroadcastHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Today' chip
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Today should show the two 1023 broadcasts, but exclude the past 1020 broadcast
      expect(find.text('BC-2026-1023-001'), findsOneWidget);
      expect(find.text('BC-2026-1023-002'), findsOneWidget);
      expect(find.text('BC-2026-1020-001'), findsNothing);
    });

    testWidgets('BroadcastDetailScreen renders immutable price snapshot, recipient outcomes, and message text',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authRepo = MockAuthorizedAuthRepo();
      final historyRepo = BroadcastHistoryRepository(authRepo: authRepo);
      historyRepo.enableMemoryFallbackForTesting();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            broadcastHistoryRepositoryProvider.overrideWithValue(historyRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const BroadcastDetailScreen(broadcastId: 'BC-2026-1023-001'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title & Overview Card
      expect(find.text('Broadcast Details'), findsOneWidget);
      expect(find.text('BC-2026-1023-001'), findsOneWidget);
      expect(find.text('Varun Commodity Broker Desk'), findsOneWidget);

      // Verify Committed Price Snapshot
      expect(find.text('Committed Price Snapshot'), findsOneWidget);
      expect(find.text('Mustard Seed (Sarson)'), findsOneWidget);
      expect(find.text('₹5,450'), findsOneWidget);
      expect(find.text('Revision v1'), findsWidgets);

      // Verify Recipients Section
      expect(find.text('Recipients & Delivery Outcomes (4)'), findsOneWidget);
      expect(find.text('Sunil Sharma'), findsOneWidget);
      expect(find.text('Sharma Agro Mills Ltd • +91 98290 11223'), findsOneWidget);

      // Verify Standard Message Snapshot
      expect(find.text('Standard Message Text Snapshot'), findsOneWidget);
      expect(find.text('Exact Sent Message'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });
  });
}
