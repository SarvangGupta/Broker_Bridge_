// RB-SELLER-QUICK-POST-01: server-side business-profile readiness through the
// real SellerProfileRepository (users → companies) against a loopback PostgREST.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';

import '../support/fake_postgrest.dart';

const _seller = '7c000000-0000-4000-8000-000000000001';
const _company = '20000000-0000-4000-8000-0000000000c1';

String _jwt(String sub) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none', 'typ': 'JWT'})}.'
      '${b64({'sub': sub, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

void main() {
  late FakePostgrest fake;
  late SellerProfileRepository repo;

  Future<void> start(Map<String, List<Map<String, dynamic>>> tables, {bool signIn = true}) async {
    fake = await FakePostgrest.start(tables);
    if (signIn) {
      await fake.client.auth.setInitialSession(
        jsonEncode({
          'access_token': _jwt(_seller),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'r',
          'user': {
            'id': _seller,
            'aud': 'authenticated',
            'app_metadata': {'role': 'seller'},
            'user_metadata': <String, dynamic>{},
            'created_at': '2026-10-01T00:00:00Z',
          },
        }),
      );
    }
    repo = SellerProfileRepository(
      supabase: fake.client,
      storage: SecureStorageService()..enableMemoryFallbackForTesting(),
    );
  }

  tearDown(() => fake.close());

  test('complete: linked firm with a name; region carried for defaults', () async {
    await start({
      'users': [
        {'id': _seller, 'company_id': _company},
      ],
      'companies': [
        {'id': _company, 'name': 'Shiv Agro', 'gst': null, 'state_id': 'S-1', 'district_id': 'D-1'},
      ],
    });
    final r = await repo.checkListingReadiness();
    expect(r.status, ListingReadinessStatus.complete);
    expect(r.firmName, 'Shiv Agro');
    expect(r.companyStateId, 'S-1');
    expect(r.companyDistrictId, 'D-1');
  });

  test('complete: individual seller without a firm', () async {
    await start({
      'users': [
        {'id': _seller, 'company_id': null, 'name': 'Bikaner Kisan Trader', 'role': 'seller'},
      ],
    });
    final r = await repo.checkListingReadiness();
    expect(r.status, ListingReadinessStatus.complete);
    expect(r.firmName, 'Bikaner Kisan Trader');
  });

  test('incomplete: account not provisioned in users table', () async {
    await start({
      'users': [],
    });
    fake.failWith = (r) {
      if (r.table == 'provision_individual_seller') {
        return (500, {'message': 'RPC error'});
      }
      return null;
    };
    final r = await repo.checkListingReadiness();
    expect(r.status, ListingReadinessStatus.incomplete);
    expect(r.missing.single, contains('not yet provisioned'));
  });

  test('incomplete: account has unauthorized non-seller role', () async {
    await start({
      'users': [
        {'id': _seller, 'company_id': null, 'role': 'buyer'},
      ],
    });
    final r = await repo.checkListingReadiness();
    expect(r.status, ListingReadinessStatus.incomplete);
    expect(r.missing.single, contains('does not have active seller permissions'));
  });

  test('incomplete: firm record not readable / missing', () async {
    await start({
      'users': [
        {'id': _seller, 'company_id': _company},
      ],
      'companies': [],
    });
    final r = await repo.checkListingReadiness();
    expect(r.status, ListingReadinessStatus.incomplete);
    expect(r.missing.single, contains('could not be found'));
  });

  test('server error is "unable to verify", never "incomplete"', () async {
    await start({'users': []});
    fake.failWith = (r) => (500, {'code': 'XX000', 'message': 'down'});
    final r = await repo.checkListingReadiness();
    expect(r.status, ListingReadinessStatus.unverified);
    expect(r.missing, isEmpty);
  });

  test('no session is "unable to verify"', () async {
    await start({'users': []}, signIn: false);
    final r = await repo.checkListingReadiness();
    expect(r.status, ListingReadinessStatus.unverified);
    expect(r.error, contains('sign in'));
    expect(fake.requests, isEmpty);
  });
}
