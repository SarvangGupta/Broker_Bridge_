import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmseller_mobile/features/authentication/domain/auth_result.dart';

void main() {
  group('RB-SELLER-01: AuthRepository Role & Security Tests', () {
    late SecureStorageService storage;
    late AuthRepository authRepository;

    setUp(() {
      storage = SecureStorageService();
      storage.enableMemoryFallbackForTesting();
      authRepository = AuthRepository(storage: storage);
    });

    test(
      'Authorized Seller login returns AuthSuccess and persists credentials',
      () async {
        final result = await authRepository.signInWithPassword(
          email: 'seller@demo.com',
          password: 'password123',
        );

        expect(result, isA<AuthSuccess>());
        final success = result as AuthSuccess;
        expect(success.user.role, 'seller');
        expect(success.user.email, 'seller@demo.com');
        expect(success.user.companyId, isNotNull);

        // Verify token and role saved in secure storage
        final savedToken = await storage.getToken();
        final savedRole = await storage.getUserRole();
        expect(savedToken, isNotNull);
        expect(savedRole, 'seller');
      },
    );

    test(
      'Buyer role is strictly rejected from Seller desk with AuthAccessDenied',
      () async {
        final result = await authRepository.signInWithPassword(
          email: 'buyer@demo.com',
          password: 'password123',
        );

        expect(result, isA<AuthAccessDenied>());
        final denied = result as AuthAccessDenied;
        expect(denied.role, 'buyer');
        expect(denied.message, contains('Seller Portal Access Restricted'));

        // Verify storage was wiped
        final savedToken = await storage.getToken();
        expect(savedToken, isNull);
      },
    );

    test('Broker desk role is strictly rejected from Seller desk with AuthAccessDenied', () async {
      final result = await authRepository.signInWithPassword(
        email: 'broker@demo.com',
        password: 'password123',
      );

      expect(result, isA<AuthAccessDenied>());
      final denied = result as AuthAccessDenied;
      expect(denied.role, 'broker');
      expect(denied.message, contains('Seller Portal Access Restricted'));

      final savedToken = await storage.getToken();
      expect(savedToken, isNull);
    });

    test(
      'Sign out cleanly wipes session token and secure storage keys',
      () async {
        // First sign in
        await authRepository.signInWithPassword(
          email: 'seller@demo.com',
          password: 'password123',
        );
        expect(await storage.getToken(), isNotNull);

        // Now sign out
        await authRepository.signOut();
        expect(await storage.getToken(), isNull);
        expect(await storage.getUserId(), isNull);
        expect(await storage.getUserRole(), isNull);
      },
    );
  });
}
