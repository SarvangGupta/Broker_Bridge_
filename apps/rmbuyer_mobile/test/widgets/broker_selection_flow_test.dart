import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/search/data/search_repository.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';
import 'package:rmbuyer_mobile/features/search/presentation/broker_profile_screen.dart';
import 'package:rmbuyer_mobile/features/search/presentation/brokers_screen.dart';

class _FakeRepo extends SearchRepository {
  final List<BrokerModel> brokers;
  _FakeRepo(this.brokers) : super(client: null);

  @override
  Future<List<BrokerModel>> searchBrokers({required String query, String? commodityFilter}) async =>
      brokers;

  @override
  Future<BrokerModel?> getBrokerById(String id) async {
    for (final b in brokers) {
      if (b.id == id) return b;
    }
    return null;
  }
}

void main() {
  // Shapes mirror live `users` rows: Varun has no company join, so no trust,
  // firm, location or commodity data; the second broker has a full company.
  final varun = BrokerModel.fromMap({
    'id': 'live-varun',
    'name': 'Varun',
    'mobile': '+919876500001',
  });
  final rbtest = BrokerModel.fromMap({
    'id': 'live-rbtest',
    'name': 'RBTEST-BROKER-B',
    'mobile': '+919876500002',
    'location': 'Indore Mandi, Madhya Pradesh',
    'commodities': ['Yellow Soybean', 'Wheat'],
    'companies': {
      'name': 'Indore Mandi Associates',
      'gst': '23AABCI5678B1Z2',
      'is_verified': true,
      'trust_score': 96,
    },
  });

  testWidgets('unverified company with default trust_score shows no trust badge',
      (tester) async {
    final demo = BrokerModel.fromMap({
      'id': 'live-demo',
      'name': 'Varun',
      'companies': {
        'name': 'Varun Agro Trading — DEMO',
        'is_verified': false,
        'trust_score': 100,
      },
    });
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: BrokerProfileScreen(brokerId: 'live-demo', initialBroker: demo),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Varun Agro Trading — DEMO'), findsNWidgets(2));
    expect(find.textContaining('Trust Score'), findsNothing);
    expect(find.text('Verified Licensed Broker'), findsNothing);
    expect(find.text('Not verified'), findsOneWidget);
  });

  GoRouter buildRouter(SearchRepository repo) => GoRouter(
        initialLocation: '/brokers',
        routes: [
          GoRoute(path: '/brokers', builder: (_, _) => BrokersScreen(searchRepository: repo)),
          GoRoute(
            path: '/brokers/:id',
            builder: (_, state) => BrokerProfileScreen(
              brokerId: state.pathParameters['id']!,
              initialBroker: state.extra as BrokerModel?,
              searchRepository: repo,
            ),
          ),
        ],
      );

  testWidgets('selected broker data propagates; switching brokers shows no stale data',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final router = buildRouter(_FakeRepo([varun, rbtest]));
    await tester.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();

    // Directory: no invented trust score or commodities for Varun
    expect(find.text('Varun'), findsOneWidget);
    expect(find.textContaining('100%'), findsNothing);
    expect(find.text('Trust Score: 96%'), findsOneWidget);

    // Open Varun
    await tester.tap(find.text('Varun'));
    await tester.pumpAndSettle();
    expect(find.text('Broker Profile'), findsOneWidget);
    expect(router.state.uri.path, '/brokers/live-varun');
    // Heading + Contact Person row
    expect(find.text('Varun'), findsNWidgets(2));
    expect(find.textContaining('Trust Score'), findsNothing);
    expect(find.text('Indore Mandi Associates'), findsNothing);
    expect(find.text('No commodities listed for this broker yet.'), findsOneWidget);
    expect(find.byKey(const Key('broker-call')), findsOneWidget);

    // Back, then open the other broker
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('RBTEST-BROKER-B'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/brokers/live-rbtest');
    expect(find.text('RBTEST-BROKER-B'), findsNWidgets(2));
    expect(find.text('Varun'), findsNothing);
    expect(find.text('Trust Score: 96%'), findsOneWidget);
    expect(find.text('Indore Mandi Associates'), findsNWidgets(2));
    expect(find.text('23AABCI5678B1Z2'), findsOneWidget);
    expect(find.text('Yellow Soybean'), findsOneWidget);
    // Badge + Verification Status row
    expect(find.text('Verified Broker'), findsNWidgets(2));
  });

  testWidgets('deep link without extra loads the broker by id', (tester) async {
    final router = buildRouter(_FakeRepo([varun, rbtest]));
    router.go('/brokers/live-rbtest');
    await tester.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('RBTEST-BROKER-B'), findsNWidgets(2));
    expect(find.text('Trust Score: 96%'), findsOneWidget);
  });
}
