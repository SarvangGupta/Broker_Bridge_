import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/invoice_extracted_data.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';

class MockIntelligenceOcrService extends InvoiceOcrService {
  final InvoiceExtractedData mockData;

  const MockIntelligenceOcrService({required this.mockData})
      : super(nativeEngineAvailable: true);

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
    InvoiceExtractedData? initialInvoiceData,
    bool isInitialEdit = true,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: SellerProfileScreen(
          profileRepository: repo ?? repository,
          storageService: storage,
          ocrService: ocr,
          initialExtractedInvoiceData: initialInvoiceData,
          isInitialEdit: isInitialEdit,
        ),
      ),
    );
  }

  group('RB-SELLER-OCR-INTELLIGENCE-01: OCR Intelligence & Multilingual UI Tests', () {
    testWidgets('1. Applies genuine Hindi invoice suggestions and renders Devanagari text in form', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const hindiExtracted = InvoiceExtractedData(
        firmName: 'श्री बालाजी एग्रो ट्रेडर्स',
        gstin: '08AABCB1234F1Z5',
        officeAddress: 'दुकान नं. ४५, नई कृषि उपज मंडी परिसर, बीकानेर, राजस्थान',
        pinCode: '334001',
        state: 'Rajasthan',
        district: 'Bikaner Mandi Hub',
        contactMobile: '9829012345',
        accountNumber: '334455667788',
        ifscCode: 'SBIN0001234',
        bankName: 'भारतीय स्टेट बैंक',
        accountHolderName: 'श्री बालाजी एग्रो ट्रेडर्स',
        isHindiDocument: true,
      );

      final ocrService = MockIntelligenceOcrService(mockData: hindiExtracted);

      await tester.pumpWidget(buildTestWidget(
        ocr: ocrService,
        initialInvoiceData: hindiExtracted,
      ));
      await tester.pumpAndSettle();

      // Trigger apply suggestions button
      expect(find.byKey(const Key('btn_apply_invoice_suggestions')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_apply_invoice_suggestions')));
      await tester.pumpAndSettle();

      // Verify Hindi firm name and multi-line address are rendered exactly in Devanagari
      final companyField = tester.widget<TextFormField>(find.byKey(const Key('edit_company_name_field')));
      expect(companyField.controller?.text, 'श्री बालाजी एग्रो ट्रेडर्स');

      final gstField = tester.widget<TextFormField>(find.byKey(const Key('edit_gstin_field')));
      expect(gstField.controller?.text, '08AABCB1234F1Z5');

      final addressField = tester.widget<TextFormField>(find.byKey(const Key('edit_office_address_field')));
      expect(addressField.controller?.text, 'दुकान नं. ४५, नई कृषि उपज मंडी परिसर, बीकानेर, राजस्थान');

      final pinField = tester.widget<TextFormField>(find.byKey(const Key('edit_location_pincode_field')));
      expect(pinField.controller?.text, '334001');

      // Verify state and district were auto-suggested
      expect(find.text('Rajasthan'), findsWidgets);
      expect(find.text('Bikaner Mandi Hub'), findsWidgets);
    });

    testWidgets('2. OCR operates independently of app display language (Hindi doc on English UI)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mixedData = InvoiceExtractedData(
        firmName: 'मारवाड़ एग्रो इंडस्ट्रीज Pvt Ltd',
        gstin: '08XYZPA5544L1Z2',
        officeAddress: 'Industrial Area, Mandi Road, Kota, Rajasthan',
        pinCode: '324005',
        state: 'Rajasthan',
        district: 'Kota Agro Mandi',
      );

      await tester.pumpWidget(buildTestWidget(
        ocr: MockIntelligenceOcrService(mockData: mixedData),
        initialInvoiceData: mixedData,
      ));
      await tester.pumpAndSettle();

      // App UI is in English: Verify English headers
      expect(find.text('Business Details'), findsOneWidget);
      expect(find.text('Scan Business Invoice'), findsOneWidget);

      // Apply suggestions
      await tester.tap(find.byKey(const Key('btn_apply_invoice_suggestions')));
      await tester.pumpAndSettle();

      // Verify mixed Hindi-English company name is retained in original script
      final companyField = tester.widget<TextFormField>(find.byKey(const Key('edit_company_name_field')));
      expect(companyField.controller?.text, 'मारवाड़ एग्रो इंडस्ट्रीज Pvt Ltd');
    });

    testWidgets('3. English invoice operates cleanly when app display language is toggled to Hindi', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const englishData = InvoiceExtractedData(
        firmName: 'Jaipur Grain Processors Ltd',
        gstin: '08AAACF4321Q1Z8',
        officeAddress: 'Sitapura Industrial Area, Jaipur, Rajasthan',
        pinCode: '302022',
        state: 'Rajasthan',
        district: 'Jaipur Central Depot',
      );

      await tester.pumpWidget(buildTestWidget(
        ocr: MockIntelligenceOcrService(mockData: englishData),
        initialInvoiceData: englishData,
      ));
      await tester.pumpAndSettle();

      // Toggle UI to Hindi
      await tester.tap(find.byKey(const Key('toggle_profile_language_button')));
      await tester.pumpAndSettle();

      // Verify UI labels are in Hindi
      expect(find.text('व्यवसाय का विवरण'), findsOneWidget);
      expect(find.text('व्यवसाय का बिल स्कैन करें'), findsOneWidget);

      // Apply suggestions
      await tester.tap(find.byKey(const Key('btn_apply_invoice_suggestions')));
      await tester.pumpAndSettle();

      // Original English company name and address are preserved without transliteration
      final companyField = tester.widget<TextFormField>(find.byKey(const Key('edit_company_name_field')));
      expect(companyField.controller?.text, 'Jaipur Grain Processors Ltd');

      final addressField = tester.widget<TextFormField>(find.byKey(const Key('edit_office_address_field')));
      expect(addressField.controller?.text, 'Sitapura Industrial Area, Jaipur, Rajasthan');
    });

    testWidgets('4. Displays warning banner when PIN code and address state conflict', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const conflictingData = InvoiceExtractedData(
        firmName: 'Malwa Processing Corp',
        gstin: '23AAACM1122Q1Z4',
        officeAddress: 'Mandi Road, Kota, Rajasthan',
        pinCode: '452001',
        hasPinAddressConflict: true,
        pinConflictNotice: 'PIN code 452001 belongs to Madhya Pradesh, but address mentions Rajasthan.',
      );

      await tester.pumpWidget(buildTestWidget(
        ocr: MockIntelligenceOcrService(mockData: conflictingData),
        initialInvoiceData: conflictingData,
      ));
      await tester.pumpAndSettle();

      // Apply suggestions
      await tester.tap(find.byKey(const Key('btn_apply_invoice_suggestions')));
      await tester.pumpAndSettle();

      // Verify conflict notice is shown in the banner
      expect(find.textContaining('PIN code 452001 belongs to Madhya Pradesh'), findsOneWidget);
    });

    testWidgets('5. Small-screen 320x640 layout stability with Devanagari text without render overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const hindiData = InvoiceExtractedData(
        firmName: 'श्री बालाजी एग्रो ट्रेडर्स प्राइवेट लिमिटेड',
        gstin: '08AABCB1234F1Z5',
        officeAddress: 'दुकान नं. ४५, नई कृषि उपज मंडी परिसर, बीकानेर',
        pinCode: '334001',
      );

      await tester.pumpWidget(buildTestWidget(
        ocr: MockIntelligenceOcrService(mockData: hindiData),
        initialInvoiceData: hindiData,
      ));
      await tester.pumpAndSettle();

      // Toggle to Hindi
      await tester.tap(find.byKey(const Key('toggle_profile_language_button')));
      await tester.pumpAndSettle();

      // Apply suggestions
      await tester.tap(find.byKey(const Key('btn_apply_invoice_suggestions')));
      await tester.pumpAndSettle();

      // Expect no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });
  });
}
