import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// RB-SELLER-WAREHOUSE-GPS-LIVE-01 — warehouse GPS server persistence (no network: every
/// server call goes through the repository's @visibleForTesting hooks).
const _uid = '7f3c1a2e-0000-4000-8000-00000000c0de';

Future<SupabaseClient> _signedInClient(Map<String, dynamic> userMetadata) async {
  final client = SupabaseClient('https://example.invalid', 'anon-key-for-tests');
  final exp = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
  String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final jwt = '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': _uid, 'exp': exp, 'role': 'authenticated'})}.sig';
  await client.auth.setInitialSession(jsonEncode({
    'access_token': jwt,
    'token_type': 'bearer',
    'expires_in': 86400,
    'expires_at': exp,
    'refresh_token': 'refresh',
    'user': {
      'id': _uid,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'warehouse.test@example.test',
      'app_metadata': <String, dynamic>{},
      'user_metadata': userMetadata,
      'created_at': '2026-01-01T00:00:00Z',
    },
  }));
  return client;
}

class _ServerStub extends SellerProfileRepository {
  final List<Map<String, dynamic>> metadataWrites = [];
  bool failMetadata;

  _ServerStub({required super.supabase, required super.storage, this.failMetadata = false});

  @override
  Future<Map<String, dynamic>?> performUserLookup(SupabaseClient client, String userId) async =>
      {'id': _uid, 'name': 'Warehouse Test Seller', 'mobile': '9000000001', 'role': 'seller', 'company_id': null};
  @override
  Future<Map<String, dynamic>?> performCompanyLookup(SupabaseClient client, String companyId) async => null;
  @override
  Future<void> performUserUpdate(SupabaseClient client, String userId, Map<String, dynamic> data) async {}
  @override
  Future<void> performCompanyUpdate(SupabaseClient client, String companyId, Map<String, dynamic> data) async {}
  @override
  Future<UserResponse?> performUpdateUserMetadata(SupabaseClient client, Map<String, dynamic> data) async {
    if (failMetadata && data.containsKey('default_warehouse')) throw Exception('simulated server error');
    metadataWrites.add(data);
    return UserResponse.fromJson({
      'id': _uid,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': data,
      'created_at': '2026-01-01T00:00:00Z',
    });
  }
}

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService()..enableMemoryFallbackForTesting();
    await storage.clearAll();
    await storage.saveUserInfo(id: _uid, role: 'seller', email: 'warehouse.test@example.test', fullName: 'Warehouse Test Seller');
  });

  test('9. save sends the confirmed latitude/longitude to the server', () async {
    final repo = _ServerStub(supabase: await _signedInClient({}), storage: storage);
    final p = await repo.getProfile();
    await repo.updateProfile(p.copyWith(
      businessLocation: p.businessLocation.copyWith(latitude: 26.912434, longitude: 75.787271, isGpsDetected: true),
    ));
    final wh = repo.metadataWrites.lastWhere((w) => w.containsKey('default_warehouse'))['default_warehouse'] as Map;
    expect(wh['latitude'], 26.912434);
    expect(wh['longitude'], 75.787271);
    expect(wh['is_gps_detected'], isTrue);
    expect(wh['address_line'], p.businessLocation.addressLine, reason: 'address sent unchanged');
    expect(wh['pin_code'], p.businessLocation.pinCode);
  });

  test('10. server failure → save throws (no false success), nothing cached as saved', () async {
    final repo = _ServerStub(supabase: await _signedInClient({}), storage: storage, failMetadata: true);
    final p = await repo.getProfile();
    await expectLater(
      repo.updateProfile(p.copyWith(
          businessLocation: p.businessLocation.copyWith(latitude: 26.9, longitude: 75.7, isGpsDetected: true))),
      throwsException,
    );
    expect(await storage.getPreference('business_location_lat'), anyOf(isNull, isEmpty));
  });

  test('11. reopen reads coordinates from the server copy (local cache empty)', () async {
    final serverWh = const BusinessLocationModel(
      addressLine: 'Godown 7, VKIA, Jaipur',
      pinCode: '302013',
      latitude: 26.912434,
      longitude: 75.787271,
      isGpsDetected: true,
    ).toMap();
    final repo = _ServerStub(supabase: await _signedInClient({'default_warehouse': serverWh}), storage: storage);
    expect(await storage.getPreference('business_location_lat'), isNull);
    final p = await repo.getProfile();
    expect(p.businessLocation.latitude, 26.912434);
    expect(p.businessLocation.longitude, 75.787271);
    expect(p.businessLocation.isGpsDetected, isTrue);
  });

  test('server copy wins over a stale local cache; no data → null, never a default city', () async {
    await storage.savePreference('business_location_lat', '28.0229');
    await storage.savePreference('business_location_lng', '73.3119');
    await storage.savePreference('business_location_gps', 'true');
    final cleared = const BusinessLocationModel(addressLine: 'x').toMap(); // server says: no GPS
    final repo = _ServerStub(supabase: await _signedInClient({'default_warehouse': cleared}), storage: storage);
    final p = await repo.getProfile();
    expect(p.businessLocation.latitude, isNull);
    expect(p.businessLocation.isGpsDetected, isFalse);

    await storage.clearAll();
    await storage.saveUserInfo(id: _uid, role: 'seller', email: 'w@example.test', fullName: 'W');
    final offline = SellerProfileRepository(storage: storage);
    final q = await offline.getProfile();
    expect(q.businessLocation.latitude, isNull, reason: 'no fabricated Bikaner fallback');
    expect(q.businessLocation.longitude, isNull);
  });

  test('Clear GPS is persisted only by the save: server gets null coordinates', () async {
    final repo = _ServerStub(supabase: await _signedInClient({}), storage: storage);
    final p = await repo.getProfile();
    final withGps = p.copyWith(
        businessLocation: p.businessLocation.copyWith(latitude: 26.9, longitude: 75.7, isGpsDetected: true));
    await repo.updateProfile(withGps);
    await repo.updateProfile(withGps.copyWith(businessLocation: withGps.businessLocation.copyWith(clearCoordinates: true)));
    final wh = repo.metadataWrites.lastWhere((w) => w.containsKey('default_warehouse'))['default_warehouse'] as Map;
    expect(wh['latitude'], isNull);
    expect(wh['longitude'], isNull);
    expect(wh['is_gps_detected'], isFalse);
    expect(await storage.getPreference('business_location_lat'), isEmpty);
  });

  test('model: no default coordinates; clearCoordinates resets confirmation', () {
    const m = BusinessLocationModel();
    expect(m.latitude, isNull);
    expect(BusinessLocationModel.fromMap(const {}).latitude, isNull);
    final c = m.copyWith(latitude: 1, longitude: 2, isGpsDetected: true).copyWith(clearCoordinates: true);
    expect(c.latitude, isNull);
    expect(c.isGpsDetected, isFalse);
  });
}
