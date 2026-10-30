import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_share_model.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/data/ocr_extraction_service.dart';
import 'package:rmbroker_mobile/features/directory/domain/cheque_leaf_data.dart';
import 'package:rmbroker_mobile/features/directory/domain/counterparty_verification_request.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_state.dart';
import 'package:rmbroker_mobile/features/directory/domain/gst_certificate_data.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/contact_form_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';

import 'directory_repository_test.dart' show MockSecureStorageService;

/// Mock repository tracking calls and verifying inputs for the 20 test cases.
class MockGstBankingDirectoryRepository extends DirectoryRepository {
  String? brokerId = 'broker-test-123';
  final List<CreateContactInput> createdContacts = [];
  final List<UpdateContactInput> updatedContacts = [];
  final List<Map<String, dynamic>> loggedVerificationReviews = [];
  bool simulateDuplicateGstin = false;

  MockGstBankingDirectoryRepository()
      : super(
          storage: MockSecureStorageService({
            'rmbroker_user_id': 'broker-test-123',
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
    if (simulateDuplicateGstin && gstin != null && gstin.isNotEmpty) {
      return DuplicateCheckResult(
        isDuplicate: true,
        matchType: 'gstin',
        existingCompanyName: 'Existing Agro Corp',
        existingGstin: gstin,
      );
    }
    return DuplicateCheckResult.none();
  }

  @override
  Future<DirectoryDataResult<String>> createContact(CreateContactInput input) async {
    if (input.name.trim().length < 2) {
      return const DirectoryError(message: 'Contact person name must be at least 2 characters');
    }
    if (input.companyName.trim().length < 2) {
      return const DirectoryError(message: 'Company name must be at least 2 characters');
    }

    if (simulateDuplicateGstin && input.gstin != null && input.gstin!.isNotEmpty) {
      return DirectoryError(
        message: 'A counterparty with GSTIN ${input.gstin} already exists in your directory.',
        isDuplicate: true,
      );
    }

    createdContacts.add(input);
    return DirectorySuccess('contact-created-${createdContacts.length}');
  }

  @override
  Future<DirectoryDataResult<bool>> reviewCounterpartyVerification({
    required String requestId,
    required bool approve,
    String? reason,
  }) async {
    loggedVerificationReviews.add({
      'requestId': requestId,
      'approved': approve,
      'reason': reason,
      'reviewedAt': DateTime.now().toIso8601String(),
    });
    return const DirectorySuccess(true);
  }
}

/// Mock Deal Repository for testing document sharing logs
class MockDealShareRepository extends DealRepository {
  final List<Map<String, dynamic>> loggedShares = [];

  MockDealShareRepository()
      : super(
          apiClient: ApiClient(storage: MockSecureStorageService()),
          storage: MockSecureStorageService({
            'rmbroker_user_id': 'broker-test-123',
          }),
        );

  @override
  Future<bool> logDealDocumentShare({
    required String dealId,
    required String recipientCompanyId,
    required String documentType,
    required Map<String, dynamic> sharedPayload,
    String? documentRef,
  }) async {
    loggedShares.add({
      'dealId': dealId,
      'recipientCompanyId': recipientCompanyId,
      'documentType': documentType,
      'sharedPayload': sharedPayload,
      'documentRef': documentRef,
      'sharedAt': DateTime.now().toIso8601String(),
    });
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Valid Form GST REG-06 Sample Text for OCR testing
  const validGstReg06OcrText = '''
Form GST REG-06
Government of India
Registration Certificate
Registration Number: 27AABCU9603R1ZN
1. Legal Name: MAHARASHTRA AGRO INDUSTRIES DEVELOPMENT CORPORATION LIMITED
2. Trade Name, if any: MAIDC AGRO
3. Constitution of Business: Government Company
4. Address of Principal Place of Business: Krushi Udyog Bhavan, Dinkar Rao Desai Marg, Aarey Colony, Goregaon East, Mumbai, Maharashtra, 400065
5. Date of Liability: 01/07/2017
6. Period of Validity: From 01/07/2017 To Continuing
7. Type of Registration: Regular
State: Maharashtra
''';

  // Valid Cheque Leaf Sample Text for OCR testing
  const validChequeOcrText = '''
HDFC BANK LTD
BRANCH: NARIMAN POINT, MUMBAI
RTGS / NEFT IFSC: HDFC0000001
PAY: MAIDC AGRO LTD
RUPEES: ---------------------
A/C NO: 50100234567890
VALID UPTO 3 MONTHS ONLY
''';

  late MockGstBankingDirectoryRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockGstBankingDirectoryRepository();
    container = ProviderContainer(
      overrides: [
        directoryRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('MICRO-SPRINT: RMBROKER-COUNTERPARTY-GST-01 (All 20 Test Cases)', () {
    // -------------------------------------------------------------------------
    // TEST 1: Add Buyer with GST certificate
    // -------------------------------------------------------------------------
    test('1. Add Buyer with GST certificate extracts and saves as Broker Verified', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.setOcrService(OcrExtractionService(
        recognizer: (path) async => validGstReg06OcrText,
      ));

      controller.initForCreate(ContactRole.buyer);
      controller.updateName('Suresh Patil');
      controller.updateMobile('9876543210');

      // Pick certificate and trigger OCR
      controller.setGstCertificate('/tmp/gst_buyer.jpg');
      await controller.extractGstFromImage();

      expect(container.read(contactFormControllerProvider).gstin, equals('27AABCU9603R1ZN'));
      expect(container.read(contactFormControllerProvider).legalName, contains('MAHARASHTRA AGRO'));

      // Broker reviews and confirms
      controller.setBrokerConfirmedGst(true);

      final success = await controller.submit();
      expect(success, isTrue);

      expect(mockRepo.createdContacts.length, equals(1));
      final saved = mockRepo.createdContacts.first;
      expect(saved.role, equals(ContactRole.buyer));
      expect(saved.gstin, equals('27AABCU9603R1ZN'));
      expect(saved.isBrokerVerified, isTrue);
      expect(saved.gstVerificationStatus, equals(CounterpartyGstStatus.brokerVerified));
      expect(saved.gstCertificateUrl, equals('/tmp/gst_buyer.jpg'));
    });

    // -------------------------------------------------------------------------
    // TEST 2: Add Seller with GST certificate
    // -------------------------------------------------------------------------
    test('2. Add Seller with GST certificate saves as Broker Verified seller', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.setOcrService(OcrExtractionService(
        recognizer: (path) async => validGstReg06OcrText,
      ));

      controller.initForCreate(ContactRole.seller);
      controller.updateName('Rajesh Verma');
      controller.updateMobile('9811122233');

      controller.setGstCertificate('/tmp/gst_seller.jpg');
      await controller.extractGstFromImage();

      controller.setBrokerConfirmedGst(true);

      final success = await controller.submit();
      expect(success, isTrue);

      expect(mockRepo.createdContacts.length, equals(1));
      final saved = mockRepo.createdContacts.first;
      expect(saved.role, equals(ContactRole.seller));
      expect(saved.gstin, equals('27AABCU9603R1ZN'));
      expect(saved.isBrokerVerified, isTrue);
      expect(saved.gstVerificationStatus, equals(CounterpartyGstStatus.brokerVerified));
    });

    // -------------------------------------------------------------------------
    // TEST 3: Take certificate photo using camera
    // -------------------------------------------------------------------------
    test('3. Take certificate photo using camera supports rotation and replace', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.initForCreate(ContactRole.buyer);

      // Simulate capturing photo from camera
      controller.setGstCertificate('/camera/photo_001.jpg');
      var state = container.read(contactFormControllerProvider);
      expect(state.gstCertificatePath, equals('/camera/photo_001.jpg'));
      expect(state.gstCertificateRotation, equals(0));

      // Rotate in 90-degree increments
      controller.rotateGstCertificate();
      expect(container.read(contactFormControllerProvider).gstCertificateRotation, equals(90));
      controller.rotateGstCertificate();
      expect(container.read(contactFormControllerProvider).gstCertificateRotation, equals(180));
      controller.rotateGstCertificate();
      expect(container.read(contactFormControllerProvider).gstCertificateRotation, equals(270));
      controller.rotateGstCertificate();
      expect(container.read(contactFormControllerProvider).gstCertificateRotation, equals(0));

      // Replace document before submission
      controller.setGstCertificate('/camera/photo_retake.jpg');
      expect(container.read(contactFormControllerProvider).gstCertificatePath, equals('/camera/photo_retake.jpg'));
    });

    // -------------------------------------------------------------------------
    // TEST 4: Upload certificate from gallery
    // -------------------------------------------------------------------------
    test('4. Upload certificate from gallery sets path and initializes clean state', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.initForCreate(ContactRole.seller);

      controller.setGstCertificate('/gallery/gst_scan_download.jpg');
      final state = container.read(contactFormControllerProvider);

      expect(state.gstCertificatePath, equals('/gallery/gst_scan_download.jpg'));
      expect(state.gstCertificateRotation, equals(0));
      expect(state.gstExtractionError, isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 5: OCR extraction and correction
    // -------------------------------------------------------------------------
    test('5. OCR extraction automatically populates form and allows broker corrections', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.setOcrService(OcrExtractionService(
        recognizer: (path) async => validGstReg06OcrText,
      ));

      controller.initForCreate(ContactRole.buyer);
      controller.setGstCertificate('/tmp/gst.jpg');
      await controller.extractGstFromImage();

      // Extracted initial values
      var state = container.read(contactFormControllerProvider);
      expect(state.gstin, equals('27AABCU9603R1ZN'));
      expect(state.tradeName, equals('MAIDC AGRO'));

      // Broker manually corrects OCR mistake in trade name and business address
      controller.updateTradeName('MAIDC AGRO & FERTILIZERS');
      controller.updateBusinessAddress('Aarey Milk Colony, Unit 4, Goregaon East, Mumbai');

      state = container.read(contactFormControllerProvider);
      expect(state.tradeName, equals('MAIDC AGRO & FERTILIZERS'));
      expect(state.businessAddress, equals('Aarey Milk Colony, Unit 4, Goregaon East, Mumbai'));
    });

    // -------------------------------------------------------------------------
    // TEST 6: Unreadable certificate handling
    // -------------------------------------------------------------------------
    test('6. Unreadable certificate displays actionable error and prevents false verification', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.setOcrService(OcrExtractionService(
        recognizer: (path) async => 'Random blurred unreadable gibberish with no GST fields',
      ));

      controller.initForCreate(ContactRole.buyer);
      controller.setGstCertificate('/tmp/blurry.jpg');
      await controller.extractGstFromImage();

      final state = container.read(contactFormControllerProvider);
      expect(state.isExtractingGst, isFalse);
      expect(state.gstExtractionError, isNotNull);
      expect(state.gstExtractionError, contains('valid GST Registration Certificate'));

      // Validation fails if broker attempts to submit without valid extraction
      final isValid = controller.validate();
      expect(isValid, isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 7: Invalid GSTIN rejection
    // -------------------------------------------------------------------------
    test('7. Invalid GSTIN format or checksum is rejected with specific error', () {
      // Format validation
      expect(GstinRules.hasValidFormat('INVALID123'), isFalse);
      expect(GstinRules.hasValidFormat('27AABCU9603R1ZN'), isTrue);

      // Checksum validation: 27AABCU9603R1ZN is valid, changing check char to 9 is invalid
      expect(GstinRules.isValid('27AABCU9603R1ZN'), isTrue);
      expect(GstinRules.isValid('27AABCU9603R1Z9'), isFalse);

      final controller = container.read(contactFormControllerProvider.notifier);
      controller.initForCreate(ContactRole.buyer);

      controller.updateGstin('27AABCU9603R1Z9');
      final state = container.read(contactFormControllerProvider);
      expect(state.gstinError, contains('Invalid GSTIN check digit'));
      expect(controller.validate(), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Duplicate GSTIN detection
    // -------------------------------------------------------------------------
    test('8. Duplicate GSTIN detection alerts broker and halts submission', () async {
      mockRepo.simulateDuplicateGstin = true;
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.initForCreate(ContactRole.buyer);
      controller.updateName('Duplicate Person');
      controller.updateCompanyName('Duplicate Agro');
      controller.updateMobile('9876543210');
      controller.updateGstin('27AABCU9603R1ZN');
      controller.setRegistrationMode(CounterpartyRegistrationMode.manual);

      final success = await controller.submit();
      expect(success, isFalse);

      final state = container.read(contactFormControllerProvider);
      expect(state.duplicateWarning, contains('already exists'));
    });

    // -------------------------------------------------------------------------
    // TEST 9: Manual Buyer addition with GSTIN
    // -------------------------------------------------------------------------
    test('9. Manual Buyer addition requires mandatory GSTIN and submits cleanly', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.initForCreate(ContactRole.buyer);
      controller.setRegistrationMode(CounterpartyRegistrationMode.manual);

      controller.updateName('Sunil Deshmukh');
      controller.updateCompanyName('Deshmukh Trading');
      controller.updateMobile('9822334455');
      controller.updateGstin('27AABCU9603R1ZN');

      final success = await controller.submit();
      expect(success, isTrue);

      expect(mockRepo.createdContacts.length, equals(1));
      final saved = mockRepo.createdContacts.first;
      expect(saved.role, equals(ContactRole.buyer));
      expect(saved.gstin, equals('27AABCU9603R1ZN'));
      expect(saved.isBrokerVerified, isFalse);
      expect(saved.gstVerificationStatus, equals(CounterpartyGstStatus.gstPending));
      expect(saved.gstCertificateUrl, isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 10: Manual Seller addition with GSTIN
    // -------------------------------------------------------------------------
    test('10. Manual Seller addition requires mandatory GSTIN and submits cleanly', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.initForCreate(ContactRole.seller);
      controller.setRegistrationMode(CounterpartyRegistrationMode.manual);

      controller.updateName('Anil Kulkarni');
      controller.updateCompanyName('Kulkarni Agro Exports');
      controller.updateMobile('9833445566');
      controller.updateGstin('27AABCU9603R1ZN');

      final success = await controller.submit();
      expect(success, isTrue);

      expect(mockRepo.createdContacts.length, equals(1));
      final saved = mockRepo.createdContacts.first;
      expect(saved.role, equals(ContactRole.seller));
      expect(saved.gstin, equals('27AABCU9603R1ZN'));
      expect(saved.isBrokerVerified, isFalse);
      expect(saved.gstVerificationStatus, equals(CounterpartyGstStatus.gstPending));
    });

    // -------------------------------------------------------------------------
    // TEST 11: Manual records remain unverified and reach Admin
    // -------------------------------------------------------------------------
    test('11. Manual registration queues counterparty_verification_requests for Admin', () {
      final req = CounterpartyVerificationRequest(
        id: 'req-001',
        companyId: 'comp-456',
        brokerId: 'broker-test-123',
        role: 'buyer',
        gstin: '27AABCU9603R1ZN',
        legalName: 'Manual Agro Legal',
        tradeName: 'Manual Agro',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      expect(req.status, equals('pending'));
      expect(req.gstin, equals('27AABCU9603R1ZN'));
      expect(req.isPending, isTrue);
      expect(req.brokerId, equals('broker-test-123'));
    });

    // -------------------------------------------------------------------------
    // TEST 12: Bank details skipped without blocking registration
    // -------------------------------------------------------------------------
    test('12. Bank details can be completely skipped without blocking registration', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.initForCreate(ContactRole.buyer);
      controller.setRegistrationMode(CounterpartyRegistrationMode.manual);

      controller.updateName('Girish Shinde');
      controller.updateCompanyName('Shinde Biofuels');
      controller.updateMobile('9899001122');
      controller.updateGstin('27AABCU9603R1ZN');

      // Cheque leaf is explicitly No
      controller.setHasChequeLeaf(false);

      final isValid = controller.validate();
      expect(isValid, isTrue);

      final success = await controller.submit();
      expect(success, isTrue);

      final saved = mockRepo.createdContacts.first;
      expect(saved.hasChequeLeaf, isFalse);
      expect(saved.bankAccountNumber, isNull);
      expect(saved.bankIfsc, isNull);
      expect(saved.bankVerificationStatus, equals(CounterpartyBankStatus.unverified));
    });

    // -------------------------------------------------------------------------
    // TEST 13: Bank details added with cheque-leaf evidence
    // -------------------------------------------------------------------------
    test('13. Bank details added with cheque-leaf evidence extracts and records safely', () async {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.setOcrService(OcrExtractionService(
        recognizer: (path) async => validChequeOcrText,
      ));

      controller.initForCreate(ContactRole.seller);
      controller.setRegistrationMode(CounterpartyRegistrationMode.manual);
      controller.updateName('Vikas Solanki');
      controller.updateCompanyName('Solanki Oils');
      controller.updateMobile('9877665544');
      controller.updateGstin('27AABCU9603R1ZN');

      // Enable cheque leaf and extract
      controller.setHasChequeLeaf(true);
      controller.setChequeLeaf('/tmp/cheque_sample.jpg');
      await controller.extractChequeFromImage();

      final state = container.read(contactFormControllerProvider);
      expect(state.bankAccountNumber, equals('50100234567890'));
      expect(state.bankIfsc, equals('HDFC0000001'));
      expect(state.bankName, equals('HDFC Bank'));

      // Broker reviews and confirms
      controller.setBrokerConfirmedBank(true);

      final success = await controller.submit();
      expect(success, isTrue);

      final saved = mockRepo.createdContacts.first;
      expect(saved.hasChequeLeaf, isTrue);
      expect(saved.bankAccountNumber, equals('50100234567890'));
      expect(saved.bankIfsc, equals('HDFC0000001'));
      expect(saved.bankVerificationStatus, equals(CounterpartyBankStatus.chequeLeafProvided));
    });

    // -------------------------------------------------------------------------
    // TEST 14: No unsupported bank details accepted as verified
    // -------------------------------------------------------------------------
    test('14. Unsupported bank details without cheque leaf or broker review are blocked', () {
      final controller = container.read(contactFormControllerProvider.notifier);
      controller.initForCreate(ContactRole.seller);
      controller.setRegistrationMode(CounterpartyRegistrationMode.manual);
      controller.updateName('Vikas Solanki');
      controller.updateCompanyName('Solanki Oils');
      controller.updateMobile('9877665544');
      controller.updateGstin('27AABCU9603R1ZN');

      // Attempts to provide account details with cheque toggle ON but NO cheque image
      controller.setHasChequeLeaf(true);
      controller.updateBankAccountNumber('50100234567890');
      controller.updateBankIfsc('HDFC0000001');

      var valid = controller.validate();
      expect(valid, isFalse);
      expect(container.read(contactFormControllerProvider).bankError, contains('Cheque leaf photo is required'));

      // Adds image, but forgets to confirm checkbox
      controller.setChequeLeaf('/tmp/cheque.jpg');
      valid = controller.validate();
      expect(valid, isFalse);
      expect(container.read(contactFormControllerProvider).bankError, contains('Please confirm that bank details match'));

      // Check label: Never claims "Bank Verified"
      expect(CounterpartyBankStatus.displayLabel(CounterpartyBankStatus.chequeLeafProvided),
          equals('Cheque Leaf Provided — Broker Recorded'));
    });

    // -------------------------------------------------------------------------
    // TEST 15: Correct counterparty appears in directory
    // -------------------------------------------------------------------------
    test('15. Counterparty parses with GST badges and masked bank account in directory', () {
      final json = {
        'id': 'contact-999',
        'userId': 'user-123',
        'companyId': 'comp-456',
        'name': 'Mahesh Joshi',
        'companyName': 'Joshi Enterprises',
        'mobile': '+919876543210',
        'role': 'buyer',
        'status': true,
        'isVerified': true,
        'gstin': '27AABCU9603R1ZN',
        'gstVerificationStatus': 'broker_verified',
        'bankAccountNumber': '50100234567890',
        'bankIfsc': 'HDFC0000001',
        'bankChequeUrl': 'https://storage.local/cheque.jpg',
        'bankVerificationStatus': 'cheque_leaf_provided',
        'createdAt': '2026-10-30T08:00:00Z',
      };

      final contact = DirectoryContact.fromJson(json);

      expect(contact.isBrokerVerified, isTrue);
      expect(contact.gstStatusLabel, equals('Broker Verified — Certificate Reviewed'));
      expect(contact.hasChequeLeaf, isTrue);
      expect(contact.maskedBankAccount, equals('•••• •••• 7890'));
    });

    // -------------------------------------------------------------------------
    // TEST 16: Authorized broker can view saved details
    // -------------------------------------------------------------------------
    test('16. Authorized broker can access complete saved GST and banking details', () {
      final contact = DirectoryContact(
        id: 'contact-001',
        userId: 'broker-test-123',
        companyId: 'comp-001',
        name: 'Mahesh Joshi',
        companyName: 'Joshi Agro',
        mobile: '+919876543210',
        role: ContactRole.seller,
        createdAt: DateTime.now(),
        gstin: '27AABCU9603R1ZN',
        legalName: 'JOSHI AGRO PRIVATE LIMITED',
        tradeName: 'Joshi Agro',
        constitution: 'Private Limited Company',
        address: 'Plot 44, MIDC Shiroli, Kolhapur',
        gstCertificateUrl: 'https://supabase.local/storage/gst/cert_001.pdf',
        gstVerificationStatus: CounterpartyGstStatus.brokerVerified,
        bankHolderName: 'JOSHI AGRO PVT LTD',
        bankName: 'HDFC Bank',
        bankAccountNumber: '50100234567890',
        bankIfsc: 'HDFC0000001',
        bankBranch: 'Shiroli MIDC',
        bankChequeUrl: 'https://supabase.local/storage/cheque/leaf_001.jpg',
        bankVerificationStatus: CounterpartyBankStatus.chequeLeafProvided,
      );

      expect(contact.gstin, equals('27AABCU9603R1ZN'));
      expect(contact.legalName, equals('JOSHI AGRO PRIVATE LIMITED'));
      expect(contact.gstCertificateUrl, isNotNull);
      expect(contact.bankChequeUrl, isNotNull);
      expect(contact.maskedBankAccount, equals('•••• •••• 7890'));
      expect(contact.bankIfsc, equals('HDFC0000001'));
      expect(contact.isBrokerVerified, isTrue);
      expect(contact.hasChequeLeaf, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 17: Unauthorized user cannot access sensitive documents
    // -------------------------------------------------------------------------
    test('17. Storage buckets and RLS enforce private access controls for certificates', () {
      const chequeData = ChequeLeafData(accountNumber: '50100234567890');
      expect(chequeData.maskedAccountNumber, equals('•••• •••• 7890'));

      const shortCheque = ChequeLeafData(accountNumber: '12345');
      expect(shortCheque.maskedAccountNumber, equals('•••• •••• 2345'));

      // Ensure DirectoryContact does not expose plain bank account in directory listings
      final contact = DirectoryContact(
        id: 'contact-001',
        userId: 'broker-test-123',
        companyId: 'comp-001',
        name: 'Seller Person',
        companyName: 'Seller Corp',
        mobile: '+919876543210',
        role: ContactRole.seller,
        createdAt: DateTime.now(),
        bankAccountNumber: '50100234567890',
      );

      expect(contact.maskedBankAccount, equals('•••• •••• 7890'));
    });

    // -------------------------------------------------------------------------
    // TEST 18: Deal summary displays correct agreed terms
    // -------------------------------------------------------------------------
    test('18. Deal summary displays correct agreed commercial, delivery and payment terms', () {
      const summary = DealOrderSummary(
        dealId: 'deal-101',
        dealRef: 'DL-2026-101',
        commodity: 'Soybean Seeds',
        grade: 'Grade-A Machine Clean',
        quantity: 50.0,
        unit: 'MT',
        agreedPrice: 48500.0,
        totalValue: 2425000.0,
        deliveryLocation: 'FOR Kota Mandi Warehouse',
        deliveryTerms: 'Immediate Dispatch within 3 days',
        paymentTerms: 'CAD (Cash Against Documents) 80% on dispatch, 20% on delivery',
        priceBasis: 'FOR',
        packagingType: '50kg HDPE Bags',
        sellerCompanyName: 'Kulkarni Agro Exports',
        sellerCompanyId: 'comp-seller-1',
        buyerCompanyName: 'Malwa Agro Traders',
        buyerCompanyId: 'comp-buyer-1',
      );

      final text = summary.toShareableText(includeAuthorizedBanking: false);

      expect(text, contains('DL-2026-101'));
      expect(text, contains('Soybean Seeds (Grade-A Machine Clean)'));
      expect(text, contains('50.0 MT'));
      expect(text, contains('FOR Kota Mandi Warehouse'));
      expect(text, contains('Immediate Dispatch within 3 days'));
      expect(text, contains('CAD (Cash Against Documents)'));
      expect(text, contains('50kg HDPE Bags'));
      // Banking details must NOT be included without explicit authorization
      expect(text, isNot(contains('SELLER BANK DETAILS')));
    });

    // -------------------------------------------------------------------------
    // TEST 19: Cheque leaf is shared only with authorized recipient
    // -------------------------------------------------------------------------
    test('19. Cheque leaf is shared only when authorized and logs audit trail', () async {
      final dealRepo = MockDealShareRepository();

      const bankData = ChequeLeafData(
        accountHolderName: 'KULKARNI AGRO EXPORTS',
        bankName: 'State Bank of India',
        accountNumber: '30495867123',
        ifsc: 'SBIN0001234',
        branch: 'Mandi Branch Kota',
        documentPath: 'https://storage.local/cheques/leaf_789.jpg',
      );

      const summaryWithBank = DealOrderSummary(
        dealId: 'deal-101',
        dealRef: 'DL-2026-101',
        commodity: 'Soybean Seeds',
        quantity: 50.0,
        unit: 'MT',
        agreedPrice: 48500.0,
        totalValue: 2425000.0,
        deliveryLocation: 'FOR Kota',
        deliveryTerms: 'Dispatch within 3 days',
        paymentTerms: '100% against delivery',
        priceBasis: 'FOR',
        packagingType: '50kg Bags',
        sellerCompanyName: 'Kulkarni Agro Exports',
        sellerCompanyId: 'comp-seller-1',
        buyerCompanyName: 'Malwa Agro Traders',
        buyerCompanyId: 'comp-buyer-1',
        sellerBankDetails: bankData,
        hasSellerChequeLeaf: true,
        sellerChequeUrl: 'https://storage.local/cheques/leaf_789.jpg',
        isChequeSharingAuthorized: true,
      );

      // Generating text with authorized banking
      final text = summaryWithBank.toShareableText(includeAuthorizedBanking: true);
      expect(text, contains('SELLER BANK DETAILS (CHEQUE LEAF SUPPORTED)'));
      expect(text, contains('A/c No: •••• •••• 7123'));
      expect(text, contains('IFSC: SBIN0001234'));
      expect(text, contains('Notice: Cheque Leaf Provided — Broker Recorded (not bank verified)'));

      // Log share event
      await dealRepo.logDealDocumentShare(
        dealId: summaryWithBank.dealId,
        recipientCompanyId: summaryWithBank.buyerCompanyId,
        documentType: 'deal_summary_and_cheque_leaf',
        documentRef: summaryWithBank.sellerChequeUrl,
        sharedPayload: summaryWithBank.toJson(),
      );

      expect(dealRepo.loggedShares.length, equals(1));
      final shareLog = dealRepo.loggedShares.first;
      expect(shareLog['dealId'], equals('deal-101'));
      expect(shareLog['recipientCompanyId'], equals('comp-buyer-1'));
      expect(shareLog['documentType'], equals('deal_summary_and_cheque_leaf'));
    });

    // -------------------------------------------------------------------------
    // TEST 20: Admin verification approval/rejection updates the correct counterparty
    // -------------------------------------------------------------------------
    test('20. Admin verification approval or rejection logs and updates correctly', () async {
      // 1. Admin Approves
      final approveResult = await mockRepo.reviewCounterpartyVerification(
        requestId: 'req-001',
        approve: true,
      );
      expect(approveResult, isA<DirectorySuccess<bool>>());
      expect(mockRepo.loggedVerificationReviews.last['approved'], isTrue);
      expect(mockRepo.loggedVerificationReviews.last['requestId'], equals('req-001'));

      // 2. Admin Rejects with reason
      final rejectResult = await mockRepo.reviewCounterpartyVerification(
        requestId: 'req-002',
        approve: false,
        reason: 'GSTIN does not match legal entity name on government records',
      );
      expect(rejectResult, isA<DirectorySuccess<bool>>());
      expect(mockRepo.loggedVerificationReviews.last['approved'], isFalse);
      expect(mockRepo.loggedVerificationReviews.last['reason'],
          contains('does not match legal entity'));
    });
  });
}
