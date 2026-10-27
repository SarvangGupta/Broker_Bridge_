// RB-SELLER-INDIVIDUAL-ACCESS-FIX-01: a seller with no company (or no users
// row) signs in without a fabricated company id.
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmseller_mobile/features/authentication/domain/auth_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _ScriptedAuth extends AuthRepository {
  final Map<String, dynamic> userMetadata;
  final Map<String, dynamic>? profileRow;
  final Map<String, dynamic>? companyRow;

  _ScriptedAuth({
    required super.storage,
    required this.userMetadata,
    this.profileRow,
    this.companyRow,
  }) : super(supabase: SupabaseClient('http://127.0.0.1:9', 'test-anon-key'));

  @override
  Future<AuthResponse> performSignIn(SupabaseClient client, String email, String password) async {
    final user = User(
      id: '49534f2f-0000-4000-8000-000000000001',
      appMetadata: const {},
      userMetadata: userMetadata,
      aud: 'authenticated',
      email: email,
      createdAt: '2026-10-01T00:00:00Z',
    );
    return AuthResponse(
      session: Session(accessToken: 'token', tokenType: 'bearer', user: user),
      user: user,
    );
  }

  @override
  Future<Map<String, dynamic>?> performProfileLookup(SupabaseClient client, String userId) async =>
      profileRow;

  @override
  Future<Map<String, dynamic>?> performCompanyLookup(SupabaseClient client, String companyId) async =>
      companyRow;

  @override
  Future<void> performSignOut(SupabaseClient client) async {}
}

void main() {
  late SecureStorageService storage;

  setUp(() {
    storage = SecureStorageService()..enableMemoryFallbackForTesting();
  });

  test('unprovisioned seller (no users row) signs in with no company — none invented', () async {
    final repo = _ScriptedAuth(
      storage: storage,
      // Self-editable metadata: role accepted as before, company NOT trusted.
      userMetadata: {
        'role': 'seller',
        'name': 'Hari',
        'company_id': '20000000-0000-0000-0000-000000000999',
        'company_name': 'Shiv Shankar Pashu Aahar Udyog',
      },
    );
    final result = await repo.signInWithPassword(email: 's@test', password: 'x');
    expect(result, isA<AuthSuccess>());
    final user = (result as AuthSuccess).user;
    expect(user.companyId, isNull);
    expect(user.companyGst, isNull);
    expect(await storage.getCompanyId(), isNull);
    // The hard-coded demo company is never stored.
    expect(await storage.getCompanyId(), isNot('20000000-0000-0000-0000-000000000101'));
  });

  test('linked seller keeps the company from the users row', () async {
    final repo = _ScriptedAuth(
      storage: storage,
      userMetadata: const {'role': 'seller'},
      profileRow: {
        'id': '49534f2f-0000-4000-8000-000000000001',
        'role': 'seller',
        'name': 'Linked Seller',
        'company_id': '20000000-0000-4000-8000-0000000000c1',
      },
      companyRow: {'name': 'Real Firm', 'gst': '08ABCDE1234F1Z5', 'trust_score': 90, 'is_verified': true},
    );
    final result = await repo.signInWithPassword(email: 's@test', password: 'x');
    final user = (result as AuthSuccess).user;
    expect(user.companyId, '20000000-0000-4000-8000-0000000000c1');
    expect(user.companyName, 'Real Firm');
    expect(await storage.getCompanyId(), '20000000-0000-4000-8000-0000000000c1');
  });
}
