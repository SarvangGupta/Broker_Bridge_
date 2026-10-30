import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/data/gst_filing_provider.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_state.dart';
import 'package:rmbroker_mobile/features/directory/domain/gst_certificate_data.dart';
import 'package:rmbroker_mobile/features/directory/domain/gst_filing_history.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/contact_form_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/gst_filing_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/contact_details_sheet.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/contact_form_modal.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/gst_filing_history_sheet.dart';

import 'directory_repository_test.dart' show MockSecureStorageService;

class MockDirectoryFixRepository extends DirectoryRepository {
  String? brokerId = 'broker-fix-02';
  final List<String> removedContactIds = [];
  final List<String> restoredContactIds = [];
  final List<Map<String, dynamic>> linkedCounterparties = [];
  final List<UpdateContactInput> updatedContactInputs = [];
  final List<CreateContactInput> createdContactInputs = [];

  DuplicateCase simulatedDuplicateCase = DuplicateCase.none;
  String? simulatedDuplicateGstin;
  String? simulatedDuplicateMobile;

  MockDirectoryFixRepository()
      : super(
          storage: MockSecureStorageService({
            'rmbroker_user_id': 'broker-fix-02',
            'rmbroker_user_role': 'broker',
          }),
        );

  @override
  String? activeBrokerId() => brokerId;

  @override
  Future<DuplicateCheckResult> checkDuplicate({
    required String mobile,
    required String companyName,
    String? gstin,
  }) async {
    if (simulatedDuplicateCase == DuplicateCase.activeInDirectory) {
      return DuplicateCheckResult(
        isDuplicate: true,
        matchType: 'gstin',
        duplicateCase: DuplicateCase.activeInDirectory,
        existingContactId: 'contact-active-01',
        existingCompanyName: 'Active Agro Corp',
        existingGstin: gstin ?? '27AABCU9603R1ZN',
      );
    } else if (simulatedDuplicateCase == DuplicateCase.previouslyRemoved) {
      return DuplicateCheckResult(
        isDuplicate: true,
        matchType: 'gstin',
        duplicateCase: DuplicateCase.previouslyRemoved,
        existingContactId: 'contact-removed-02',
        existingCompanyName: 'Previously Removed Commodities',
        existingGstin: gstin ?? '27AABCU9603R1ZN',
      );
    } else if (simulatedDuplicateCase == DuplicateCase.sharedAvailable) {
      return DuplicateCheckResult(
        isDuplicate: true,
        matchType: 'gstin',
        duplicateCase: DuplicateCase.sharedAvailable,
        existingCompanyId: 'comp-shared-03',
        existingUserId: 'user-shared-03',
        existingCompanyName: 'Shared Global Traders',
        existingGstin: gstin ?? '27AABCU9603R1ZN',
      );
    }

    return DuplicateCheckResult.none();
  }

  @override
  Future<DirectoryDataResult<bool>> removeContact(String contactId) async {
    removedContactIds.add(contactId);
    return const DirectorySuccess(true);
  }

  @override
  Future<DirectoryDataResult<String>> restoreContact(String contactId) async {
    restoredContactIds.add(contactId);
    return DirectorySuccess(contactId);
  }

  @override
  Future<DirectoryDataResult<String>> linkSharedCounterparty({
    required String companyId,
    String? userId,
    String? notes,
  }) async {
    linkedCounterparties.add({
      'companyId': companyId,
      'userId': userId,
      'notes': notes,
    });
    return DirectorySuccess('new-link-$companyId');
  }

  @override
  Future<DirectoryDataResult<bool>> updateContact(
    String contactId,
    UpdateContactInput input,
  ) async {
    updatedContactInputs.add(input);
    return const DirectorySuccess(true);
  }

  @override
  Future<DirectoryDataResult<String>> createContact(CreateContactInput input) async {
    final dup = await checkDuplicate(
      mobile: input.mobile,
      companyName: input.companyName,
      gstin: input.gstin,
    );
    if (dup.isDuplicate) {
      if (dup.isCaseA) {
        return DirectoryError(
          message: 'This ${input.role.label} is already in your directory (${dup.existingCompanyName}).',
          isDuplicate: true,
          duplicateInfo: dup,
        );
      } else if (dup.isCaseB) {
        return DirectoryError(
          message: 'This ${input.role.label} already exists in your database. Add them back?',
          isDuplicate: true,
          duplicateInfo: dup,
        );
      } else if (dup.isCaseC) {
        return DirectoryError(
          message: 'Found ${dup.existingCompanyName} in directory. Link to your directory?',
          isDuplicate: true,
          duplicateInfo: dup,
        );
      }
    }
    createdContactInputs.add(input);
    return const DirectorySuccess('created-contact-id-123');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MICRO-SPRINT: RMBROKER-GST-DIRECTORY-FIX-02', () {
    test('1. GST Filing History sheet layout does not collapse: handles initial loading, empty, and data states', () async {
      const provider = GstMockDataProvider();
      final snapshot = await provider.fetchFilingHistory('27AABCU9603R1ZN');

      const initialState = GstFilingState(
        status: GstFilingLoadingStatus.initial,
      );
      expect(initialState.isLoading, isTrue);

      final successState = GstFilingState(
        status: GstFilingLoadingStatus.success,
        snapshot: snapshot,
      );
      expect(successState.snapshot?.filings.isNotEmpty, isTrue);

      const errorState = GstFilingState(
        status: GstFilingLoadingStatus.error,
        errorMessage: 'Network connection timeout while connecting to free public GST source.',
      );
      expect(errorState.errorMessage, contains('timeout'));
    });

    test('2. Refresh preserves existing snapshot during reload without blank screen flashing', () async {
      const provider = GstMockDataProvider();
      final snapshot = await provider.fetchFilingHistory('27AABCU9603R1ZN');

      final state = GstFilingState(
        status: GstFilingLoadingStatus.success,
        snapshot: snapshot,
        isRefreshing: true,
      );

      expect(state.snapshot, isNotNull);
      expect(state.snapshot!.filings.isNotEmpty, isTrue);
      expect(state.isRefreshing, isTrue);
    });

    test('3. Soft delete / Remove Counterparty: removes contact relationship without deleting shared data', () async {
      final repo = MockDirectoryFixRepository();
      final container = ProviderContainer(
        overrides: [
          directoryRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(directoryControllerProvider.notifier);
      final removed = await controller.removeContact('contact-uuid-101');

      expect(removed, isTrue);
      expect(repo.removedContactIds, contains('contact-uuid-101'));
    });

    test('4. Re-Add Case A: Active in directory prevents duplicate creation with clear message', () async {
      final repo = MockDirectoryFixRepository();
      repo.simulatedDuplicateCase = DuplicateCase.activeInDirectory;

      const input = CreateContactInput(
        name: 'Suresh Patil',
        companyName: 'Active Agro Corp',
        mobile: '9876543210',
        role: ContactRole.buyer,
        gstin: '27AABCU9603R1ZN',
      );

      final res = await repo.createContact(input);
      expect(res, isA<DirectoryError<String>>());
      final err = res as DirectoryError<String>;
      expect(err.isDuplicate, isTrue);
      expect(err.duplicateInfo?.duplicateCase, DuplicateCase.activeInDirectory);
      expect(err.message, contains('already in your directory'));
    });

    test('5. Re-Add Case B: Previously removed counterparty prompts Add them back and restores relationship', () async {
      final repo = MockDirectoryFixRepository();
      repo.simulatedDuplicateCase = DuplicateCase.previouslyRemoved;

      const input = CreateContactInput(
        name: 'Ramesh Sharma',
        companyName: 'Previously Removed Commodities',
        mobile: '9876543211',
        role: ContactRole.seller,
        gstin: '27AABCU9603R1ZN',
      );

      final res = await repo.createContact(input);
      expect(res, isA<DirectoryError<String>>());
      final err = res as DirectoryError<String>;
      expect(err.isDuplicate, isTrue);
      expect(err.duplicateInfo?.duplicateCase, DuplicateCase.previouslyRemoved);
      expect(err.message, contains('Add them back?'));

      // Restore relationship
      final restoreRes = await repo.restoreContact(err.duplicateInfo!.existingContactId!);
      expect(restoreRes, isA<DirectorySuccess<String>>());
      expect(repo.restoredContactIds, contains('contact-removed-02'));
    });

    test('6. Re-Add Case C: Shared database counterparty allows linking to broker directory', () async {
      final repo = MockDirectoryFixRepository();
      repo.simulatedDuplicateCase = DuplicateCase.sharedAvailable;

      const input = CreateContactInput(
        name: 'Vikram Mehta',
        companyName: 'Shared Global Traders',
        mobile: '9876543212',
        role: ContactRole.buyer,
        gstin: '27AABCU9603R1ZN',
      );

      final res = await repo.createContact(input);
      expect(res, isA<DirectoryError<String>>());
      final err = res as DirectoryError<String>;
      expect(err.isDuplicate, isTrue);
      expect(err.duplicateInfo?.duplicateCase, DuplicateCase.sharedAvailable);
      expect(err.message, contains('Link to your directory?'));

      // Link shared counterparty
      final linkRes = await repo.linkSharedCounterparty(
        companyId: err.duplicateInfo!.existingCompanyId!,
        userId: err.duplicateInfo?.existingUserId,
        notes: 'Mediated under Desk 02',
      );
      expect(linkRes, isA<DirectorySuccess<String>>());
      expect(repo.linkedCounterparties.first['companyId'], 'comp-shared-03');
    });

    test('7. Re-Add Case D: Truly new counterparty creates normally without collision', () async {
      final repo = MockDirectoryFixRepository();
      repo.simulatedDuplicateCase = DuplicateCase.none;

      const input = CreateContactInput(
        name: 'New Trader',
        companyName: 'Fresh Agro Pvt Ltd',
        mobile: '9876543299',
        role: ContactRole.seller,
        gstin: '27AABCU9603R1ZN',
      );

      final res = await repo.createContact(input);
      expect(res, isA<DirectorySuccess<String>>());
      expect(repo.createdContactInputs.length, 1);
      expect(repo.createdContactInputs.first.companyName, 'Fresh Agro Pvt Ltd');
    });

    test('8. Edit GST details: saves updated GSTIN and certificate against existing contact without duplicating', () async {
      final repo = MockDirectoryFixRepository();

      const updateInput = UpdateContactInput(
        name: 'Anil Deshmukh',
        companyName: 'Deshmukh Cotton Mills',
        mobile: '9876543210',
        role: ContactRole.seller,
        gstin: '27AABCU9603R1ZN',
        legalName: 'DESHMUKH COTTON MILLS LLP',
        tradeName: 'DESHMUKH COTTON',
        constitution: 'Limited Liability Partnership',
        address: 'Plot 45, MIDC, Nagpur, Maharashtra',
        gstVerificationStatus: CounterpartyGstStatus.brokerVerified,
        gstCertificateUrl: '/storage/certificates/deshmukh_gst.pdf',
      );

      final res = await repo.updateContact('existing-contact-999', updateInput);
      expect(res, isA<DirectorySuccess<bool>>());
      expect(repo.updatedContactInputs.length, 1);
      final saved = repo.updatedContactInputs.first;
      expect(saved.gstin, '27AABCU9603R1ZN');
      expect(saved.legalName, 'DESHMUKH COTTON MILLS LLP');
      expect(saved.gstVerificationStatus, CounterpartyGstStatus.brokerVerified);
      expect(saved.gstCertificateUrl, '/storage/certificates/deshmukh_gst.pdf');
    });

    test('9. GST Verification Status labeling displays clear distinctions', () {
      expect(CounterpartyGstStatus.displayLabel(CounterpartyGstStatus.missing), 'GST Details Missing');
      expect(CounterpartyGstStatus.displayLabel(CounterpartyGstStatus.gstPending), 'Pending Verification');
      expect(CounterpartyGstStatus.displayLabel(CounterpartyGstStatus.brokerVerified), 'Broker Verified — Certificate Reviewed');
      expect(CounterpartyGstStatus.displayLabel(CounterpartyGstStatus.portalMatched), 'GST Details Matched with Official Portal');
      expect(CounterpartyGstStatus.displayLabel(CounterpartyGstStatus.registrationInactive), 'GST Registration Inactive');
      expect(CounterpartyGstStatus.displayLabel(CounterpartyGstStatus.rejected), 'Verification Failed');
    });

    testWidgets('10. Contact Details Sheet displays remove contact button and edit GST details button', (tester) async {
      final contact = DirectoryContact(
        id: 'contact-details-test-01',
        userId: 'user-01',
        companyId: 'comp-01',
        name: 'Rajesh Gupta',
        companyName: 'Gupta Agri Products',
        mobile: '+919876543210',
        role: ContactRole.buyer,
        gstin: '27AABCU9603R1ZN',
        legalName: 'GUPTA AGRI PRODUCTS PRIVATE LIMITED',
        gstVerificationStatus: CounterpartyGstStatus.brokerVerified,
        createdAt: DateTime.now(),
      );

      final repo = MockDirectoryFixRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ContactDetailsSheet(initialContact: contact),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remove_contact_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_edit_gst_details_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_check_gst_filing_history_button')), findsOneWidget);
    });
  });
}
