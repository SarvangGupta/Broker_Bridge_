import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_document_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';
import 'package:rmseller_mobile/features/profile/presentation/profile_strings.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';
import 'package:rmseller_mobile/features/profile/presentation/widgets/invoice_preview_dialog.dart';
import 'package:rmseller_mobile/features/profile/presentation/widgets/profile_review_confirmation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storage;
  late SellerProfileRepository repository;

  const sampleProfile = SellerProfileModel(
    id: '20000000-0000-0000-0000-000000000001',
    fullName: 'Ramesh Kumar',
    companyName: 'Bikaner Agro Processing Ltd',
    mobile: '9829012345',
    email: 'ramesh@bikaneragro.com',
    role: 'seller',
    companyGst: '08AAAAA0000A1Z5',
    officeAddress: 'Commercial Tower 4, Bikaner HQ',
    state: 'Rajasthan',
    district: 'Bikaner',
  );

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
    repository = SellerProfileRepository(storage: storage);
    await repository.updateProfile(sampleProfile);
  });

  Widget createTestWidget({
    bool isInitialEdit = true,
    bool isHindi = false,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: SellerProfileScreen(
          profileRepository: repository,
          storageService: storage,
          isInitialEdit: isInitialEdit,
          isHindi: isHindi,
        ),
      ),
    );
  }

  group('RB-SELLER-I18N-OCR-01: Bilingual English & Hindi Verification', () {
    testWidgets('1. English Edit Profile renders all mandatory sprint strings correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(isInitialEdit: true, isHindi: false));
      await tester.pumpAndSettle();

      // Screen title and action buttons
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Intake options
      expect(find.text('Scan Business Invoice'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('PDF / File'), findsOneWidget);

      // Group headers and field labels
      expect(find.text('Business Details'), findsOneWidget);
      expect(find.text('Business Name *'), findsOneWidget);
      expect(find.text('Corporate Office HQ Address'), findsOneWidget);

      // Data values preserved as entered
      expect(find.text('Bikaner Agro Processing Ltd'), findsWidgets);
      expect(find.text('Commercial Tower 4, Bikaner HQ'), findsOneWidget);
    });

    testWidgets('2. Hindi Edit Profile renders all mandatory translated table strings correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(isInitialEdit: true, isHindi: true));
      await tester.pumpAndSettle();

      // Screen title and action buttons in Hindi
      expect(find.text('प्रोफ़ाइल संपादित करें'), findsOneWidget);
      expect(find.text('रद्द करें'), findsOneWidget);
      expect(find.text('सेव करें'), findsOneWidget);

      // Intake options in Hindi
      expect(find.text('व्यवसाय का बिल स्कैन करें'), findsOneWidget);
      expect(find.text('कैमरा'), findsOneWidget);
      expect(find.text('गैलरी'), findsOneWidget);
      expect(find.text('PDF / फ़ाइल'), findsOneWidget);

      // Group headers and field labels in Hindi
      expect(find.text('व्यवसाय का विवरण'), findsOneWidget);
      expect(find.text('व्यवसाय का नाम *'), findsOneWidget);
      expect(find.text('कॉर्पोरेट कार्यालय का मुख्य पता'), findsOneWidget);

      // Commodity expertise section in Hindi
      expect(find.text('मेरी कमोडिटी विशेषज्ञता'), findsOneWidget);
      expect(find.text('कमोडिटी जोड़ें'), findsOneWidget);

      // Data values must remain uncorrupted and never translated
      expect(find.text('Bikaner Agro Processing Ltd'), findsWidgets);
      expect(find.text('Commercial Tower 4, Bikaner HQ'), findsOneWidget);
      expect(find.text('08AAAAA0000A1Z5'), findsOneWidget);
    });

    testWidgets('3. Immediate language toggling switches language in-place without data loss', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(isInitialEdit: true, isHindi: false));
      await tester.pumpAndSettle();

      // Initially English
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Scan Business Invoice'), findsOneWidget);

      // Tap language switcher button
      final toggleBtn = find.byKey(const Key('toggle_profile_language_button'));
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Instantly switches to Hindi
      expect(find.text('प्रोफ़ाइल संपादित करें'), findsOneWidget);
      expect(find.text('व्यवसाय का बिल स्कैन करें'), findsOneWidget);
      expect(find.text('कैमरा'), findsOneWidget);
      expect(find.text('व्यवसाय का विवरण'), findsOneWidget);

      // Tap again to switch back to English
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Scan Business Invoice'), findsOneWidget);
      expect(find.text('Business Details'), findsOneWidget);
    });

    testWidgets('4. ProfileReviewConfirmationSheet displays bilingual strings and explicit confirmation button', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Test English Sheet
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileReviewConfirmationSheet(
              currentProfile: sampleProfile,
              proposedProfile: sampleProfile.copyWith(companyName: 'New Proposed Mills Ltd'),
              onConfirm: () {},
              onCancel: () {},
              strings: const ProfileStrings(isHindi: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review Extracted Details'), findsOneWidget);
      expect(find.text('Confirm and Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Test Hindi Sheet
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileReviewConfirmationSheet(
              currentProfile: sampleProfile,
              proposedProfile: sampleProfile.copyWith(companyName: 'New Proposed Mills Ltd'),
              onConfirm: () {},
              onCancel: () {},
              strings: const ProfileStrings(isHindi: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('निकाली गई जानकारी की समीक्षा करें'), findsOneWidget);
      expect(find.text('पुष्टि करें और सेव करें'), findsOneWidget);
      expect(find.text('रद्द करें'), findsOneWidget);
      expect(find.text('New Proposed Mills Ltd'), findsOneWidget);
    });

    testWidgets('5. InvoicePreviewDialog displays Retry Scan and status indicators bilingually', (tester) async {
      const draftDoc = SelectedInvoiceDocument(
        fileName: 'Invoice_184.pdf',
        fileSizeBytes: 446336,
        localPath: '/tmp/Invoice_184.pdf',
        isUploaded: false,
      );

      // English Preview Dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvoicePreviewDialog(
              document: draftDoc,
              strings: const ProfileStrings(isHindi: false),
              onRetakeCamera: () {},
              onReplaceGallery: () {},
              onRemove: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry Scan'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.byTooltip('Remove Document'), findsOneWidget);

      // Hindi Preview Dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvoicePreviewDialog(
              document: draftDoc,
              strings: const ProfileStrings(isHindi: true),
              onRetakeCamera: () {},
              onReplaceGallery: () {},
              onRemove: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('दोबारा स्कैन करें'), findsOneWidget);
      expect(find.text('गैलरी'), findsOneWidget);
      expect(find.byTooltip('दस्तावेज़ हटाएं'), findsOneWidget);
    });

    testWidgets('6. Small screen layout (320x640) has zero overflow in English and Hindi', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Small screen test in Hindi
      await tester.pumpWidget(
        createTestWidget(
          isInitialEdit: true,
          isHindi: true,
        ),
      );
      await tester.pumpAndSettle();

      // No overflow error logged
      expect(tester.takeException(), isNull);
      expect(find.text('प्रोफ़ाइल संपादित करें'), findsOneWidget);
      expect(find.text('व्यवसाय का बिल स्कैन करें'), findsOneWidget);

      // Small screen test in English
      await tester.pumpWidget(
        createTestWidget(
          isInitialEdit: true,
          isHindi: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Profile'), findsOneWidget);
    });
  });
}
