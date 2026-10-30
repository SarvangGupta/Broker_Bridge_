import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_state.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/contact_form_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'directory_repository_test.dart' show MockSecureStorageService;

const _districtId = '50000000-0000-4000-8000-000000000001';
const _stateId = '40000000-0000-4000-8000-000000000001';

/// The REST route is not deployed: every request fails like a refused connection.
ApiClient _offlineApi() {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.reject(
          DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        ),
      ),
    );
  return ApiClient(storage: MockSecureStorageService(), customDio: dio);
}

/// The API host is up but the route is missing: Next.js answers with an HTML
/// 404 page, so the error response body is a String, not a JSON map.
ApiClient _htmlNotFoundApi() {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.reject(
          DioException(
            requestOptions: o,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: o,
              statusCode: 404,
              data: '<!DOCTYPE html><html><body>404</body></html>',
            ),
          ),
        ),
      ),
    );
  return ApiClient(storage: MockSecureStorageService(), customDio: dio);
}

/// Repository with the Supabase access points replaced; records every write.
class _FakeDirectoryRepository extends DirectoryRepository {
  String? brokerId = 'broker-1';
  List<Map<String, dynamic>> existingByMobile = [];
  Object? duplicateError;
  Object? insertError;
  Object? noteError;
  Completer<void>? insertGate;
  final List<List<String>> mobileQueries = [];
  final List<(CreateContactInput, String)> inserts = [];
  final List<String> notes = [];

  _FakeDirectoryRepository({ApiClient? api})
    : super(
        apiClient: api ?? _offlineApi(),
        storage: MockSecureStorageService(),
      );

  @override
  String? activeBrokerId() => brokerId;

  @override
  Future<List<Map<String, dynamic>>> queryContactsByMobile(
    String brokerId,
    List<String> mobiles,
  ) async {
    mobileQueries.add(mobiles);
    if (duplicateError != null) throw duplicateError!;
    return existingByMobile;
  }

  @override
  Future<String> insertContactRecords(
    String brokerId,
    CreateContactInput input,
    String normalizedMobile,
  ) async {
    inserts.add((input, normalizedMobile));
    if (insertGate != null) await insertGate!.future;
    if (insertError != null) throw insertError!;
    return 'contact-${inserts.length}';
  }

  @override
  Future<void> insertInitialNote(String contactId, String notes) async {
    if (noteError != null) throw noteError!;
    this.notes.add(notes);
  }

  @override
  Future<DirectoryDataResult<DirectoryListPayload>> getContacts({
    String? role,
    String? search,
    String? status,
    int? limit,
    String? cursor,
  }) async => const DirectorySuccess(
    DirectoryListPayload(contacts: [], stats: DirectorySummaryStats()),
  );
}

CreateContactInput _input(
  ContactRole role, {
  String mobile = '98765 43210',
  String? notes,
}) => CreateContactInput(
  name: '  Ramesh Agrawal ',
  companyName: 'Malwa Agro Traders',
  mobile: mobile,
  role: role,
  city: 'Indore',
  state: 'Madhya Pradesh',
  notes: notes,
);

DirectoryContact _contact({
  String? city,
  String? state,
  String? cityName,
  String? stateName,
}) => DirectoryContact(
  id: 'c1',
  userId: 'u1',
  companyId: 'co1',
  name: 'Ramesh',
  companyName: 'Malwa Agro',
  mobile: '+919876543210',
  role: ContactRole.buyer,
  city: city,
  state: state,
  cityName: cityName,
  stateName: stateName,
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  group('Add Buyer / Add Seller (create path)', () {
    for (final role in ContactRole.values) {
      test(
        'valid ${role.label} is saved with its own role and normalized mobile',
        () async {
          final repo = _FakeDirectoryRepository();
          final result = await repo.createContact(_input(role));

          expect(result, isA<DirectorySuccess<String>>());
          expect((result as DirectorySuccess<String>).data, 'contact-1');
          expect(repo.inserts, hasLength(1));
          final (input, mobile) = repo.inserts.single;
          expect(input.role, role);
          expect(
            input.role.apiValue,
            role == ContactRole.seller ? 'seller' : 'buyer',
          );
          expect(mobile, '+919876543210');
        },
      );
    }

    for (final role in ContactRole.values) {
      test(
        '${role.label}: an HTML 404 from the REST route falls back to the direct save',
        () async {
          final repo = _FakeDirectoryRepository(api: _htmlNotFoundApi());
          final result = await repo.createContact(_input(role));
          expect(result, isA<DirectorySuccess<String>>());
          expect(repo.inserts.single.$1.role, role);
        },
      );
    }

    test('duplicate check queries both stored mobile formats', () async {
      final repo = _FakeDirectoryRepository();
      await repo.createContact(_input(ContactRole.buyer));
      expect(
        repo.mobileQueries.last,
        unorderedEquals(['+919876543210', '9876543210']),
      );
    });

    test('an existing mobile blocks creation with a duplicate error', () async {
      final repo = _FakeDirectoryRepository()
        ..existingByMobile = [
          {
            'id': 'x',
            'users': {'name': 'Old', 'mobile': '9876543210', 'role': 'buyer'},
            'companies': {'name': 'Old Traders'},
          },
        ];
      final result = await repo.createContact(_input(ContactRole.seller));
      expect(result, isA<DirectoryError<String>>());
      final err = result as DirectoryError<String>;
      expect(err.isDuplicate, isTrue);
      expect(err.message, contains('Old Traders'));
      expect(repo.inserts, isEmpty);
    });

    test('if the duplicate check fails, nothing is created and the error is explicit', () async {
      final repo = _FakeDirectoryRepository()
        ..duplicateError = Exception('network');
      final result = await repo.createContact(_input(ContactRole.buyer));
      expect(result, isA<DirectoryError<String>>());
      expect(
        (result as DirectoryError<String>).message,
        contains('Could not check for an existing contact'),
      );
      expect(repo.inserts, isEmpty);
    });

    test('permission failure is reported as such, never as success or "backend offline"', () async {
      final repo = _FakeDirectoryRepository()
        ..insertError = const PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        );
      final result = await repo.createContact(_input(ContactRole.buyer));
      expect(result, isA<DirectoryError<String>>());
      expect(
        (result as DirectoryError<String>).message,
        'Your account is not permitted to add this contact.',
      );
    });

    test('expired JWT maps to an unauthorized result', () async {
      final repo = _FakeDirectoryRepository()
        ..insertError = const PostgrestException(
          message: 'JWT expired',
          code: 'PGRST301',
        );
      expect(
        await repo.createContact(_input(ContactRole.seller)),
        isA<DirectoryUnauthorized<String>>(),
      );
    });

    test('other save errors give a clear retry message', () async {
      final repo = _FakeDirectoryRepository()
        ..insertError = Exception('socket closed');
      final result = await repo.createContact(_input(ContactRole.buyer));
      expect(
        (result as DirectoryError<String>).message,
        contains('Could not save the contact'),
      );
    });

    test(
      'a failed initial note does not turn a saved contact into a failure',
      () async {
        final repo = _FakeDirectoryRepository()
          ..noteError = Exception('notes failed');
        final result = await repo.createContact(
          _input(ContactRole.buyer, notes: 'Prefers 30-day credit'),
        );
        expect(result, isA<DirectorySuccess<String>>());
      },
    );

    test('initial note is saved trimmed when present', () async {
      final repo = _FakeDirectoryRepository();
      await repo.createContact(
        _input(ContactRole.seller, notes: '  Prefers 30-day credit  '),
      );
      expect(repo.notes, ['Prefers 30-day credit']);
    });

    test('without a session (and no client), the result is honest, not a fake success', () async {
      final repo = _FakeDirectoryRepository()..brokerId = null;
      final result = await repo.createContact(_input(ContactRole.buyer));
      expect(result, isA<DirectoryUnavailable<String>>());
      expect(repo.inserts, isEmpty);
    });
  });

  group('Directory list', () {
    test('a client without a session reports sign-in, not "backend pending"', () async {
      final repo = DirectoryRepository(
        apiClient: _htmlNotFoundApi(),
        supabase: SupabaseClient('http://127.0.0.1:9', 'anon-key'),
        storage: MockSecureStorageService(),
      );
      expect(await repo.getContacts(), isA<DirectoryUnauthorized<DirectoryListPayload>>());
    });

    test('without any client the result stays honestly unavailable', () async {
      final repo = DirectoryRepository(
        apiClient: _htmlNotFoundApi(),
        storage: MockSecureStorageService(),
      );
      expect(await repo.getContacts(), isA<DirectoryUnavailable<DirectoryListPayload>>());
    });
  });

  group('Location display', () {
    test('resolved master names are shown; raw UUIDs never are', () {
      expect(
        _contact(
          city: _districtId,
          state: _stateId,
          cityName: 'Jaipur',
          stateName: 'Rajasthan',
        ).locationLabel,
        'Jaipur, Rajasthan',
      );
      final unresolved = _contact(city: _districtId, state: _stateId);
      expect(unresolved.locationLabel, 'Location not specified');
      expect(unresolved.hasLocation, isFalse);
      expect(
        _contact(city: 'Kota', state: 'Rajasthan').locationLabel,
        'Kota, Rajasthan',
      );
    });

    test('directory search matches resolved city/state names', () {
      final state = DirectoryState(
        status: DirectoryStatus.loaded,
        allContacts: [
          _contact(
            city: _districtId,
            state: _stateId,
            cityName: 'Jaipur',
            stateName: 'Rajasthan',
          ),
        ],
        searchQuery: 'jaipur',
      );
      expect(state.filteredContacts, hasLength(1));
      final byUuid = DirectoryState(
        status: DirectoryStatus.loaded,
        allContacts: state.allContacts,
        searchQuery: _districtId.substring(0, 8),
      );
      expect(byUuid.filteredContacts, isEmpty);
    });

    test(
      'edit saves the stored value back unless the shown text was changed',
      () {
        expect(
          ContactFormController.locationToSave('Jaipur', 'Jaipur', _districtId),
          _districtId,
        );
        expect(
          ContactFormController.locationToSave('Kota', 'Jaipur', _districtId),
          'Kota',
        );
        expect(
          ContactFormController.locationToSave('Indore', '', null),
          'Indore',
        );
      },
    );
  });

  group('Contact form controller', () {
    late _FakeDirectoryRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeDirectoryRepository();
      container = ProviderContainer(
        overrides: [directoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
    });

    ContactFormController form() =>
        container.read(contactFormControllerProvider.notifier);
    ContactFormState read() => container.read(contactFormControllerProvider);

    test('field errors clear once the value is corrected', () {
      form().initForCreate();
      form().updateName('A');
      expect(read().nameError, isNotNull);
      form().updateName('Ramesh');
      expect(read().nameError, isNull);

      form().updateMobile('123');
      expect(read().mobileError, isNotNull);
      form().updateMobile('9876543210');
      expect(read().mobileError, isNull);
    });

    test(
      'a failed submit shows its error, and a later valid submit clears it',
      () async {
        form().initForCreate(ContactRole.seller);
        form().setRegistrationMode(CounterpartyRegistrationMode.manual);
        form()
          ..updateName('Ramesh')
          ..updateCompanyName('Malwa Agro')
          ..updateMobile('9876543210')
          ..updateGstin('27AABCU9603R1ZN');
        repo.insertError = Exception('down');
        expect(await form().submit(), isFalse);
        expect(read().generalError, contains('Could not save the contact'));

        repo.insertError = null;
        expect(await form().submit(), isTrue);
        expect(read().generalError, isNull);
        expect(repo.inserts.last.$1.role, ContactRole.seller);
      },
    );

    test('rapid repeated submit creates one contact', () async {
      form().initForCreate();
      form().setRegistrationMode(CounterpartyRegistrationMode.manual);
      form()
        ..updateName('Ramesh')
        ..updateCompanyName('Malwa Agro')
        ..updateMobile('9876543210')
        ..updateGstin('27AABCU9603R1ZN');
      repo.insertGate = Completer<void>();
      final first = form().submit();
      final second = await form().submit();
      expect(second, isFalse);
      repo.insertGate!.complete();
      expect(await first, isTrue);
      expect(repo.inserts, hasLength(1));
    });
  });
}
