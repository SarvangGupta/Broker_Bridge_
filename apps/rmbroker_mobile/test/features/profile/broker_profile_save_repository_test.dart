import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/profile/data/profile_repository.dart';
import 'package:rmbroker_mobile/features/profile/domain/broker_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_postgrest.dart';

// Plain test() only: testWidgets stubs HttpClient, which FakePostgrest needs.
const _userId = 'broker-test-202';

/// Unsigned JWT; gotrue only decodes `exp` locally.
String _sessionJson() {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  final token = '${b64({'alg': 'none'})}.'
      '${b64({'sub': _userId, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
  return jsonEncode({
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'refresh',
    'user': {
      'id': _userId,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-10-01T00:00:00Z',
    },
  });
}

BrokerProfile _edited() => BrokerProfile(
      id: _userId,
      role: 'BROKER',
      fullName: 'Mukesh Sharma',
      mobile: '9829098290',
      email: 'mukesh@sharmatrading.in',
      brokerageName: 'New Trade',
      legalName: 'NEW LEGAL',
      tradeName: 'New Trade',
      principalPlaceOfBusiness: 'New Address',
      city: 'Kota',
      state: 'Gujarat',
      pincode: '324001',
      operatingLocations: 'Kota, Alwar',
      updatedAt: DateTime(2026),
    );

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
    await storage.saveUserInfo(
      id: _userId,
      role: 'broker',
      email: 'mukesh@sharmatrading.in',
      fullName: 'Mukesh Sharma',
    );
  });

  group('updateProfile only succeeds once the database confirms', () {
    late FakePostgrest fake;

    Future<ProfileRepository> repoWith(
      Map<String, List<Map<String, dynamic>>> tables,
    ) async {
      fake = await FakePostgrest.start(tables);
      await fake.client.auth.setInitialSession(_sessionJson());
      addTearDown(fake.close);
      return ProfileRepository(supabase: fake.client, storage: storage);
    }

    Map<String, List<Map<String, dynamic>>> linked() => {
          'users': [
            {'id': _userId, 'name': 'Old', 'company_id': 'c1'},
          ],
          'companies': [
            {'id': 'c1', 'name': 'Old Co'},
          ],
        };

    Future<void> expectNothingCached() async => expect(
          await storage.getPreference('rb_cached_broker_profile'),
          isNull,
        );

    test('writes every edited field and survives a fresh reload', () async {
      final repo = await repoWith(linked());
      expect(await repo.updateProfile(_edited()),
          isA<ProfileSuccess<BrokerProfile>>());

      final live = fake.tables['companies']!.first['gst_live_data'] as Map;
      expect(live['legal_name'], 'NEW LEGAL');
      expect(live['trade_name'], 'New Trade');
      expect(live['principal_place_of_business'], 'New Address');
      expect(live['city'], 'Kota');
      expect(live['state'], 'Gujarat');
      expect(live['pincode'], '324001');
      expect(live['operating_locations'], 'Kota, Alwar');

      // The cache must not be what makes the reload correct.
      await storage.savePreference('rb_cached_broker_profile', '');
      final reloaded = await ProfileRepository(
        supabase: fake.client,
        storage: storage,
      ).getProfile();
      final data = (reloaded as ProfileSuccess<BrokerProfile>).data;
      expect(data.legalName, 'NEW LEGAL');
      expect(data.city, 'Kota');
      expect(data.pincode, '324001');
      expect(data.operatingLocations, 'Kota, Alwar');
    });

    test('company update matching zero rows (RLS) is a failure', () async {
      final tables = linked();
      final repo = await repoWith(tables);
      fake.beforePatch = (r) {
        if (r.table == 'companies') tables['companies']!.clear();
      };

      final result = await repo.updateProfile(_edited());
      expect(result, isA<ProfileError<BrokerProfile>>());
      expect((result as ProfileError<BrokerProfile>).message,
          contains('not saved'));
      await expectNothingCached();
    });

    test('database error is a failure and nothing is cached', () async {
      final repo = await repoWith(linked());
      fake.failWith = (r) => r.method == 'PATCH'
          ? (403, {'code': '42501', 'message': 'permission denied'})
          : null;

      final result = await repo.updateProfile(_edited());
      expect((result as ProfileError<BrokerProfile>).message,
          contains('permission'));
      await expectNothingCached();
    });

    test('duplicate value explains the conflict', () async {
      final repo = await repoWith(linked());
      fake.failWith = (r) => r.method == 'PATCH'
          ? (409, {'code': '23505', 'message': 'duplicate key'})
          : null;

      final result = await repo.updateProfile(_edited());
      expect((result as ProfileError<BrokerProfile>).message,
          contains('already used'));
    });

    test('network failure asks the user to check their connection', () async {
      // Nothing listens on this port.
      final client = SupabaseClient('http://127.0.0.1:1', 'test-anon-key');
      await client.auth.setInitialSession(_sessionJson());
      addTearDown(client.dispose);
      final repo = ProfileRepository(supabase: client, storage: storage);

      final result = await repo.updateProfile(_edited());
      expect((result as ProfileError<BrokerProfile>).message,
          contains('internet connection'));
      await expectNothingCached();
    });

    test('account without a company writes nothing', () async {
      final repo = await repoWith({
        'users': [
          {'id': _userId, 'company_id': null},
        ],
        'companies': [],
      });

      final result = await repo.updateProfile(_edited());
      expect((result as ProfileError<BrokerProfile>).message,
          contains('not linked'));
      expect(fake.writes(), isEmpty);
      await expectNothingCached();
    });

    test('no session is unauthorized, not a local save', () async {
      fake = await FakePostgrest.start(linked());
      addTearDown(fake.close);
      final repo = ProfileRepository(supabase: fake.client, storage: storage);

      expect(await repo.updateProfile(_edited()),
          isA<ProfileUnauthorized<BrokerProfile>>());
      expect(fake.writes(), isEmpty);
      await expectNothingCached();
    });
  });
}
