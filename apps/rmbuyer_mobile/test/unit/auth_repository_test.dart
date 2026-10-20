import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/core/security/secure_storage_service.dart';
import 'package:rmbuyer_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbuyer_mobile/features/authentication/domain/auth_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory fake implementation of SecureStorageService for deterministic,
/// lightning-fast, and platform-channel-free security testing.
class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> saveToken(String token) async => _data['rmbuyer_access_token'] = token;

  @override
  Future<String?> getToken() async => _data['rmbuyer_access_token'];

  @override
  Future<void> saveRefreshToken(String token) async =>
      _data['rmbuyer_refresh_token'] = token;

  @override
  Future<String?> getRefreshToken() async => _data['rmbuyer_refresh_token'];

  @override
  Future<void> saveUserInfo({
    required String id,
    required String role,
    required String email,
    required String fullName,
    String? companyId,
    String? companyName,
  }) async {
    _data['rmbuyer_user_id'] = id;
    _data['rmbuyer_user_role'] = role;
    _data['rmbuyer_user_email'] = email;
    _data['rmbuyer_user_name'] = fullName;
    if (companyId != null) _data['rmbuyer_company_id'] = companyId;
    if (companyName != null) _data['rmbuyer_company_name'] = companyName;
  }

  @override
  Future<String?> getUserId() async => _data['rmbuyer_user_id'];

  @override
  Future<String?> getUserRole() async => _data['rmbuyer_user_role'];

  @override
  Future<String?> getUserEmail() async => _data['rmbuyer_user_email'];

  @override
  Future<String?> getUserName() async => _data['rmbuyer_user_name'];

  @override
  Future<String?> getCompanyId() async => _data['rmbuyer_company_id'];

  @override
  Future<String?> getCompanyName() async => _data['rmbuyer_company_name'];

  @override
  Future<void> clearAll() async => _data.clear();

  int get count => _data.length;
  bool containsKey(String key) => _data.containsKey(key);
}

/// Testable AuthRepository providing deterministic responses for Supabase Auth calls.
class TestableAuthRepository extends AuthRepository {
  AuthResponse? mockAuthResponse;
  Map<String, dynamic>? mockProfile;
  Map<String, dynamic>? mockCompany;
  Exception? mockAuthException;
  bool signOutCalled = false;
  Duration? delay;

  TestableAuthRepository({
    required FakeSecureStorageService fakeStorage,
    this.mockAuthResponse,
    this.mockProfile,
    this.mockCompany,
    this.mockAuthException,
    this.delay,
  }) : super(
          supabase: SupabaseClient('http://localhost:54321', 'fake-anon-key'),
          storage: fakeStorage,
        );

  @override
  Future<AuthResponse> performSignIn(
    SupabaseClient client,
    String email,
    String password,
  ) async {
    if (delay != null) {
      await Future.delayed(delay!);
    }
    if (mockAuthException != null) {
      throw mockAuthException!;
    }
    return mockAuthResponse!;
  }

  @override
  Future<Map<String, dynamic>?> performProfileLookup(
    SupabaseClient client,
    String userId,
  ) async {
    return mockProfile;
  }

  @override
  Future<Map<String, dynamic>?> performCompanyLookup(
    SupabaseClient client,
    String companyId,
  ) async {
    return mockCompany;
  }

  @override
  Future<void> performSignOut(SupabaseClient client) async {
    signOutCalled = true;
  }
}

User createMockUser({
  required String id,
  required String email,
  Map<String, dynamic>? appMetadata,
  Map<String, dynamic>? userMetadata,
}) {
  return User(
    id: id,
    appMetadata: appMetadata ?? {},
    userMetadata: userMetadata ?? {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    email: email,
  );
}

Session createMockSession({
  required User user,
  String accessToken = 'mock-access-token-jwt-secure',
  String refreshToken = 'mock-refresh-token-secure',
  int expiresIn = 3600,
}) {
  return Session(
    accessToken: accessToken,
    refreshToken: refreshToken,
    tokenType: 'bearer',
    user: user,
    expiresIn: expiresIn,
  );
}

void main() {
  group('RB-BUYER-01: AuthRepository Security & Account Access Tests', () {
    late FakeSecureStorageService fakeStorage;

    setUp(() {
      fakeStorage = FakeSecureStorageService();
    });

    test('Scenario 2: Valid, authorized buyer signs in successfully and credentials are encrypted', () async {
      final user = createMockUser(
        id: 'usr-buyer-01',
        email: 'buyer.procurement@apexgrain.com',
        appMetadata: {'role': 'buyer'},
        userMetadata: {'full_name': 'Rajesh Singhal'},
      );
      final session = createMockSession(user: user);

      final repo = TestableAuthRepository(
        fakeStorage: fakeStorage,
        mockAuthResponse: AuthResponse(session: session, user: user),
        mockProfile: {
          'id': 'usr-buyer-01',
          'role': 'buyer',
          'name': 'Rajesh Singhal',
          'company_id': 'comp-101',
        },
        mockCompany: {
          'id': 'comp-101',
          'name': 'Apex Grain Processors Pvt Ltd',
          'gst': '08AABCA1234F1Z8',
        },
      );

      final result = await repo.signInWithPassword(
        email: 'buyer.procurement@apexgrain.com',
        password: 'ValidSecurePass2026!',
      );

      expect(result, isA<AuthSuccess>());
      final success = result as AuthSuccess;
      expect(success.user.id, 'usr-buyer-01');
      expect(success.user.email, 'buyer.procurement@apexgrain.com');
      expect(success.user.role, 'buyer');
      expect(success.user.companyName, 'Apex Grain Processors Pvt Ltd');
      expect(success.user.companyGst, '08AABCA1234F1Z8');

      // Verify tokens stored securely in storage
      expect(await fakeStorage.getToken(), 'mock-access-token-jwt-secure');
      expect(await fakeStorage.getRefreshToken(), 'mock-refresh-token-secure');
      expect(await fakeStorage.getUserRole(), 'buyer');
      expect(await fakeStorage.getCompanyName(), 'Apex Grain Processors Pvt Ltd');
    });

    test('Scenario 2b: Admin account has authorized access to buyer workstation', () async {
      final user = createMockUser(
        id: 'usr-admin-01',
        email: 'admin@brokerbridge.com',
        appMetadata: {'role': 'admin'},
      );
      final session = createMockSession(user: user);

      final repo = TestableAuthRepository(
        fakeStorage: fakeStorage,
        mockAuthResponse: AuthResponse(session: session, user: user),
        mockProfile: {
          'id': 'usr-admin-01',
          'role': 'admin',
          'name': 'System Administrator',
        },
      );

      final result = await repo.signInWithPassword(
        email: 'admin@brokerbridge.com',
        password: 'AdminPassword2026!',
      );

      expect(result, isA<AuthSuccess>());
      expect((result as AuthSuccess).user.role, 'admin');
    });

    test('Scenario 3: Authenticated broker account is denied access, signs out, and wipes storage', () async {
      final user = createMockUser(
        id: 'usr-broker-02',
        email: 'broker@jaipurmandi.com',
        appMetadata: {'role': 'broker'},
      );
      final session = createMockSession(user: user);

      final repo = TestableAuthRepository(
        fakeStorage: fakeStorage,
        mockAuthResponse: AuthResponse(session: session, user: user),
        mockProfile: {
          'id': 'usr-broker-02',
          'role': 'broker',
          'name': 'Nilesh Sharma',
        },
      );

      final result = await repo.signInWithPassword(
        email: 'broker@jaipurmandi.com',
        password: 'BrokerPass2026!',
      );

      expect(result, isA<AuthAccessDenied>());
      final denied = result as AuthAccessDenied;
      expect(denied.role, 'broker');
      expect(denied.email, 'broker@jaipurmandi.com');
      expect(denied.message, contains('does not have commodity buyer permissions'));

      // Verify immediate session termination and local storage cleanup
      expect(repo.signOutCalled, isTrue);
      expect(await fakeStorage.getToken(), isNull);
      expect(await fakeStorage.getUserRole(), isNull);
    });

    test('Scenario 3b: Authenticated seller account is denied access and storage is cleared', () async {
      final user = createMockUser(
        id: 'usr-seller-03',
        email: 'seller@agrofarms.com',
        appMetadata: {'role': 'seller'},
      );
      final session = createMockSession(user: user);

      final repo = TestableAuthRepository(
        fakeStorage: fakeStorage,
        mockAuthResponse: AuthResponse(session: session, user: user),
        mockProfile: {
          'id': 'usr-seller-03',
          'role': 'seller',
          'name': 'Suresh Patel',
        },
      );

      final result = await repo.signInWithPassword(
        email: 'seller@agrofarms.com',
        password: 'SellerPass2026!',
      );

      expect(result, isA<AuthAccessDenied>());
      expect((result as AuthAccessDenied).role, 'seller');
      expect(repo.signOutCalled, isTrue);
      expect(await fakeStorage.getToken(), isNull);
    });

    test('Scenario 4: User cannot gain buyer permissions by tampering with client-provided userMetadata', () async {
      // Attacker attempts to forge userMetadata: {'role': 'buyer'}
      // However, authoritative server DB and appMetadata mark them as 'seller'
      final user = createMockUser(
        id: 'usr-attacker-04',
        email: 'attacker@agrofarms.com',
        appMetadata: {'role': 'seller'},
        userMetadata: {'role': 'buyer'}, // FORGED CLIENT ATTRIBUTE
      );
      final session = createMockSession(user: user);

      final repo = TestableAuthRepository(
        fakeStorage: fakeStorage,
        mockAuthResponse: AuthResponse(session: session, user: user),
        mockProfile: {
          'id': 'usr-attacker-04',
          'role': 'seller', // Authoritative server source
        },
      );

      final result = await repo.signInWithPassword(
        email: 'attacker@agrofarms.com',
        password: 'Password123!',
      );

      // Must be rejected based on server-side authority
      expect(result, isA<AuthAccessDenied>());
      expect((result as AuthAccessDenied).role, 'seller');
      expect(await fakeStorage.getToken(), isNull);
    });

    test('Scenario 4b: Client-provided role is rejected if server authority is absent', () async {
      // Attacker claims role: 'buyer' in userMetadata, but DB and appMetadata have no role
      final user = createMockUser(
        id: 'usr-unverified-05',
        email: 'unknown@example.com',
        appMetadata: {},
        userMetadata: {'role': 'buyer'},
      );
      final session = createMockSession(user: user);

      final repo = TestableAuthRepository(
        fakeStorage: fakeStorage,
        mockAuthResponse: AuthResponse(session: session, user: user),
        mockProfile: null, // No verified DB profile
      );

      final result = await repo.signInWithPassword(
        email: 'unknown@example.com',
        password: 'Password123!',
      );

      expect(result, isA<AuthAccessDenied>());
      expect(await fakeStorage.getToken(), isNull);
    });

    test('Scenario 5: Valid session restores correctly from secure storage', () async {
      await fakeStorage.saveToken('restored-valid-buyer-token');
      await fakeStorage.saveUserInfo(
        id: 'usr-buyer-restore',
        role: 'buyer',
        email: 'procurement@apexgrain.com',
        fullName: 'Rajesh Singhal',
        companyId: 'comp-101',
        companyName: 'Apex Grain Processors Pvt Ltd',
      );

      final repo = AuthRepository(storage: fakeStorage);
      final status = await repo.checkSession();

      expect(status, SessionStatus.authenticated);

      final buyer = await repo.getCurrentBuyer();
      expect(buyer, isNotNull);
      expect(buyer!.role, 'buyer');
      expect(buyer.email, 'procurement@apexgrain.com');
    });

    test('Scenario 6: Stored session with unauthorized role is cleared upon checkSession', () async {
      // Tampered local storage has role 'seller'
      await fakeStorage.saveToken('some-token');
      await fakeStorage.saveUserInfo(
        id: 'usr-unauth',
        role: 'seller',
        email: 'seller@agrofarms.com',
        fullName: 'Seller Name',
      );

      final repo = AuthRepository(storage: fakeStorage);
      final status = await repo.checkSession();

      expect(status, SessionStatus.accessDenied);
      // Verify local storage is purged
      expect(await fakeStorage.getToken(), isNull);
    });

    test('Scenario 7: Logout clears all stored tokens, credentials, and user data', () async {
      await fakeStorage.saveToken('token-to-be-cleared');
      await fakeStorage.saveRefreshToken('refresh-token-to-be-cleared');
      await fakeStorage.saveUserInfo(
        id: 'usr-logout',
        role: 'buyer',
        email: 'buyer@apexgrain.com',
        fullName: 'Buyer Lead',
      );

      final repo = AuthRepository(storage: fakeStorage);
      await repo.signOut();

      expect(await fakeStorage.getToken(), isNull);
      expect(await fakeStorage.getRefreshToken(), isNull);
      expect(await fakeStorage.getUserId(), isNull);
      expect(await fakeStorage.getUserRole(), isNull);
      expect(await repo.getCurrentBuyer(), isNull);
    });

    test('Scenario 8: Invalid credentials return sanitized, recoverable error message without stack trace', () async {
      final repo = TestableAuthRepository(
        fakeStorage: fakeStorage,
        mockAuthException: const AuthException(
          'invalid login credentials',
          statusCode: '400',
        ),
      );

      final result = await repo.signInWithPassword(
        email: 'buyer@company.com',
        password: 'WrongPassword',
      );

      expect(result, isA<AuthFailure>());
      final failure = result as AuthFailure;
      expect(
        failure.message,
        'Invalid email or password. Please verify your credentials and try again.',
      );
      expect(failure.code, '400');
    });

    test('Scenario 8b: Network error during authentication returns recoverable message', () async {
      final repo = TestableAuthRepository(
        fakeStorage: fakeStorage,
        mockAuthException: const AuthException(
          'Failed host lookup',
          statusCode: '503',
        ),
      );

      final result = await repo.signInWithPassword(
        email: 'buyer@company.com',
        password: 'Password123!',
      );

      expect(result, isA<AuthFailure>());
      expect((result as AuthFailure).message, contains('Failed host lookup'));
    });

    test('Concurrency Defense: Repeated submission while in-progress is rejected', () async {
      final user = createMockUser(
        id: 'usr-buyer-slow',
        email: 'buyer@company.com',
        appMetadata: {'role': 'buyer'},
      );
      final session = createMockSession(user: user);

      final repo = TestableAuthRepository(
        fakeStorage: fakeStorage,
        mockAuthResponse: AuthResponse(session: session, user: user),
        mockProfile: {'id': 'usr-buyer-slow', 'role': 'buyer'},
        delay: const Duration(milliseconds: 150),
      );

      // Launch first request (in-flight)
      final future1 = repo.signInWithPassword(
        email: 'buyer@company.com',
        password: 'ValidPassword!',
      );

      // Immediate second request while first is running
      final result2 = await repo.signInWithPassword(
        email: 'buyer@company.com',
        password: 'ValidPassword!',
      );

      expect(result2, isA<AuthFailure>());
      expect((result2 as AuthFailure).code, 'REQUEST_IN_PROGRESS');

      final result1 = await future1;
      expect(result1, isA<AuthSuccess>());
    });
  });
}
