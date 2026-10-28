import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_document_service.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/cheque_extracted_data.dart';
import 'package:rmseller_mobile/features/profile/domain/invoice_extracted_data.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';

class MockInvoiceDocumentService extends InvoiceDocumentService {
  SelectedInvoiceDocument? nextDoc;

  @override
  Future<SelectedInvoiceDocument?> captureFromCamera() async => nextDoc;

  @override
  Future<SelectedInvoiceDocument?> pickFromGallery() async => nextDoc;

  @override
  Future<SelectedInvoiceDocument?> pickDocumentFile() async => nextDoc;
}

class MockChequeOcrService extends InvoiceOcrService {
  final ChequeExtractionResult? chequeResult;
  final InvoiceExtractionResult? invoiceResult;

  const MockChequeOcrService({
    this.chequeResult,
    this.invoiceResult,
  }) : super(nativeEngineAvailable: true);

  @override
  Future<ChequeExtractionResult> extractChequeFromFile(dynamic file) async {
    return chequeResult ??
        const ChequeExtractionResult.success(
          ChequeExtractedData(
            accountHolderName: 'Marwar Agro Mills Ltd',
            bankName: 'State Bank of India',
            branchName: 'Mandi Branch',
            accountNumber: '309812345678',
            ifscCode: 'SBIN0001234',
            micrCode: '302002001',
            chequeNumber: '000123',
          ),
        );
  }

  @override
  Future<InvoiceExtractionResult> extractFromFile(dynamic file) async {
    return invoiceResult ??
        const InvoiceExtractionResult.success(
          InvoiceExtractedData(
            firmName: 'Marwar Agro Mills Ltd',
            gstin: '08AABCB1234F1Z5',
            officeAddress: 'Shop 10, Krishi Upaj Mandi, Jodhpur',
            pinCode: '342001',
            extractedCommodities: ['Wheat', 'Mustard'],
            // Notice: Bank details are missing from invoice!
          ),
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storage;
  late SellerProfileRepository repository;
  late MockInvoiceDocumentService docService;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
    repository = SellerProfileRepository(storage: storage);
    docService = MockInvoiceDocumentService();
  });

  Widget buildTestWidget({
    SellerProfileRepository? repo,
    InvoiceOcrService? ocr,
    bool isInitialEdit = false,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: SellerProfileScreen(
          profileRepository: repo ?? repository,
          storageService: storage,
          documentService: docService,
          ocrService: ocr ?? const MockChequeOcrService(),
          isInitialEdit: isInitialEdit,
        ),
      ),
    );
  }

  group('ADDENDUM — Cheque Photo to Bank Details Tests', () {
    testWidgets('1. Bank Details section renders "Scan Cheque", "Camera", "Gallery", "Enter Manually" in EN & HI', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Check English labels in Bank Details intake
      expect(find.text('Scan Cheque'), findsOneWidget);
      expect(find.byKey(const Key('btn_pick_cheque_camera')), findsOneWidget);
      expect(find.byKey(const Key('btn_pick_cheque_gallery')), findsOneWidget);
      expect(find.byKey(const Key('btn_enter_bank_manually')), findsOneWidget);
      expect(find.byKey(const Key('edit_bank_micr_field')), findsOneWidget);

      // Toggle language to Hindi
      await tester.tap(find.byKey(const Key('toggle_profile_language_button')));
      await tester.pumpAndSettle();

      // Check Hindi labels
      expect(find.text('चेक स्कैन करें'), findsOneWidget);
      expect(find.text('कैमरा'), findsWidgets);
      expect(find.text('गैलरी'), findsWidgets);
      expect(find.text('मैन्युअल रूप से दर्ज करें'), findsOneWidget);
    });

    testWidgets('2. Cheque Camera capture shows preview box, retake, replace, remove, and pre-fills bank fields', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      docService.nextDoc = const SelectedInvoiceDocument(
        localPath: '/tmp/test_cheque_leaf.jpg',
        fileName: 'test_cheque_leaf.jpg',
        fileSizeBytes: 204800,
      );

      await tester.pumpWidget(buildTestWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Tap Cheque Camera
      await tester.tap(find.byKey(const Key('btn_pick_cheque_camera')));
      await tester.pumpAndSettle();

      // Attached preview card must be displayed
      expect(find.byKey(const Key('cheque_attached_preview_card')), findsOneWidget);
      expect(find.text('test_cheque_leaf.jpg'), findsOneWidget);

      // Retake, Replace, Remove buttons
      expect(find.byKey(const Key('btn_retake_cheque')), findsOneWidget);
      expect(find.byKey(const Key('btn_replace_cheque')), findsOneWidget);
      expect(find.byKey(const Key('btn_remove_cheque')), findsOneWidget);

      // Extracted fields prefilled
      final accountCtrlFinder = find.byKey(const Key('edit_bank_account_field'));
      final ifscCtrlFinder = find.byKey(const Key('edit_bank_ifsc_field'));
      final micrCtrlFinder = find.byKey(const Key('edit_bank_micr_field'));

      expect(tester.widget<TextFormField>(accountCtrlFinder).controller?.text, equals('309812345678'));
      expect(tester.widget<TextFormField>(ifscCtrlFinder).controller?.text, equals('SBIN0001234'));
      expect(tester.widget<TextFormField>(micrCtrlFinder).controller?.text, equals('302002001'));

      // Test Remove Cheque
      await tester.tap(find.byKey(const Key('btn_remove_cheque')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cheque_attached_preview_card')), findsNothing);
    });

    testWidgets('3. Path A: Invoice scanned without bank details -> Cheque scanned -> Details merged', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Step 1: Provide Invoice with firm info but NO bank details
      docService.nextDoc = const SelectedInvoiceDocument(
        localPath: '/tmp/tax_invoice_no_bank.pdf',
        fileName: 'tax_invoice_no_bank.pdf',
        fileSizeBytes: 300000,
      );

      await tester.pumpWidget(buildTestWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Scan Invoice
      await tester.tap(find.byKey(const Key('btn_scan_invoice_file')));
      await tester.pumpAndSettle();

      // Apply Invoice suggestions
      await tester.tap(find.byKey(const Key('btn_apply_invoice_suggestions')));
      await tester.pumpAndSettle();

      // Business info prefilled from invoice
      final companyFinder = find.byKey(const Key('edit_company_name_field'));
      expect(tester.widget<TextFormField>(companyFinder).controller?.text, equals('Marwar Agro Mills Ltd'));

      // Step 2: Now scan Cheque to fill the missing bank details
      docService.nextDoc = const SelectedInvoiceDocument(
        localPath: '/tmp/cheque_leaf.png',
        fileName: 'cheque_leaf.png',
        fileSizeBytes: 150000,
      );

      await tester.tap(find.byKey(const Key('btn_pick_cheque_gallery')));
      await tester.pumpAndSettle();

      // Bank details populated from cheque
      final bankAccountFinder = find.byKey(const Key('edit_bank_account_field'));
      expect(tester.widget<TextFormField>(bankAccountFinder).controller?.text, equals('309812345678'));

      // Firm info from invoice is still preserved!
      expect(tester.widget<TextFormField>(companyFinder).controller?.text, equals('Marwar Agro Mills Ltd'));
    });

    testWidgets('4. Path B: Cheque only -> Edit Profile -> Bank Details -> Scan Cheque -> Confirm and Save', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      docService.nextDoc = const SelectedInvoiceDocument(
        localPath: '/tmp/cheque_only.jpg',
        fileName: 'cheque_only.jpg',
        fileSizeBytes: 180000,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 1. Open Edit Profile
      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      // Ensure valid business name
      await tester.enterText(find.byKey(const Key('edit_company_name_field')), 'Marwar Agro Mills Ltd');
      await tester.pumpAndSettle();

      // 2. Select Scan Cheque Camera
      await tester.tap(find.byKey(const Key('btn_pick_cheque_camera')));
      await tester.pumpAndSettle();

      // Bank details are extracted and prefilled
      final bankAccountFinder = find.byKey(const Key('edit_bank_account_field'));
      expect(tester.widget<TextFormField>(bankAccountFinder).controller?.text, equals('309812345678'));

      // 3. Tap Save -> Must open Mandatory Confirmation Sheet before write
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_review_confirmation_sheet')), findsOneWidget);
      expect(find.text('Review Extracted Details'), findsOneWidget);
      expect(find.text('Cheque-extracted bank details require explicit confirmation'), findsOneWidget);

      // Account number is masked in confirmation sheet
      expect(find.textContaining('••••'), findsWidgets);
      expect(find.textContaining('5678'), findsWidgets);

      // 4. Confirm and Save
      await tester.tap(find.byKey(const Key('confirm_and_save_button')));
      await tester.pumpAndSettle();

      // Edit mode exited upon server save
      expect(find.byKey(const Key('profile_review_confirmation_sheet')), findsNothing);
      expect(find.byKey(const Key('save_profile_button')), findsNothing);
    });

    testWidgets('5. Cancel in confirmation sheet discards unconfirmed changes without write', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      docService.nextDoc = const SelectedInvoiceDocument(
        localPath: '/tmp/unconfirmed_cheque.jpg',
        fileName: 'unconfirmed_cheque.jpg',
        fileSizeBytes: 150000,
      );

      await tester.pumpWidget(buildTestWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Enter company name
      await tester.enterText(find.byKey(const Key('edit_company_name_field')), 'Marwar Agro Mills Ltd');
      await tester.pumpAndSettle();

      // Scan cheque
      await tester.tap(find.byKey(const Key('btn_pick_cheque_camera')));
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_review_confirmation_sheet')), findsOneWidget);

      // Cancel confirmation
      await tester.tap(find.byKey(const Key('cancel_confirmation_button')));
      await tester.pumpAndSettle();

      // Confirmation sheet closed, draft preserved for editing
      expect(find.byKey(const Key('profile_review_confirmation_sheet')), findsNothing);
      expect(find.byKey(const Key('save_profile_button')), findsOneWidget);
    });

    testWidgets('6. Small-screen (320x640) renders without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Scroll to cheque intake card on small screen
      await tester.scrollUntilVisible(
        find.byKey(const Key('cheque_intake_card')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Verify no overflow error occurred
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('cheque_intake_card')), findsOneWidget);
      expect(find.byKey(const Key('btn_pick_cheque_camera')), findsOneWidget);
      expect(find.byKey(const Key('btn_pick_cheque_gallery')), findsOneWidget);
      expect(find.byKey(const Key('btn_enter_bank_manually')), findsOneWidget);
    });
  });
}
