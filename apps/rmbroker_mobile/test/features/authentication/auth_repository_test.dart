import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbroker_mobile/features/authentication/domain/auth_result.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrokerUser Domain Model Tests', () {
    test('isBrokerOrAdmin identifies authorized roles correctly', () {
      const broker = BrokerUser(
        id: '1',
        email: 'b@bb.com',
        fullName: 'Broker A',
        role: 'broker',
      );
      const admin = BrokerUser(
        id: '2',
        email: 'a@bb.com',
        fullName: 'Admin B',
        role: 'Admin',
      );
      const buyer = BrokerUser(
        id: '3',
        email: 'buyer@agro.com',
        fullName: 'Buyer C',
        role: 'buyer',
      );
      const seller = BrokerUser(
        id: '4',
        email: 'seller@agro.com',
        fullName: 'Seller D',
        role: 'seller',
      );
      const unassigned = BrokerUser(
        id: '5',
        email: 'u@agro.com',
        fullName: 'User E',
        role: '',
      );

      expect(broker.isBrokerOrAdmin, isTrue);
      expect(admin.isBrokerOrAdmin, isTrue);
      expect(buyer.isBrokerOrAdmin, isFalse);
      expect(seller.isBrokerOrAdmin, isFalse);
      expect(unassigned.isBrokerOrAdmin, isFalse);
    });

    test('fromMap and toMap serialize and deserialize cleanly', () {
      final map = {
        'id': 'usr-100',
        'email': 'broker.jaipur@brokerbridge.com',
        'full_name': 'Nilesh Sharma',
        'role': 'broker',
        'company_id': 'comp-50',
      };

      final user = BrokerUser.fromMap(map);
      expect(user.id, equals('usr-100'));
      expect(user.email, equals('broker.jaipur@brokerbridge.com'));
      expect(user.fullName, equals('Nilesh Sharma'));
      expect(user.role, equals('broker'));
      expect(user.companyId, equals('comp-50'));
      expect(user.isBrokerOrAdmin, isTrue);

      final exported = user.toMap();
      expect(exported['id'], equals('usr-100'));
      expect(exported['role'], equals('broker'));
    });
  });

  group('AuthResult Model Hierarchy Tests', () {
    test('AuthSuccess contains authorized BrokerUser', () {
      const user = BrokerUser(
        id: '1',
        email: 'b@bb.com',
        fullName: 'Broker',
        role: 'broker',
      );
      const result = AuthSuccess(user);
      expect(result.user.email, equals('b@bb.com'));
      expect(result.user.isBrokerOrAdmin, isTrue);
    });

    test('AuthAccessDenied captures unauthorized role and message', () {
      const result = AuthAccessDenied(
        email: 'buyer@corp.com',
        role: 'buyer',
        message: 'Broker desk role required',
      );
      expect(result.email, equals('buyer@corp.com'));
      expect(result.role, equals('buyer'));
      expect(result.message, contains('Broker desk role required'));
    });

    test('AuthFailure carries error message and code', () {
      const result = AuthFailure(
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS',
      );
      expect(result.message, equals('Invalid credentials'));
      expect(result.code, equals('INVALID_CREDENTIALS'));
    });
  });

  group('AuthRepository Secure Storage & Session Checks', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test(
      'checkSession returns unauthenticated when no session exists',
      () async {
        final storage = SecureStorageService();
        final authRepo = AuthRepository(storage: storage);

        final status = await authRepo.checkSession();
        expect(status, equals(SessionStatus.unauthenticated));
      },
    );

    test('checkSession returns authenticated when broker token and role are stored', () async {
      FlutterSecureStorage.setMockInitialValues({
        'rmbroker_access_token': 'jwt_mock_token_123',
        'rmbroker_user_id': 'usr_99',
        'rmbroker_user_role': 'broker',
        'rmbroker_user_email': 'broker@bb.com',
        'rmbroker_user_name': 'Desk Broker',
      });

      final storage = SecureStorageService();
      final authRepo = AuthRepository(storage: storage);

      final status = await authRepo.checkSession();
      expect(status, equals(SessionStatus.authenticated));

      final broker = await authRepo.getCurrentBroker();
      expect(broker, isNotNull);
      expect(broker!.id, equals('usr_99'));
      expect(broker.role, equals('broker'));
      expect(broker.email, equals('broker@bb.com'));
    });

    test(
      'checkSession returns accessDenied when non-broker token is stored',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'rmbroker_access_token': 'jwt_mock_token_123',
          'rmbroker_user_id': 'usr_101',
          'rmbroker_user_role': 'buyer',
        });

        final storage = SecureStorageService();
        final authRepo = AuthRepository(storage: storage);

        final status = await authRepo.checkSession();
        expect(status, equals(SessionStatus.accessDenied));
      },
    );

    test('signOut wipes secure storage', () async {
      FlutterSecureStorage.setMockInitialValues({
        'rmbroker_access_token': 'jwt_mock_token_123',
        'rmbroker_user_role': 'broker',
      });

      final storage = SecureStorageService();
      final authRepo = AuthRepository(storage: storage);

      expect(await storage.getToken(), isNotNull);
      await authRepo.signOut();
      expect(await storage.getToken(), isNull);
      expect(await storage.getUserRole(), isNull);
    });

    test(
      'signInWithPassword safely returns AuthFailure when client uninitialized',
      () async {
        final storage = SecureStorageService();
        final authRepo = AuthRepository(storage: storage);

        final result = await authRepo.signInWithPassword(
          email: 'test@bb.com',
          password: 'password123',
        );

        expect(result, isA<AuthFailure>());
        final failure = result as AuthFailure;
        expect(failure.code, equals('CLIENT_NOT_INITIALIZED'));
      },
    );
  });
}
