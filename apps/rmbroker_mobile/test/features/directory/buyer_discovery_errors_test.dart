import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/buyer_discovery_sheet.dart';

/// Answers every request with [status]/[body], or fails with no response.
class _Adapter implements HttpClientAdapter {
  final int? status;
  final Object? body;
  RequestOptions? last;

  _Adapter({this.status, this.body});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? _) async {
    last = options;
    if (status == null) {
      throw DioException.connectionError(requestOptions: options, reason: 'refused');
    }
    return ResponseBody.fromString(
      body is String ? body as String : jsonEncode(body),
      status!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DirectoryRepository _repo(_Adapter adapter) {
  final storage = SecureStorageService();
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter;
  return DirectoryRepository(apiClient: ApiClient(storage: storage, customDio: dio), storage: storage);
}

/// Each search completes only when the test says so.
class _ManualRepo extends DirectoryRepository {
  final calls = <String, Completer<DirectoryDataResult<List<DiscoverableBuyer>>>>{};

  @override
  Future<DirectoryDataResult<List<DiscoverableBuyer>>> discoverBuyers({
    required String search,
    String? categoryId,
  }) =>
      (calls[search] = Completer()).future;

  @override
  Future<List<InterestedCategory>> getCategories() async => const [];

  @override
  Future<DirectoryDataResult<DirectoryListPayload>> getContacts({
    String? role,
    String? search,
    String? status,
    String? categoryId,
    int? limit,
    String? cursor,
  }) async =>
      const DirectorySuccess(DirectoryListPayload(contacts: []));
}

DiscoverableBuyer _buyer(String company) =>
    DiscoverableBuyer(userId: company, name: 'Asha', companyName: company);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('sends the query to the discover endpoint and parses matches', () async {
    final adapter = _Adapter(status: 200, body: {
      'success': true,
      'data': [
        {'userId': 'u1', 'name': 'Nilesh', 'companyName': 'Nilesh Agro', 'interestedCategories': []},
      ],
    });
    final result = await _repo(adapter).discoverBuyers(search: ' niles ');
    expect(adapter.last!.path, '/broker/directory/discover');
    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.queryParameters['search'], 'niles');
    expect((result as DirectorySuccess<List<DiscoverableBuyer>>).data.single.companyName, 'Nilesh Agro');
  });

  test('empty response is a success, not an error', () async {
    final result = await _repo(_Adapter(status: 200, body: {'success': true, 'data': []}))
        .discoverBuyers(search: 'nobody');
    expect((result as DirectorySuccess<List<DiscoverableBuyer>>).data, isEmpty);
  });

  test('no response is the only connection failure', () async {
    final result = await _repo(_Adapter()).discoverBuyers(search: 'niles');
    final error = result as DirectoryError;
    expect(error.code, 'network');
    expect(error.message, contains('Could not reach'));
  });

  test('401 is reported as a session problem', () async {
    final result = await _repo(_Adapter(status: 401, body: {'success': false, 'error': 'x'}))
        .discoverBuyers(search: 'niles');
    expect(result, isA<DirectoryUnauthorized<List<DiscoverableBuyer>>>());
  });

  for (final status in [403, 404, 500]) {
    test('HTTP $status is not labelled as unreachable', () async {
      final result = await _repo(_Adapter(status: status, body: {'success': false, 'error': 'secret detail'}))
          .discoverBuyers(search: 'niles');
      final error = result as DirectoryError;
      expect(error.code, 'http_$status');
      expect(error.message, isNot(contains('Could not reach')));
      expect(error.message, isNot(contains('secret detail')));
    });
  }

  test('a 200 that is not the expected JSON is not labelled as unreachable', () async {
    final result = await _repo(_Adapter(status: 200, body: '"<html>"')).discoverBuyers(search: 'niles');
    expect((result as DirectoryError).message, contains('unexpected response'));
  });

  testWidgets('an older response never overwrites a newer search', (tester) async {
    final repo = _ManualRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [directoryRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: Scaffold(body: BuyerDiscoverySheet())),
      ),
    );
    final field = find.byKey(const Key('buyer_discovery_search'));

    await tester.enterText(field, 'old');
    await tester.pump(DirectoryController.searchDebounce);
    await tester.enterText(field, 'new');
    // The old answer arrives while the new search is still debouncing.
    repo.calls['old']!.complete(DirectorySuccess([_buyer('Old Co')]));
    await tester.pump();
    expect(find.text('Old Co'), findsNothing);

    await tester.pump(DirectoryController.searchDebounce);
    repo.calls['new']!.complete(DirectorySuccess([_buyer('New Co')]));
    await tester.pump();
    expect(find.text('New Co'), findsOneWidget);
    expect(find.text('Old Co'), findsNothing);
  });

  testWidgets('empty shows No buyers found; a failure offers Retry that searches again', (tester) async {
    final repo = _ManualRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [directoryRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: Scaffold(body: BuyerDiscoverySheet())),
      ),
    );
    await tester.enterText(find.byKey(const Key('buyer_discovery_search')), 'niles');
    await tester.pump(DirectoryController.searchDebounce);
    expect(find.text('No buyers found.'), findsNothing, reason: 'not before an answer');

    repo.calls['niles']!.complete(const DirectoryError(message: 'Could not reach', code: 'network'));
    await tester.pump();
    expect(find.text('No buyers found.'), findsNothing);

    await tester.tap(find.byKey(const Key('buyer_discovery_retry')));
    await tester.pump();
    repo.calls['niles']!.complete(const DirectorySuccess([]));
    await tester.pump();
    expect(find.text('No buyers found.'), findsOneWidget);
  });
}
