import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/invoice_extracted_data.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_bank_details.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';

class MockInvoiceOcrService extends InvoiceOcrService {
  final InvoiceExtractedData mockData;

  const MockInvoiceOcrService({required this.mockData}) : super(nativeEngineAvailable: true);

  @override
  InvoiceExtractedData extractFromText(String rawText) {
    return mockData;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storage;
  late SellerProfileRepository repository;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
    repository = SellerProfileRepository(storage: storage);
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
          ocrService: ocr,
          isInitialEdit: isInitialEdit,
        ),
      ),
    );
  }

  group('RB-SELLER-PROFILE-INVOICE-01: Profile & Invoice UI Workflow Tests', () {
    testWidgets('1. Profile overflow menu contains "Scan Business Invoice"', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open overflow menu
      await tester.tap(find.byKey(const Key('profile_overflow_menu')));
      await tester.pumpAndSettle();

      // Verify Scan Business Invoice menu item
      expect(find.byKey(const Key('profile_menu_scan_invoice')), findsOneWidget);
      expect(find.text('Scan Business Invoice'), findsNWidgets(2)); // Menu item + Header banner
    });

    testWidgets('2. View Mode renders dedicated Bank Details section with masked account number', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Save a bank profile first
      final initial = await repository.getProfile();
      await repository.updateProfile(
        initial.copyWith(
          bankDetails: const SellerBankDetails(
            accountHolderName: 'Goyal Agro Trading Co',
            bankName: 'State Bank of India',
            accountNumber: '112233445566',
            ifscCode: 'SBIN0001234',
            branchName: 'Bikaner Mandi',
            isVerified: false,
          ),
        ),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify Bank Details accordion exists
      expect(find.byKey(const Key('profile_section_bank')), findsOneWidget);
      expect(find.text('Bank Details'), findsOneWidget);

      // Expand Bank Details section
      await tester.tap(find.byKey(const Key('profile_section_bank')));
      await tester.pumpAndSettle();

      // Check fields rendered
      expect(find.text('Beneficiary'), findsOneWidget);
      expect(find.text('Goyal Agro Trading Co'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(find.text('State Bank of India'), findsOneWidget);

      // Privacy verification: Account number must be masked (ending in 5566)
      expect(find.textContaining('••••'), findsWidgets);
      expect(find.textContaining('5566'), findsWidgets);
      expect(find.text('112233445566'), findsNothing); // Never plain in view mode!

      // Unverified status badge
      expect(find.text('Unverified'), findsOneWidget);
    });

    testWidgets('3. Edit Mode provides Bank Details form fields with validations', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Verify bank input controllers
      expect(find.byKey(const Key('edit_bank_holder_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_bank_name_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_bank_account_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_bank_ifsc_field')), findsOneWidget);

      // Verify Zero-Secret Policy notice
      expect(find.textContaining('Zero-Secret Policy'), findsOneWidget);

      // Enter invalid IFSC
      await tester.enterText(find.byKey(const Key('edit_bank_ifsc_field')), 'INVALIDIFSC');
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter a valid 11-digit IFSC code'), findsOneWidget);
    });

    testWidgets('4. Mandatory Confirmation Workflow: No write before explicit "Confirm and Save"', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Enter Edit Mode
      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      // Enter updated business details
      await tester.enterText(find.byKey(const Key('edit_company_name_field')), 'Thar Agro Processing Ltd');
      await tester.enterText(find.byKey(const Key('edit_bank_name_field')), 'HDFC Bank');
      await tester.enterText(find.byKey(const Key('edit_bank_account_field')), '987654321098');
      await tester.enterText(find.byKey(const Key('edit_bank_ifsc_field')), 'HDFC0001234');

      // Tap Save button: MUST NOT immediately write to repository
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      // Verify Mandatory Confirmation Sheet is displayed
      expect(find.byKey(const Key('profile_review_confirmation_sheet')), findsOneWidget);
      expect(find.text('Review Profile Changes'), findsOneWidget);
      expect(find.byKey(const Key('confirm_and_save_button')), findsOneWidget);
      expect(find.byKey(const Key('cancel_confirmation_button')), findsOneWidget);

      // Verify Side-by-Side Diff table displays Current vs Proposed in confirmation sheet
      expect(
        find.descendant(
          of: find.byKey(const Key('profile_review_confirmation_sheet')),
          matching: find.text('Thar Agro Processing Ltd'),
        ),
        findsOneWidget,
      );

      // Dismissal / Cancel step: Tapping Keep Editing must not save changes
      await tester.tap(find.byKey(const Key('cancel_confirmation_button')));
      await tester.pumpAndSettle();

      // Confirmation sheet closed; still in Edit mode
      expect(find.byKey(const Key('profile_review_confirmation_sheet')), findsNothing);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Repository still holds initial name
      final profileAfterCancel = await repository.getProfile();
      expect(profileAfterCancel.companyName, isNot('Thar Agro Processing Ltd'));

      // Re-trigger Save and explicitly tap "Confirm and Save"
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm_and_save_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_and_save_button')));
      await tester.pumpAndSettle();

      // Authoritative Save Success
      expect(find.text('Business profile updated successfully'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget); // Returned to View Mode
      expect(find.text('Thar Agro Processing Ltd'), findsOneWidget);

      // Verify audit entry was logged
      final audit = await repository.getProfileAuditHistory(sellerId: profileAfterCancel.id, checkAdminRole: false);
      expect(audit.length, 1);
      expect(audit.first.changeSummary, contains('Thar Agro Processing Ltd'));
      expect(audit.first.changeSummary, contains('...1098')); // Masked account in audit
    });

    testWidgets('5. Invoice scanning card renders Camera, Gallery, and PDF buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_invoice_document_card')), findsOneWidget);
      expect(find.byKey(const Key('btn_scan_invoice_camera')), findsOneWidget);
      expect(find.byKey(const Key('btn_scan_invoice_gallery')), findsOneWidget);
      expect(find.byKey(const Key('btn_scan_invoice_file')), findsOneWidget);
    });
  });
}
