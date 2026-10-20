import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/search/data/search_repository.dart';
import 'package:rmbuyer_mobile/features/search/domain/search_model.dart';

void main() {
  group('SearchRepository Isolation & Filtering Tests', () {
    test('search returns matching commodities and brokers safely', () async {
      final repo = SearchRepository();

      final soybeanResults = await repo.search(query: 'Soybean');
      expect(soybeanResults.isNotEmpty, isTrue);
      expect(soybeanResults.any((item) => item.title.contains('Soybean')), isTrue);
      expect(soybeanResults.any((item) => item.category == SearchCategory.commodities), isTrue);

      final brokerResults = await repo.search(query: 'Jaipur');
      expect(brokerResults.isNotEmpty, isTrue);
      expect(brokerResults.any((item) => item.title.contains('Jaipur')), isTrue);
      expect(brokerResults.any((item) => item.category == SearchCategory.brokers), isTrue);
    });

    test('search results never expose seller records or seller categories', () async {
      final repo = SearchRepository();
      final results = await repo.search(query: 'seller');

      for (final item in results) {
        expect(item.category, isNot(equals('seller')));
        expect(item.subtitle.toLowerCase(), isNot(contains('seller phone')));
        expect(item.subtitle.toLowerCase(), isNot(contains('seller whatsapp')));
      }
    });

    test('empty query returns empty list without errors', () async {
      final repo = SearchRepository();
      final results = await repo.search(query: '   ');
      expect(results, isEmpty);
    });
  });
}
