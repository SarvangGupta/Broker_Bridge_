import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/search/data/search_repository.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';
import 'package:rmbuyer_mobile/features/search/presentation/brokers_screen.dart';

class _FakeRepo extends SearchRepository {
  final List<BrokerModel> brokers;
  bool fail;
  Completer<void>? gate;
  _FakeRepo(this.brokers, {this.fail = false}) : super(client: null);

  @override
  Future<List<BrokerModel>> searchBrokers({
    required String query,
    String? commodityFilter,
  }) async {
    if (gate != null) await gate!.future;
    if (fail) throw Exception('offline');
    return brokers;
  }
}

BrokerModel _b(
  String id,
  String name,
  String? location,
  List<String> commodities, {
  bool verified = false,
}) => BrokerModel(
  id: id,
  name: name,
  location: location,
  commoditiesHandled: commodities,
  isVerified: verified,
);

void main() {
  final brokers = [
    _b('1', 'Indore Desk A', 'Indore Mandi, Madhya Pradesh', [
      'Soybean',
    ], verified: true),
    _b('2', 'Indore Desk B', 'Indore Mandi, Madhya Pradesh', ['Wheat']),
    _b('3', 'Kota Agro', 'Kota Mandi, Rajasthan', ['Coriander']),
    _b('4', 'Bikaner Desk', 'Bikaner Mandi, Rajasthan', ['Guar Gum']),
    _b('5', 'Jaipur Desk', 'Jaipur Mandi, Rajasthan', [
      'Maize',
    ], verified: true),
    _b('6', 'Ujjain Desk', 'Ujjain Mandi, Madhya Pradesh', ['Chana']),
    _b('7', 'No Location Desk', null, ['Tur']),
  ];

  Future<void> pump(
    WidgetTester tester,
    SearchRepository repo, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(360, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BrokersScreen(searchRepository: repo),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('header, search hint and real-count chips; no Nearby chip', (
    tester,
  ) async {
    await pump(tester, _FakeRepo(brokers));
    expect(find.text('Mandi Brokers'), findsOneWidget);
    expect(
      find.text('Connect with trusted brokers for your procurement needs.'),
      findsOneWidget,
    );
    expect(
      find.text('Search by broker name, mandi or commodity...'),
      findsOneWidget,
    );
    expect(find.text('All Brokers (7)'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Nearby'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Verified chip shows only backend-verified brokers; All resets', (
    tester,
  ) async {
    await pump(tester, _FakeRepo(brokers));
    await tester.tap(find.byKey(const Key('filter-verified')));
    await tester.pumpAndSettle();
    expect(find.text('Indore Desk A'), findsOneWidget);
    expect(find.text('Jaipur Desk'), findsOneWidget);
    expect(find.text('Kota Agro'), findsNothing);
    expect(find.text('No Location Desk'), findsNothing);

    await tester.tap(find.byKey(const Key('filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Kota Agro'), findsOneWidget);
  });

  testWidgets('Filters lists every market and clears back to all', (
    tester,
  ) async {
    await pump(tester, _FakeRepo(brokers));
    await tester.tap(find.byKey(const Key('broker-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('Filter by location'), findsOneWidget);
    await tester.tap(find.text('Kota').last);
    await tester.pumpAndSettle();
    expect(find.text('Kota Agro'), findsOneWidget);
    expect(find.text('Indore Desk A'), findsNothing);

    await tester.tap(find.byKey(const Key('broker-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All locations'));
    await tester.pumpAndSettle();
    expect(find.text('Indore Desk A'), findsOneWidget);
  });

  testWidgets('search matches name, mandi and commodity', (tester) async {
    await pump(tester, _FakeRepo(brokers));
    final field = find.byType(TextField);

    await tester.enterText(field, 'coriander');
    await tester.pumpAndSettle();
    expect(find.text('Kota Agro'), findsOneWidget);
    expect(find.text('Indore Desk A'), findsNothing);

    await tester.enterText(field, 'bikaner');
    await tester.pumpAndSettle();
    expect(find.text('Bikaner Desk'), findsOneWidget);

    await tester.enterText(field, 'zzz');
    await tester.pumpAndSettle();
    expect(
      find.text('No brokers match your search or filters.'),
      findsOneWidget,
    );
  });

  testWidgets('loading, then empty state', (tester) async {
    final repo = _FakeRepo(const [])..gate = Completer<void>();
    await pump(tester, repo, settle: false);
    await tester.pump();
    expect(find.text('Loading verified broker desks...'), findsOneWidget);
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('No authorized brokers currently listed.'),
      findsOneWidget,
    );
  });

  testWidgets('load failure shows retry', (tester) async {
    final repo = _FakeRepo(brokers, fail: true);
    await pump(tester, repo);
    expect(
      find.text('Unable to load broker desks. Please check your connection.'),
      findsOneWidget,
    );

    repo.fail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Kota Agro'), findsOneWidget);
  });
}
