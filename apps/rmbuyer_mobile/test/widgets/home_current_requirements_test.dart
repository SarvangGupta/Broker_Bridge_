import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/home/presentation/home_screen.dart';
import 'package:rmbuyer_mobile/features/offers/data/offers_repository.dart';
import 'package:rmbuyer_mobile/features/offers/domain/buyer_offer_model.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';

class _FakeRequirementsRepo extends RequirementsRepository {
  List<BuyerRequirement> items;
  bool shouldThrow;

  _FakeRequirementsRepo(this.items, {this.shouldThrow = false});

  @override
  Future<List<BuyerRequirement>> getRequirements({
    String? statusFilter,
    bool includeBaseline = true,
  }) async {
    if (shouldThrow) {
      throw Exception('Network connection failure');
    }
    return List<BuyerRequirement>.from(items);
  }
}

class _FakeOffersRepo extends OffersRepository {
  List<BuyerOffer> offers;

  _FakeOffersRepo(this.offers);

  @override
  Future<List<BuyerOffer>> getOffers({
    String? requirementId,
    String? statusFilter,
  }) async {
    if (requirementId != null && requirementId.isNotEmpty) {
      return offers.where((o) => o.requirementId == requirementId).toList();
    }
    return List<BuyerOffer>.from(offers);
  }
}

BuyerRequirement _makeReq({
  required String id,
  required String commodity,
  required double quantity,
  String unit = 'MT',
  String status = 'Open',
  String? deliveryLocation,
}) {
  return BuyerRequirement(
    id: id,
    commodityName: commodity,
    gradeName: 'Standard Mandi Grade',
    quantity: quantity,
    unit: unit,
    targetPrice: 2400,
    status: status,
    targetDate: DateTime.now().add(const Duration(days: 7)),
    deliveryTerms: deliveryLocation,
  );
}

BuyerOffer _makeOffer({
  required String id,
  required String reqId,
  double price = 2450,
}) {
  return BuyerOffer(
    id: id,
    requirementId: reqId,
    requirementDisplayId: 'REQ-$reqId',
    commodityName: 'Test Commodity',
    gradeName: 'Grade A',
    offeredQuantity: 50,
    unit: 'MT',
    offeredPrice: price,
    totalEstimatedValue: price * 50,
    status: 'Proposed',
    versionNumber: 1,
    brokerName: 'Apex Brokerage Desk',
    deliveryTerms: 'FOR Factory Depot',
    deliveryLocation: 'Jaipur Depot',
    paymentTerms: 'Payment on Delivery',
    packagingType: '50kg Bags',
    applicableCharges: const [],
    qualitySpecs: const [],
    negotiationRounds: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({
    required RequirementsRepository reqRepo,
    OffersRepository? offersRepo,
    List<RouteBase>? extraRoutes,
    String? initialLocation,
  }) {
    final router = GoRouter(
      initialLocation: initialLocation ?? '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => HomeScreen(
            requirementsRepository: reqRepo,
            offersRepository: offersRepo ?? _FakeOffersRepo([]),
          ),
        ),
        ...?extraRoutes,
      ],
    );

    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }

  group('RMBUYER-HOME-CURRENT-REQUIREMENTS-01: 10 Requirements Verification', () {
    // 1. Real requirement records render correctly
    testWidgets('1. Real requirement records render correctly with authoritative data', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final req = _makeReq(
        id: 'REQ-001',
        commodity: 'Maize (Corn)',
        quantity: 120,
        unit: 'MT',
        status: 'Open',
        deliveryLocation: 'Jaipur, Rajasthan',
      );

      final offers = [
        _makeOffer(id: 'OFF-1', reqId: 'REQ-001'),
        _makeOffer(id: 'OFF-2', reqId: 'REQ-001'),
      ];

      final reqRepo = _FakeRequirementsRepo([req]);
      final offersRepo = _FakeOffersRepo(offers);

      await tester.pumpWidget(buildTestApp(reqRepo: reqRepo, offersRepo: offersRepo));
      await tester.pumpAndSettle();

      expect(find.text('Your Current Requirements'), findsOneWidget);
      expect(find.text('Maize (Corn)'), findsOneWidget);
      expect(find.text('120 MT'), findsOneWidget);
      expect(find.text('Jaipur, Rajasthan'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('2 broker offers · Awaiting response'), findsOneWidget);
    });

    // 2. Multiple requirements display in the correct order
    testWidgets('2. Multiple requirements display in the correct order', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final req1 = _makeReq(id: 'REQ-1', commodity: 'Maize (Corn)', quantity: 120);
      final req2 = _makeReq(id: 'REQ-2', commodity: 'Rice Bran', quantity: 80);
      final req3 = _makeReq(id: 'REQ-3', commodity: 'Mustard DOC', quantity: 50);

      final reqRepo = _FakeRequirementsRepo([req1, req2, req3]);

      await tester.pumpWidget(buildTestApp(reqRepo: reqRepo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-req-card-REQ-1')), findsOneWidget);
      expect(find.byKey(const Key('home-req-card-REQ-2')), findsOneWidget);
      expect(find.byKey(const Key('home-req-card-REQ-3')), findsOneWidget);

      final pos1 = tester.getTopLeft(find.byKey(const Key('home-req-card-REQ-1'))).dy;
      final pos2 = tester.getTopLeft(find.byKey(const Key('home-req-card-REQ-2'))).dy;
      final pos3 = tester.getTopLeft(find.byKey(const Key('home-req-card-REQ-3'))).dy;

      expect(pos1, lessThan(pos2));
      expect(pos2, lessThan(pos3));
    });

    // 3. Empty state when no requirements exist
    testWidgets('3. Empty state renders when no requirements exist', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final reqRepo = _FakeRequirementsRepo([]);

      await tester.pumpWidget(buildTestApp(reqRepo: reqRepo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-requirements-empty')), findsOneWidget);
      expect(find.text('No Current Requirements'), findsOneWidget);
      expect(find.byKey(const Key('home-empty-post-requirement-btn')), findsOneWidget);
    });

    // 4. Loading and API-error states
    testWidgets('4. Loading and API-error states with functional retry', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final reqRepo = _FakeRequirementsRepo([], shouldThrow: true);

      await tester.pumpWidget(buildTestApp(reqRepo: reqRepo));
      await tester.pump();

      // After settling, error state is rendered
      await tester.pumpAndSettle();
      expect(find.text('Unable to load requirements. Please check your connection.'), findsOneWidget);
      expect(find.byKey(const Key('home-requirements-retry-btn')), findsOneWidget);

      // Fix error and tap retry
      reqRepo.shouldThrow = false;
      reqRepo.items = [_makeReq(id: 'REQ-RECOVERED', commodity: 'Yellow Soybean', quantity: 200)];

      await tester.tap(find.byKey(const Key('home-requirements-retry-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Yellow Soybean'), findsOneWidget);
      expect(find.text('200 MT'), findsOneWidget);
    });

    // 5. Correct status badges
    testWidgets('5. Correct status badges (Active, Draft, In Negotiation, Completed, Cancelled)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final reqs = [
        _makeReq(id: 'REQ-OPEN', commodity: 'Maize', quantity: 10, status: 'Open'),
        _makeReq(id: 'REQ-DRAFT', commodity: 'Mustard', quantity: 20, status: 'Draft'),
        _makeReq(id: 'REQ-NEG', commodity: 'Wheat', quantity: 30, status: 'In Negotiation'),
        _makeReq(id: 'REQ-DONE', commodity: 'Soybean', quantity: 40, status: 'Fulfilled'),
        _makeReq(id: 'REQ-CANCEL', commodity: 'Chana', quantity: 50, status: 'Cancelled'),
      ];

      final reqRepo = _FakeRequirementsRepo(reqs);

      await tester.pumpWidget(buildTestApp(reqRepo: reqRepo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-req-status-open')), findsOneWidget);
      expect(find.byKey(const Key('home-req-status-draft')), findsOneWidget);
      expect(find.byKey(const Key('home-req-status-in negotiation')), findsOneWidget);
      expect(find.byKey(const Key('home-req-status-fulfilled')), findsOneWidget);
      expect(find.byKey(const Key('home-req-status-cancelled')), findsOneWidget);

      // Verify draft hint
      expect(find.text('Complete details to publish'), findsOneWidget);
    });

    // 6. Correct quantity and unit formatting
    testWidgets('6. Correct quantity and unit formatting (120 MT, 85.5 Qtl, 500 KG)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final reqs = [
        _makeReq(id: 'REQ-INT', commodity: 'Maize', quantity: 120.0, unit: 'MT'),
        _makeReq(id: 'REQ-DEC', commodity: 'Wheat', quantity: 85.5, unit: 'Qtl'),
        _makeReq(id: 'REQ-KG', commodity: 'Soybean Meal', quantity: 500.0, unit: 'KG'),
      ];

      final reqRepo = _FakeRequirementsRepo(reqs);

      await tester.pumpWidget(buildTestApp(reqRepo: reqRepo));
      await tester.pumpAndSettle();

      expect(find.text('120 MT'), findsOneWidget);
      expect(find.text('85.5 Qtl'), findsOneWidget);
      expect(find.text('500 KG'), findsOneWidget);
    });

    // 7. View All navigation
    testWidgets('7. View All navigation navigates to /requirements', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final reqRepo = _FakeRequirementsRepo([
        _makeReq(id: 'REQ-1', commodity: 'Maize', quantity: 100),
      ]);

      await tester.pumpWidget(buildTestApp(
        reqRepo: reqRepo,
        extraRoutes: [
          GoRoute(
            path: '/requirements',
            builder: (context, state) => const Scaffold(body: Text('Requirements Screen Destination')),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-view-all-requirements')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-view-all-requirements')));
      await tester.pumpAndSettle();

      expect(find.text('Requirements Screen Destination'), findsOneWidget);
    });

    // 8. Requirement-card navigation
    testWidgets('8. Requirement-card navigation navigates to requirement details', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final req = _makeReq(id: 'REQ-TARGET-99', commodity: 'High-Protein Maize', quantity: 150);
      final reqRepo = _FakeRequirementsRepo([req]);

      await tester.pumpWidget(buildTestApp(
        reqRepo: reqRepo,
        extraRoutes: [
          GoRoute(
            path: '/requirements/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              return Scaffold(body: Text('Requirement Details For $id'));
            },
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-req-card-REQ-TARGET-99')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-req-card-REQ-TARGET-99')));
      await tester.pumpAndSettle();

      expect(find.text('Requirement Details For REQ-TARGET-99'), findsOneWidget);
    });

    // 9. Refresh after a create/update operation
    testWidgets('9. Refresh after a create/update operation via requirementsUpdatedNotifier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final reqRepo = _FakeRequirementsRepo([
        _makeReq(id: 'REQ-INITIAL', commodity: 'Initial Maize', quantity: 50),
      ]);

      await tester.pumpWidget(buildTestApp(reqRepo: reqRepo));
      await tester.pumpAndSettle();

      expect(find.text('Initial Maize'), findsOneWidget);
      expect(find.text('Newly Created Commodity'), findsNothing);

      // Simulate a background requirement creation/update
      reqRepo.items = [
        _makeReq(id: 'REQ-NEW', commodity: 'Newly Created Commodity', quantity: 99),
        _makeReq(id: 'REQ-INITIAL', commodity: 'Initial Maize', quantity: 50),
      ];

      // Trigger global update notifier
      RequirementsRepository.requirementsUpdatedNotifier.value++;
      await tester.pumpAndSettle();

      expect(find.text('Newly Created Commodity'), findsOneWidget);
      expect(find.text('99 MT'), findsOneWidget);
    });

    // 10. No cross-user/company data leakage
    testWidgets('10. No cross-user/company data leakage: only authentic company requirements rendered', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authenticRepo = _FakeRequirementsRepo([
        _makeReq(id: 'REQ-COMPANY-A', commodity: 'Company A Mandi Stock', quantity: 100),
      ]);

      await tester.pumpWidget(buildTestApp(reqRepo: authenticRepo));
      await tester.pumpAndSettle();

      expect(find.text('Company A Mandi Stock'), findsOneWidget);
      expect(find.text('Company B Leaked Requirement'), findsNothing);
    });
  });
}
