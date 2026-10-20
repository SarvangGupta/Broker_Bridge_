import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/search/data/search_repository.dart';
import 'package:rmbuyer_mobile/features/search/domain/search_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Testable subclass of SearchRepository providing mock responses for Supabase queries.
class TestableSearchRepository extends SearchRepository {
  List<Map<String, dynamic>>? mockBrokerRows;
  List<Map<String, dynamic>>? mockCommodityRows;
  Duration? searchDelay;
  bool brokerSearchCalled = false;
  bool commoditySearchCalled = false;

  TestableSearchRepository({
    this.mockBrokerRows,
    this.mockCommodityRows,
    this.searchDelay,
  }) : super(client: SupabaseClient('http://localhost:54321', 'fake-anon-key'));

  @override
  Future<List<Map<String, dynamic>>> performBrokerSearch(
    SupabaseClient client,
    String query,
  ) async {
    brokerSearchCalled = true;
    if (searchDelay != null) {
      await Future.delayed(searchDelay!);
    }
    return mockBrokerRows ?? [];
  }

  @override
  Future<List<Map<String, dynamic>>> performCommoditySearch(
    SupabaseClient client,
    String query,
  ) async {
    commoditySearchCalled = true;
    if (searchDelay != null) {
      await Future.delayed(searchDelay!);
    }
    return mockCommodityRows ?? [];
  }
}

void main() {
  group('RB-BUYER-02: SearchRepository Broker & Discovery Tests', () {
    test('Scenario 3 & 4: search returns authorized commodities and brokers with verified contracts', () async {
      final repo = TestableSearchRepository(
        mockCommodityRows: [
          {
            'id': 'comm-test-1',
            'name': 'Yellow Soybean',
            'code': 'SOY-A',
            'status': true,
          },
        ],
        mockBrokerRows: [
          {
            'id': 'broker-test-1',
            'name': 'Rajesh Verma',
            'role': 'broker',
            'mobile': '+919829012345',
            'email': 'rajesh@jaipurmandi.com',
            'location': 'Jaipur Mandi',
            'commodities': ['Yellow Soybean', 'Desi Chana'],
            'companies': {
              'id': 'comp-test-1',
              'name': 'Jaipur Grain Broker Desk',
              'gst': '08AAACJ1234A1Z1',
              'trust_score': 98,
              'is_verified': true,
            },
          },
        ],
      );

      final results = await repo.search(query: 'soybean');

      expect(results.length, 2);

      // Verify Commodity Result
      final commodityItem = results.firstWhere((r) => r.isCommodity);
      expect(commodityItem.title, 'Yellow Soybean');
      expect(commodityItem.subtitle, contains('SOY-A'));

      // Verify Broker Result
      final brokerItem = results.firstWhere((r) => r.isBroker);
      expect(brokerItem.title, 'Jaipur Grain Broker Desk');
      expect(brokerItem.broker, isNotNull);
      expect(brokerItem.broker!.name, 'Rajesh Verma');
      expect(brokerItem.broker!.companyName, 'Jaipur Grain Broker Desk');
      expect(brokerItem.broker!.trustScore, 98);
      expect(brokerItem.broker!.isVerified, isTrue);
    });

    test('Scenario 5: Empty search query returns empty list without issuing invalid requests', () async {
      final repo = TestableSearchRepository();

      final results = await repo.search(query: '');
      final whitespaceResults = await repo.search(query: '   ');

      expect(results, isEmpty);
      expect(whitespaceResults, isEmpty);
      expect(repo.brokerSearchCalled, isFalse);
      expect(repo.commoditySearchCalled, isFalse);
    });

    test('Scenario 6: No matching broker returns empty list', () async {
      final repo = TestableSearchRepository(
        mockBrokerRows: [],
        mockCommodityRows: [],
      );

      final results = await repo.search(
        query: 'xyznonexistentcommoditybroker999',
        category: SearchCategory.brokers,
      );

      expect(results, isEmpty);
    });

    test('Scenario 8: Request sequence tracking discards stale out-of-order responses', () async {
      // Simulates slow initial query ('soy') superseded by fast second query ('wheat')
      final repo = SearchRepository();

      // Launch slow request
      final slowSearchFuture = repo.search(query: 'soybean');

      // Immediate second search before first completes
      final fastSearchFuture = repo.search(query: 'wheat');

      final fastResults = await fastSearchFuture;
      final slowResults = await slowSearchFuture;

      expect(fastResults, isNotEmpty);
      // The obsolete request is discarded because sequence counter was bumped
      expect(slowResults, isEmpty);
    });

    test('Scenario 9: getBrokerById retrieves verified broker desk details', () async {
      final repo = SearchRepository();

      final broker = await repo.getBrokerById('b354958e-779a-41f2-b7a3-5899eca32e32');

      expect(broker, isNotNull);
      expect(broker!.name, contains('Varun'));
      expect(broker.companyName, 'Jaipur Grain Broker Desk');
      expect(broker.location, contains('Jaipur'));
      expect(broker.trustScore, 98);
      expect(broker.isVerified, isTrue);
      expect(broker.commoditiesHandled, contains('Soybean'));
    });

    test('searchBrokers applies commodity filter accurately', () async {
      final repo = SearchRepository();

      final soybeanBrokers = await repo.searchBrokers(
        query: '',
        commodityFilter: 'soybean',
      );

      for (final b in soybeanBrokers) {
        expect(
          b.commoditiesHandled.any((c) => c.toLowerCase().contains('soybean')),
          isTrue,
        );
      }
    });
  });
}
