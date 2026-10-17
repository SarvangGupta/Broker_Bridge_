import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';

class MockSecureStorageService extends SecureStorageService {
  final Map<String, String> _storage = {};

  MockSecureStorageService([Map<String, String>? initial]) {
    if (initial != null) _storage.addAll(initial);
  }

  @override
  Future<String?> getUserId() async => _storage['rmbroker_user_id'];

  @override
  Future<String?> getUserRole() async => _storage['rmbroker_user_role'];

  @override
  Future<String?> getToken() async => _storage['rmbroker_auth_token'];
}

void main() {
  group('DirectoryRepository Tests', () {
    late DirectoryRepository repository;

    setUp(() {
      repository = DirectoryRepository(
        storage: MockSecureStorageService(),
      );
    });

    test('getContacts returns DirectoryUnavailable when endpoint is pending exposure', () async {
      final result = await repository.getContacts();

      expect(result, isA<DirectoryUnavailable<DirectoryListPayload>>());
      final unavailable = result as DirectoryUnavailable<DirectoryListPayload>;
      expect(unavailable.contractNotice, contains('pending backend exposure'));
    });

    test('createContact rejects invalid mobile numbers before making network calls', () async {
      const invalidInput = CreateContactInput(
        name: 'Test Buyer',
        companyName: 'Test Corp',
        mobile: '12345',
        role: ContactRole.buyer,
      );

      final result = await repository.createContact(invalidInput);

      expect(result, isA<DirectoryError<String>>());
      final err = result as DirectoryError<String>;
      expect(err.message, contains('valid 10-digit mobile number'));
    });

    test('createContact rejects short names or company names', () async {
      const shortNameInput = CreateContactInput(
        name: 'A',
        companyName: 'Valid Corp',
        mobile: '9876543210',
        role: ContactRole.buyer,
      );

      final result = await repository.createContact(shortNameInput);

      expect(result, isA<DirectoryError<String>>());
      final err = result as DirectoryError<String>;
      expect(err.message, contains('Contact person name must be at least 2 characters'));
    });

    test('updateContact validates mobile format on edit', () async {
      const invalidEdit = UpdateContactInput(
        name: 'Ramesh',
        companyName: 'Malwa Agro',
        mobile: 'bad_number',
        role: ContactRole.buyer,
      );

      final result = await repository.updateContact('contact-1', invalidEdit);

      expect(result, isA<DirectoryError<bool>>());
      final err = result as DirectoryError<bool>;
      expect(err.message, contains('10-digit mobile number'));
    });
  });
}
