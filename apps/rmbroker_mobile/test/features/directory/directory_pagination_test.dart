import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_state.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'directory_repository_test.dart' show MockSecureStorageService;

String _uuid(int i) => '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';

/// PostgREST-shaped crm_contacts row (`timestamp` without zone, microseconds).
Map<String, dynamic> _row(
  int i, {
  String role = 'buyer',
  bool userActive = true,
  bool companyActive = true,
  String? name,
  String? createdAt,
}) => {
  'id': _uuid(i),
  'broker_id': 'broker-1',
  'user_id': 'u$i',
  'company_id': 'co$i',
  'created_at': createdAt ?? '2026-10-${(1 + i % 28).toString().padLeft(2, '0')}T10:00:${(i % 60).toString().padLeft(2, '0')}.${i.toString().padLeft(6, '0')}',
  'users': {
    'id': 'u$i',
    'name': name ?? 'Contact $i',
    'mobile': '+9198765${i.toString().padLeft(5, '0')}',
    'email': null,
    'role': role,
    'status': userActive,
  },
  'companies': {
    'id': 'co$i',
    'name': 'Company $i',
    'status': companyActive,
    'is_verified': false,
    'trust_score': 100,
    'district_id': null,
    'state_id': null,
  },
};

ApiClient _offlineApi() {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.reject(
          DioException(requestOptions: o, type: DioExceptionType.connectionError),
        ),
      ),
    );
  return ApiClient(storage: MockSecureStorageService(), customDio: dio);
}

/// Direct-Supabase path over an in-memory table that applies the same
/// semantics as the real query: role push-down, (created_at, id) keyset in
/// descending order, limit, and PostgREST's 1000-row response cap.
class _TableRepository extends DirectoryRepository {
  final List<Map<String, dynamic>> table;
  final Map<String, int> openRequirements;
  final List<({String? role, DirectoryCursor? after, int limit})> queries = [];
  int statsCalls = 0;

  _TableRepository(this.table, {this.openRequirements = const {}})
    : super(apiClient: _offlineApi(), storage: MockSecureStorageService());

  @override
  String? activeBrokerId() => 'broker-1';

  static int _order(Map<String, dynamic> a, Map<String, dynamic> b) {
    final byTime = (b['created_at'] as String).compareTo(a['created_at'] as String);
    return byTime != 0 ? byTime : (b['id'] as String).compareTo(a['id'] as String);
  }

  @override
  Future<List<Map<String, dynamic>>> queryContactRows(
    String brokerId, {
    String? role,
    DirectoryCursor? after,
    required int limit,
  }) async {
    queries.add((role: role, after: after, limit: limit));
    String? roleOf(Map<String, dynamic> r) => (r['users'] as Map)['role'] as String?;
    final rows = table.where((r) {
      final rRole = roleOf(r)?.toLowerCase();
      if (role == 'seller' && rRole != 'seller') return false;
      if (role == 'buyer' && rRole == 'seller') return false;
      if (after != null) {
        final t = r['created_at'] as String;
        final c = t.compareTo(after.createdAt);
        if (c > 0) return false;
        if (c == 0 && (r['id'] as String).compareTo(after.id) >= 0) return false;
      }
      return true;
    }).toList()..sort(_order);
    return rows.take(limit.clamp(0, 1000)).toList();
  }

  @override
  Future<MandateCounts> fetchMandateCounts(String brokerId, List<String> companyIds) async =>
      MandateCounts(requirements: {
        for (final id in companyIds)
          if (openRequirements.containsKey(id)) id: openRequirements[id]!,
      });

  @override
  Future<DirectorySummaryStats> fetchDirectoryStats(String brokerId) async {
    statsCalls++;
    final all = table.map((r) => DirectoryContact(
      id: r['id'] as String,
      userId: '',
      companyId: r['company_id'] as String,
      name: '',
      companyName: '',
      mobile: '',
      role: ContactRole.fromString((r['users'] as Map)['role'] as String?),
      status: ((r['users'] as Map)['status'] as bool) && ((r['companies'] as Map)['status'] as bool),
      createdAt: DateTime(2026),
    )).toList();
    return DirectorySummaryStats.fromContacts(all);
  }
}

/// Pages through the repository until the end; fails on a stuck cursor.
Future<List<String>> _pageAll(
  DirectoryRepository repo, {
  required int limit,
  String? role,
  String? status,
  String? search,
}) async {
  final ids = <String>[];
  String? cursor;
  for (var i = 0; i < 500; i++) {
    final result = await repo.getContacts(
      role: role,
      status: status,
      search: search,
      limit: limit,
      cursor: cursor,
    );
    final page = (result as DirectorySuccess<DirectoryListPayload>).data;
    ids.addAll(page.contacts.map((c) => c.id));
    if (!page.hasMore) return ids;
    expect(page.nextCursor, isNotNull);
    cursor = page.nextCursor;
  }
  fail('pagination did not terminate');
}

List<String> _expected(
  List<Map<String, dynamic>> table, {
  String? role,
  String? status,
  String? search,
}) {
  final rows = List.of(table)..sort(_TableRepository._order);
  return rows
      .map((r) => r['id'] as String)
      .where((id) {
        final r = table.firstWhere((x) => x['id'] == id);
        final u = r['users'] as Map;
        final c = r['companies'] as Map;
        final contact = DirectoryContact(
          id: id,
          userId: '',
          companyId: '',
          name: u['name'] as String,
          companyName: c['name'] as String,
          mobile: u['mobile'] as String,
          role: ContactRole.fromString(u['role'] as String?),
          status: (u['status'] as bool) && (c['status'] as bool),
          createdAt: DateTime(2026),
        );
        return contact.matchesFilters(role: role, status: status, search: search);
      })
      .toList();
}

/// API stub: answers by path with a JSON body and status, recording requests.
class _Api {
  final List<RequestOptions> requests = [];
  final (int, Object?) Function(RequestOptions o) respond;

  _Api(this.respond);

  ApiClient client() {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            requests.add(o);
            final (code, body) = respond(o);
            final response = Response(requestOptions: o, statusCode: code, data: body);
            if (code >= 200 && code < 300) {
              h.resolve(response);
            } else {
              h.reject(
                DioException(requestOptions: o, type: DioExceptionType.badResponse, response: response),
              );
            }
          },
        ),
      );
    return ApiClient(storage: MockSecureStorageService(), customDio: dio);
  }
}

class _ApiRepository extends DirectoryRepository {
  int directWrites = 0;
  _ApiRepository(ApiClient api) : super(apiClient: api, storage: MockSecureStorageService());

  @override
  String? activeBrokerId() => 'broker-1';

  @override
  Future<List<Map<String, dynamic>>> queryContactsByMobile(String brokerId, List<String> mobiles) async => [];

  @override
  Future<String> insertContactRecords(String brokerId, CreateContactInput input, String normalizedMobile) async {
    directWrites++;
    return 'direct-contact';
  }
}

Map<String, dynamic> _apiContact(int i, {String role = 'Buyer'}) => {
  'id': _uuid(i),
  'userId': 'u$i',
  'companyId': 'co$i',
  'name': 'Contact $i',
  'companyName': 'Company $i',
  'mobile': '+919876500000',
  'role': role,
  'status': true,
  'isVerified': false,
  'trustScore': 100,
  'createdAt': '2026-10-01T10:00:00.000Z',
};

const _createInput = CreateContactInput(
  name: 'Ramesh Agrawal',
  companyName: 'Malwa Agro Traders',
  mobile: '+919876543210',
  role: ContactRole.seller,
);

void main() {
  group('Cursor', () {
    test('round-trips and rejects malformed values', () {
      const c = DirectoryCursor('2026-10-01T10:00:00.123456', '00000000-0000-4000-8000-000000000001');
      expect(DirectoryCursor.tryParse(c.encode())?.encode(), c.encode());
      expect(DirectoryCursor.tryParse('2026-10-01 10:00:00.1|${_uuid(1)}'), isNotNull);
      expect(DirectoryCursor.tryParse(null), isNull);
      expect(DirectoryCursor.tryParse('garbage'), isNull);
      expect(DirectoryCursor.tryParse('2026-10-01T10:00:00|not-a-uuid'), isNull);
      expect(DirectoryCursor.tryParse('drop table|${_uuid(1)}'), isNull);
    });

    test('an invalid cursor is an error, not a silent restart', () async {
      final repo = _TableRepository([_row(1)]);
      final result = await repo.getContacts(limit: 5, cursor: 'nope');
      expect(result, isA<DirectoryError<DirectoryListPayload>>());
      expect(repo.queries, isEmpty);
    });
  });

  group('Direct path pagination', () {
    final table = [for (var i = 1; i <= 10; i++) _row(i, role: i.isEven ? 'seller' : 'buyer')];

    for (final limit in [1, 3, 4, 10, 11]) {
      test('limit $limit: pages concatenate to the full list, in order, no repeats', () async {
        final ids = await _pageAll(_TableRepository(table), limit: limit);
        expect(ids, _expected(table));
        expect(ids.toSet(), hasLength(ids.length));
      });
    }

    test('an exact multiple of the page size ends without an extra empty page', () async {
      final repo = _TableRepository([for (var i = 1; i <= 6; i++) _row(i)]);
      final first = (await repo.getContacts(limit: 3) as DirectorySuccess<DirectoryListPayload>).data;
      expect(first.contacts, hasLength(3));
      expect(first.hasMore, isTrue);
      final second = (await repo.getContacts(limit: 3, cursor: first.nextCursor)
              as DirectorySuccess<DirectoryListPayload>)
          .data;
      expect(second.contacts, hasLength(3));
      expect(second.hasMore, isFalse);
      expect(second.nextCursor, isNull);
    });

    test('rows sharing one created_at are split by id, never repeated or lost', () async {
      final same = [for (var i = 1; i <= 7; i++) _row(i, createdAt: '2026-10-05T09:00:00.000001')];
      final ids = await _pageAll(_TableRepository(same), limit: 2);
      expect(ids, _expected(same));
    });

    test('role tabs page only their own role (pushed down to the query)', () async {
      final repo = _TableRepository(table);
      expect(await _pageAll(repo, limit: 2, role: 'seller'), _expected(table, role: 'seller'));
      expect(repo.queries.every((q) => q.role == 'seller'), isTrue);
      expect(await _pageAll(_TableRepository(table), limit: 2, role: 'buyer'), _expected(table, role: 'buyer'));
    });

    test('status and search filters page without omissions across sparse matches', () async {
      final sparse = [
        for (var i = 1; i <= 40; i++)
          _row(i, userActive: i % 7 != 0, name: i % 9 == 0 ? 'Mittal $i' : null),
      ];
      expect(
        await _pageAll(_TableRepository(sparse), limit: 2, status: 'inactive'),
        _expected(sparse, status: 'inactive'),
      );
      expect(
        await _pageAll(_TableRepository(sparse), limit: 3, search: 'mittal'),
        _expected(sparse, search: 'mittal'),
      );
      expect(
        await _pageAll(_TableRepository(sparse), limit: 1, search: 'mittal', status: 'active'),
        _expected(sparse, search: 'mittal', status: 'active'),
      );
    });

    test('a contact added between pages does not shift or duplicate later pages', () async {
      final live = [for (var i = 1; i <= 6; i++) _row(i)];
      final repo = _TableRepository(live);
      final first = (await repo.getContacts(limit: 3) as DirectorySuccess<DirectoryListPayload>).data;
      live.add(_row(99, createdAt: '2026-12-31T23:59:59.000000')); // newest
      final second = (await repo.getContacts(limit: 3, cursor: first.nextCursor)
              as DirectorySuccess<DirectoryListPayload>)
          .data;
      final ids = [...first.contacts.map((c) => c.id), ...second.contacts.map((c) => c.id)];
      expect(ids, _expected([for (var i = 1; i <= 6; i++) _row(i)]));
    });

    test('stats cover all contacts and are fetched for the first page only', () async {
      final repo = _TableRepository(table);
      final first = (await repo.getContacts(limit: 3) as DirectorySuccess<DirectoryListPayload>).data;
      expect(first.stats?.totalContacts, 10);
      expect(first.stats?.sellersCount, 5);
      final second = (await repo.getContacts(limit: 3, cursor: first.nextCursor)
              as DirectorySuccess<DirectoryListPayload>)
          .data;
      expect(second.stats, isNull);
      expect(repo.statsCalls, 1);
    });

    test('mandate counts are attached per page', () async {
      final repo = _TableRepository(table, openRequirements: {'co10': 4});
      final page = (await repo.getContacts(limit: 1) as DirectorySuccess<DirectoryListPayload>).data;
      expect(page.contacts.single.companyId, 'co10');
      expect(page.contacts.single.openRequirementsCount, 4);
    });

    test('without a limit the full list is returned past the 1000-row response cap', () async {
      final big = [for (var i = 1; i <= 1201; i++) _row(i)];
      final repo = _TableRepository(big);
      final all = (await repo.getContacts(role: 'buyer', status: 'active') as DirectorySuccess<DirectoryListPayload>).data;
      expect(all.contacts, hasLength(1201));
      expect(all.hasMore, isFalse);
      expect(all.contacts.map((c) => c.id).toSet(), hasLength(1201));
    });
  });

  group('REST path', () {
    test('sends page parameters and parses pageInfo, stats and contacts', () async {
      final api = _Api((o) => (200, {
            'success': true,
            'data': {
              'contacts': [_apiContact(1), _apiContact(2, role: 'Seller')],
              'stats': {'totalContacts': 40, 'buyersCount': 30, 'sellersCount': 10, 'activeMandatesCount': 7},
              'pageInfo': {'hasMore': true, 'nextCursor': '2026-10-01 10:00:00.123456|${_uuid(2)}'},
            },
          }));
      final repo = _ApiRepository(api.client());
      final result = await repo.getContacts(role: 'seller', status: 'all', search: ' mit ', limit: 30);
      final page = (result as DirectorySuccess<DirectoryListPayload>).data;

      final q = api.requests.single.queryParameters;
      expect(api.requests.single.path, '/broker/directory');
      expect(q['role'], 'seller');
      expect(q['search'], 'mit');
      expect(q['limit'], 30);
      expect(q.containsKey('status'), isFalse);
      expect(q.containsKey('cursor'), isFalse);
      expect(page.contacts.map((c) => c.role), [ContactRole.buyer, ContactRole.seller]);
      expect(page.stats?.totalContacts, 40);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, '2026-10-01 10:00:00.123456|${_uuid(2)}');
    });

    test('a later page sends the cursor and carries no stats', () async {
      final api = _Api((o) => (200, {
            'success': true,
            'data': {
              'contacts': [_apiContact(3)],
              'pageInfo': {'hasMore': false, 'nextCursor': null},
            },
          }));
      final cursor = '2026-10-01 10:00:00.123456|${_uuid(2)}';
      final result = await _ApiRepository(api.client()).getContacts(limit: 30, cursor: cursor);
      final page = (result as DirectorySuccess<DirectoryListPayload>).data;
      expect(api.requests.single.queryParameters['cursor'], cursor);
      expect(page.stats, isNull);
      expect(page.hasMore, isFalse);
    });

    test('hasMore with an unusable cursor is treated as the end (no stuck loop)', () async {
      final api = _Api((o) => (200, {
            'success': true,
            'data': {'contacts': [_apiContact(1)], 'pageInfo': {'hasMore': true, 'nextCursor': 'bad'}},
          }));
      final page = ((await _ApiRepository(api.client()).getContacts(limit: 30))
              as DirectorySuccess<DirectoryListPayload>)
          .data;
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('a server without paging (no pageInfo) returns one complete page', () async {
      final api = _Api((o) => (200, {
            'success': true,
            'data': {'contacts': [_apiContact(1), _apiContact(2)]},
          }));
      final page = ((await _ApiRepository(api.client()).getContacts(limit: 30))
              as DirectorySuccess<DirectoryListPayload>)
          .data;
      expect(page.contacts, hasLength(2));
      expect(page.hasMore, isFalse);
      expect(page.stats?.totalContacts, 2);
    });

    test('401 from the list route is an unauthorized result', () async {
      final api = _Api((o) => (401, {'success': false, 'error': 'Unauthorized: Valid broker session required'}));
      expect(
        await _ApiRepository(api.client()).getContacts(limit: 30),
        isA<DirectoryUnauthorized<DirectoryListPayload>>(),
      );
    });

    test('create: 201 returns the server contact id without a second (direct) insert', () async {
      final api = _Api((o) => o.path == '/broker/directory' && o.method == 'POST'
          ? (201, {'success': true, 'contactId': 'server-contact'})
          : (200, {'isDuplicate': false}));
      final repo = _ApiRepository(api.client());
      final result = await repo.createContact(_createInput);
      expect((result as DirectorySuccess<String>).data, 'server-contact');
      expect(repo.directWrites, 0);
      final post = api.requests.firstWhere((o) => o.path == '/broker/directory');
      expect((post.data as Map)['role'], 'seller');
    });

    test('create: 409 duplicate keeps the duplicate flag and does not fall back', () async {
      final api = _Api((o) => o.path == '/broker/directory'
          ? (409, {'success': false, 'isDuplicate': true, 'error': 'A contact with mobile number +91 98765 43210 already exists'})
          : (200, {'isDuplicate': false}));
      final repo = _ApiRepository(api.client());
      final result = await repo.createContact(_createInput);
      final err = result as DirectoryError<String>;
      expect(err.isDuplicate, isTrue);
      expect(err.message, contains('already exists'));
      expect(repo.directWrites, 0);
    });

    test('create: duplicate reported by check-duplicate blocks the save', () async {
      final api = _Api((o) => (200, {
            'isDuplicate': true,
            'matchType': 'exact_mobile',
            'existingContact': {'companyName': 'Old Traders'},
          }));
      final repo = _ApiRepository(api.client());
      final err = await repo.createContact(_createInput) as DirectoryError<String>;
      expect(err.isDuplicate, isTrue);
      expect(api.requests.where((o) => o.path == '/broker/directory'), isEmpty);
    });

    test('create: a 400 validation error is shown as sent, not replaced', () async {
      final api = _Api((o) => o.path == '/broker/directory'
          ? (400, {'success': false, 'error': 'Company name must be at least 2 characters'})
          : (200, {'isDuplicate': false}));
      final err = await _ApiRepository(api.client()).createContact(_createInput) as DirectoryError<String>;
      expect(err.message, 'Company name must be at least 2 characters');
      expect(err.isDuplicate, isFalse);
    });

    test('update: success, and a 403 JSON error is reported (no direct fallback)', () async {
      const input = UpdateContactInput(
        name: 'Ramesh',
        companyName: 'Malwa Agro',
        mobile: '+919876543210',
        role: ContactRole.buyer,
      );
      final ok = _Api((o) => (200, {'success': true}));
      expect(await _ApiRepository(ok.client()).updateContact('c1', input), isA<DirectorySuccess<bool>>());
      expect(ok.requests.single.method, 'PUT');
      expect(ok.requests.single.path, '/broker/directory/c1');

      final denied = _Api((o) => (403, {'success': false, 'error': 'Unauthorized: You do not have permission to edit this contact'}));
      final err = await _ApiRepository(denied.client()).updateContact('c1', input) as DirectoryError<bool>;
      expect(err.message, contains('permission'));
    });

    test('status toggle calls the real PATCH …/status route', () async {
      final api = _Api((o) => (200, {'success': true, 'newStatus': false}));
      final result = await _ApiRepository(api.client()).toggleContactStatus('c1');
      expect((result as DirectorySuccess<bool>).data, isFalse);
      expect(api.requests.single.method, 'PATCH');
      expect(api.requests.single.path, '/broker/directory/c1/status');
    });

    test('details: UUID locations from the API never show as raw ids', () async {
      final api = _Api((o) => (200, {
            'success': true,
            'data': {
              'contact': {..._apiContact(1), 'city': _uuid(77), 'state': 'Rajasthan'},
              'associatedRequirements': [],
              'associatedOffers': [],
              'linkedDeals': [],
              'activities': [],
            },
          }));
      final details = await _ApiRepository(api.client()).getContactDetails(_uuid(1))
          as DirectorySuccess<ContactDetailsPayload>;
      expect(details.data.contact.locationLabel, 'Rajasthan');
    });
  });

  group('PostgREST query shape', () {
    late HttpServer server;
    final urls = <Uri>[];

    setUp(() async {
      urls.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        urls.add(req.uri);
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode([]))
          ..close();
      });
    });

    tearDown(() => server.close(force: true));

    test('keyset, role push-down and order are encoded as PostgREST parameters', () async {
      final repo = DirectoryRepository(
        apiClient: _offlineApi(),
        supabase: SupabaseClient('http://127.0.0.1:${server.port}', 'anon-key'),
        storage: MockSecureStorageService(),
      );
      await repo.queryContactRows(
        'broker-1',
        role: 'buyer',
        after: DirectoryCursor('2026-10-01T10:00:00.123456', _uuid(5)),
        limit: 31,
      );
      await repo.queryContactRows('broker-1', role: 'seller', limit: 31);

      final buyer = urls[0].queryParameters;
      expect(buyer['broker_id'], 'eq.broker-1');
      expect(buyer['users.or'], '(role.is.null,role.not.ilike.seller)');
      expect(
        buyer['or'],
        '(created_at.lt."2026-10-01T10:00:00.123456",and(created_at.eq."2026-10-01T10:00:00.123456",id.lt.${_uuid(5)}))',
      );
      expect(buyer['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      expect(buyer['limit'], '31');
      expect(buyer['select'], contains('users!user_id!inner('));

      final seller = urls[1].queryParameters;
      expect(seller['users.role'], 'ilike.seller');
      expect(seller.containsKey('or'), isFalse);
    });
  });

  group('Controller paging', () {
    ProviderContainer containerFor(DirectoryRepository repo) {
      final c = ProviderContainer(overrides: [directoryRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle(ProviderContainer c) async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('first page, then loadMore appends the rest exactly once', () async {
      final table = [for (var i = 1; i <= 65; i++) _row(i)];
      final c = containerFor(_TableRepository(table));
      c.read(directoryControllerProvider);
      await settle(c);
      var s = c.read(directoryControllerProvider);
      expect(s.allContacts, hasLength(DirectoryRepository.directoryPageSize));
      expect(s.hasMore, isTrue);
      expect(s.stats.totalContacts, 65);

      final ctrl = c.read(directoryControllerProvider.notifier);
      await ctrl.loadMore();
      await ctrl.loadMore();
      await ctrl.loadMore(); // at the end: no-op
      s = c.read(directoryControllerProvider);
      expect(s.allContacts.map((x) => x.id), _expected(table));
      expect(s.hasMore, isFalse);
      expect(s.stats.totalContacts, 65);
    });

    test('changing the tab reloads with the role filter; a stale response is dropped', () async {
      final table = [for (var i = 1; i <= 8; i++) _row(i, role: i.isEven ? 'seller' : 'buyer')];
      final repo = _SlowFirstRepository(table);
      final c = containerFor(repo);
      c.read(directoryControllerProvider); // first load (all) is held
      await settle(c);
      c.read(directoryControllerProvider.notifier).setActiveTab('seller');
      await settle(c);
      repo.release.complete(); // the stale "all" response arrives last
      await settle(c);
      final s = c.read(directoryControllerProvider);
      expect(s.allContacts.every((x) => x.role == ContactRole.seller), isTrue);
      expect(s.allContacts.map((x) => x.id), _expected(table, role: 'seller'));
      expect(repo.queries.any((q) => q.role == 'seller'), isTrue);
    });

    test('search reloads from the server after the debounce', () async {
      // The match is the oldest row: outside the first unfiltered page.
      final table = [
        for (var i = 1; i <= 40; i++)
          _row(i, name: i == 3 ? 'Sunil Mittal' : null, createdAt: i == 3 ? '2026-01-01T00:00:00.000000' : null),
      ];
      final repo = _TableRepository(table);
      final c = containerFor(repo);
      c.read(directoryControllerProvider);
      await settle(c);
      c.read(directoryControllerProvider.notifier).setSearchQuery('mittal');
      await Future<void>.delayed(DirectoryController.searchDebounce + const Duration(milliseconds: 50));
      await settle(c);
      final s = c.read(directoryControllerProvider);
      expect(s.filteredContacts.map((x) => x.id), [_uuid(3)]);
      expect(s.hasMore, isFalse);
    });

    test('a failed further page keeps the loaded list and offers retry', () async {
      final table = [for (var i = 1; i <= 40; i++) _row(i)];
      final repo = _FailingLaterPagesRepository(table);
      final c = containerFor(repo);
      c.read(directoryControllerProvider);
      await settle(c);
      await c.read(directoryControllerProvider.notifier).loadMore();
      var s = c.read(directoryControllerProvider);
      expect(s.allContacts, hasLength(DirectoryRepository.directoryPageSize));
      expect(s.loadMoreError, isNotNull);
      expect(s.status, DirectoryStatus.loaded);

      repo.failLater = false;
      await c.read(directoryControllerProvider.notifier).loadMore();
      s = c.read(directoryControllerProvider);
      expect(s.allContacts.map((x) => x.id), _expected(table));
      expect(s.loadMoreError, isNull);
    });
  });
}

class _SlowFirstRepository extends _TableRepository {
  final Completer<void> release = Completer<void>();
  var _first = true;
  _SlowFirstRepository(super.table);

  @override
  Future<List<Map<String, dynamic>>> queryContactRows(
    String brokerId, {
    String? role,
    DirectoryCursor? after,
    required int limit,
  }) async {
    if (_first) {
      _first = false;
      await release.future;
    }
    return super.queryContactRows(brokerId, role: role, after: after, limit: limit);
  }
}

class _FailingLaterPagesRepository extends _TableRepository {
  bool failLater = true;
  _FailingLaterPagesRepository(super.table);

  @override
  Future<List<Map<String, dynamic>>> queryContactRows(
    String brokerId, {
    String? role,
    DirectoryCursor? after,
    required int limit,
  }) async {
    if (after != null && failLater) throw const SocketException('offline');
    return super.queryContactRows(brokerId, role: role, after: after, limit: limit);
  }
}
