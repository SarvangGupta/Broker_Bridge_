import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/search/data/search_repository.dart';

class MockSecureStorageService extends SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({required String key}) async => _storage[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }
}

void main() {
  group('SearchRepository Tests', () {
    late SearchRepository repository;
    late MockSecureStorageService mockStorage;

    setUp(() {
      mockStorage = MockSecureStorageService();
      repository = SearchRepository(
        storage: mockStorage,
      );
    });

    test('sanitizeQuery trims whitespace and removes control characters', () {
      expect(repository.sanitizeQuery('   soyabean \x00\x1F  '), 'soyabean');
      expect(repository.sanitizeQuery('mustard seed'), 'mustard seed');
    });

    test('searchGlobal with query < 2 chars returns empty results immediately', () async {
      final resEmpty = await repository.searchGlobal(query: '');
      expect(resEmpty.totalCount, 0);

      final resSingle = await repository.searchGlobal(query: 's');
      expect(resSingle.totalCount, 0);
    });

    test('searchGlobal returns SearchUnavailableException when REST and PostgREST are unmounted', () async {
      expect(
        () => repository.searchGlobal(query: 'soyabean'),
        throwsA(isA<SearchUnavailableException>()),
      );
    });

    test('addRecentSearch stores queries, deduplicates, and caps at max 8', () async {
      await repository.addRecentSearch('Soyabean');
      await repository.addRecentSearch('Mustard');
      await repository.addRecentSearch('Wheat');

      var recents = await repository.getRecentSearches();
      expect(recents, ['Wheat', 'Mustard', 'Soyabean']);

      // Deduplicate case-insensitively and move to front
      await repository.addRecentSearch('soyabean');
      recents = await repository.getRecentSearches();
      expect(recents.first, 'soyabean');
      expect(recents.where((e) => e.toLowerCase() == 'soyabean').length, 1);

      // Add more items up to capping limit (8)
      for (int i = 1; i <= 10; i++) {
        await repository.addRecentSearch('Query $i');
      }
      recents = await repository.getRecentSearches();
      expect(recents.length, 8);
      expect(recents.first, 'Query 10');
    });

    test('removeRecentSearch and clearRecentSearches operate reliably', () async {
      await repository.addRecentSearch('Item A');
      await repository.addRecentSearch('Item B');

      var recents = await repository.removeRecentSearch('Item A');
      expect(recents, ['Item B']);

      await repository.clearRecentSearches();
      recents = await repository.getRecentSearches();
      expect(recents, isEmpty);
    });
  });
}
