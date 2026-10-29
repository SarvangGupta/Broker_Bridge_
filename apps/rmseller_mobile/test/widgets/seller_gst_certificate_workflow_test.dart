import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_document_service.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';
import 'package:rmseller_mobile/features/profile/presentation/profile_strings.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';

import '../support/fake_commodities_repository.dart';
import '../unit/gst_certificate_amended_photo_test.dart' show realAmendedPhotoOcr;
import '../unit/gst_certificate_extraction_test.dart' show realGstOcrForTests;

/// RB-SELLER-GST-CERTIFICATE-PROFILE-01 — widget workflow. OCR text is the verbatim on-device
/// ML Kit output for the supplied REG-06; the app's real parser and mapping run on it.
class _Docs extends InvoiceDocumentService {
  SelectedInvoiceDocument? next = const SelectedInvoiceDocument(
    localPath: '/nonexistent/gst_reg06.png',
    fileName: 'gst_reg06.png',
    fileSizeBytes: 167428,
  );
  @override
  Future<SelectedInvoiceDocument?> pickFromGallery() async => next;
  @override
  Future<SelectedInvoiceDocument?> pickDocumentFile() async => next;
  @override
  Future<SelectedInvoiceDocument?> captureFromCamera() async => next;
}

class _Ocr extends InvoiceOcrService {
  final bool fail;
  final String rawOcr;
  const _Ocr({this.fail = false, this.rawOcr = realGstOcrForTests}) : super(nativeEngineAvailable: true);
  @override
  Future<GstCertificateExtractionResult> extractGstCertificateFromFile(File file) async => fail
      ? const GstCertificateExtractionResult.failure('No readable text was found on the certificate.')
      : GstCertificateExtractionResult.success(extractGstCertificateFromText(rawOcr));
}

class _Master extends FakeCommoditiesRepository {
  @override
  Future<List<MasterState>> getMasterStates() async => const [MasterState(id: 'rj', name: 'Rajasthan', code: 'RJ')];
  @override
  Future<List<MasterDistrict>> getMasterDistricts(String stateId) async => stateId == 'rj'
      ? const [
          MasterDistrict(id: 'rj-bikaner', stateId: 'rj', name: 'Bikaner'),
          MasterDistrict(id: 'rj-jaipur', stateId: 'rj', name: 'Jaipur'),
        ]
      : const [];
}

class _FailingRepo extends SellerProfileRepository {
  _FailingRepo({required super.storage});
  @override
  Future<SellerProfileModel> updateProfile(SellerProfileModel updatedProfile,
          {String operationType = 'MANUAL_EDIT', String? requestId, List<String>? confirmedFields, String? customSummary}) async =>
      throw Exception('simulated server rejection');
}

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService()..enableMemoryFallbackForTesting();
    await storage.clearAll();
  });

  Future<void> pump(WidgetTester tester, SellerProfileRepository repo,
      {bool fail = false, bool edit = true, String rawOcr = realGstOcrForTests}) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SellerProfileScreen(
          key: UniqueKey(),
          profileRepository: repo,
          storageService: storage,
          ocrService: _Ocr(fail: fail, rawOcr: rawOcr),
          documentService: _Docs(),
          commoditiesRepository: _Master(),
          isInitialEdit: edit,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  String field(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  Future<void> uploadAndApply(WidgetTester tester, {bool godown = false}) async {
    await tapKey(tester, 'chk_has_gst_certificate');
    await tapKey(tester, 'btn_gst_cert_gallery');
    if (godown) await tapKey(tester, 'chk_gst_address_is_godown');
    await tapKey(tester, 'btn_apply_gst_certificate');
  }

  testWidgets('1. checkbox shows/hides the upload section; unchecking keeps form values', (tester) async {
    await pump(tester, SellerProfileRepository(storage: storage));
    expect(find.byKey(const Key('btn_gst_cert_gallery')), findsNothing);
    await tapKey(tester, 'chk_has_gst_certificate');
    expect(find.byKey(const Key('btn_gst_cert_gallery')), findsOneWidget);
    await tapKey(tester, 'btn_gst_cert_gallery');
    await tapKey(tester, 'btn_apply_gst_certificate');
    await tapKey(tester, 'chk_has_gst_certificate');
    expect(find.byKey(const Key('btn_gst_cert_gallery')), findsNothing);
    expect(field(tester, 'edit_gstin_field'), '08AWIPG6115A1Z0');
    // Invoice scanning remains available while the certificate option is unchecked.
    expect(find.byKey(const Key('btn_scan_invoice_gallery')), findsOneWidget);
  });

  testWidgets('3–10. upload, preview, extracted values, mapping into editable fields', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    await pump(tester, repo);
    await tapKey(tester, 'chk_has_gst_certificate');
    await tapKey(tester, 'btn_gst_cert_gallery');

    expect(find.byKey(const Key('gst_certificate_preview')), findsOneWidget);
    expect(find.text('gst_reg06.png'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('gst_value_legal_name'))).data, 'Raghuveer Prasad Goyal');
    expect(tester.widget<Text>(find.byKey(const Key('gst_value_issue_date'))).data, '23/07/2020');
    expect(tester.widget<Text>(find.byKey(const Key('gst_value_jurisdiction'))).data, 'Circle-A, Jaipur - Ward-2');
    // Review notes (GSTIN O→0 repair, inferred issue date) are shown before applying.
    expect(find.byKey(const Key('gst_certificate_notice')), findsOneWidget);

    await tapKey(tester, 'btn_apply_gst_certificate');
    expect(field(tester, 'edit_full_name_field'), 'Raghuveer Prasad Goyal');
    expect(field(tester, 'edit_company_name_field'), 'Piyush General Store');
    expect(field(tester, 'edit_gstin_field'), '08AWIPG6115A1Z0');
    expect(field(tester, 'edit_office_address_field'), 'B-391, Shanti Nagar, Gurjer Ki Thadi, Jaipur, Rajasthan, 302019');
    // Shop/godown address untouched without explicit confirmation.
    expect(field(tester, 'edit_location_address_field'), isNot(contains('Shanti Nagar')));
    // Hidden values are not editable profile fields.
    expect(find.widgetWithText(TextFormField, 'Circle-A, Jaipur - Ward-2'), findsNothing);
    expect(find.widgetWithText(TextFormField, '23/07/2020'), findsNothing);
    // Nothing saved yet.
    expect((await repo.getProfile()).companyGst, isNot('08AWIPG6115A1Z0'));
  });

  testWidgets('11. godown confirmation fills street, PIN and PIN-derived Rajasthan / Jaipur', (tester) async {
    await pump(tester, SellerProfileRepository(storage: storage));
    await uploadAndApply(tester, godown: true);
    expect(field(tester, 'edit_location_address_field'), 'B-391, Shanti Nagar, Gurjer Ki Thadi, Jaipur, Rajasthan, 302019');
    expect(field(tester, 'edit_location_pincode_field'), '302019');
    expect(find.descendant(of: find.byKey(const Key('location_district_dropdown')), matching: find.text('Jaipur')), findsOneWidget);
  });

  testWidgets('12 + 14. seller correction is saved; hidden fields persist and stay hidden after reopen', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    final before = await repo.getProfile();
    await pump(tester, repo);
    await uploadAndApply(tester);
    await tester.enterText(find.byKey(const Key('edit_company_name_field')), 'Piyush General Store (Jaipur)');
    await tester.pump();
    await tapKey(tester, 'save_profile_button');
    expect(find.byKey(const Key('profile_review_confirmation_sheet')), findsOneWidget);
    await tapKey(tester, 'confirm_and_save_button');

    final saved = await repo.getProfile();
    expect(saved.fullName, 'Raghuveer Prasad Goyal');
    expect(saved.companyName, 'Piyush General Store (Jaipur)');
    expect(saved.companyGst, '08AWIPG6115A1Z0');
    expect(saved.officeAddress, 'B-391, Shanti Nagar, Gurjer Ki Thadi, Jaipur, Rajasthan, 302019');
    expect(saved.jurisdictionalOffice, 'Circle-A, Jaipur - Ward-2');
    expect(saved.gstCertificateIssueDate, '23/07/2020');
    expect(saved.email, before.email);
    expect(saved.mobile, before.mobile);

    // Reopen in view mode with every section expanded: hidden fields are not displayed.
    await pump(tester, repo, edit: false);
    for (final k in ['profile_section_business', 'profile_section_personal', 'business_location_view_card']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.tap(find.descendant(of: find.byKey(Key(k)), matching: find.byType(InkWell)).first);
      await tester.pumpAndSettle();
    }
    expect(find.text('Piyush General Store (Jaipur)'), findsWidgets);
    expect(find.textContaining('Circle-A'), findsNothing);
    expect(find.textContaining('23/07/2020'), findsNothing);
    expect((await repo.getProfile()).toMap(), saved.toMap());
  });

  testWidgets('13. cancelling the confirmation or the edit saves nothing', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    final before = (await repo.getProfile()).toMap();
    await pump(tester, repo);
    await uploadAndApply(tester);
    await tapKey(tester, 'save_profile_button');
    await tapKey(tester, 'cancel_confirmation_button');
    expect((await repo.getProfile()).toMap(), before);
  });

  testWidgets('15a. extraction failure shows an error and leaves manual editing intact', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    await pump(tester, repo, fail: true);
    final gstBefore = field(tester, 'edit_gstin_field');
    await tapKey(tester, 'chk_has_gst_certificate');
    await tapKey(tester, 'btn_gst_cert_gallery');
    expect(find.byKey(const Key('gst_certificate_notice')), findsOneWidget);
    expect(find.byKey(const Key('btn_apply_gst_certificate')), findsNothing);
    expect(field(tester, 'edit_gstin_field'), gstBefore);
    await tester.enterText(find.byKey(const Key('edit_gstin_field')), '08AWIPG6115A1Z0');
    expect(field(tester, 'edit_gstin_field'), '08AWIPG6115A1Z0');
  });

  testWidgets('15b. server failure keeps the draft for retry and stores nothing', (tester) async {
    final repo = _FailingRepo(storage: storage);
    final before = (await repo.getProfile()).toMap();
    await pump(tester, repo);
    await uploadAndApply(tester);
    await tapKey(tester, 'save_profile_button');
    await tapKey(tester, 'confirm_and_save_button');
    expect((await repo.getProfile()).toMap(), before);
    expect(find.byKey(const Key('save_profile_button')), findsOneWidget);
    expect(field(tester, 'edit_gstin_field'), '08AWIPG6115A1Z0');
  });

  testWidgets('remove clears the unsaved certificate draft only', (tester) async {
    await pump(tester, SellerProfileRepository(storage: storage));
    await tapKey(tester, 'chk_has_gst_certificate');
    await tapKey(tester, 'btn_gst_cert_gallery');
    await tapKey(tester, 'btn_gst_cert_remove');
    expect(find.byKey(const Key('gst_certificate_preview')), findsNothing);
    expect(find.byKey(const Key('btn_apply_gst_certificate')), findsNothing);
  });

  testWidgets('PARSER-FIX-01 #12: amended photo certificate shows values, not "Not found on certificate"', (tester) async {
    await pump(tester, SellerProfileRepository(storage: storage), rawOcr: realAmendedPhotoOcr);
    await tapKey(tester, 'chk_has_gst_certificate');
    await tapKey(tester, 'btn_gst_cert_gallery');
    String shown(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(shown('gst_value_legal_name'), 'HARI SHANKAR KHANDELWAL');
    expect(shown('gst_value_trade_name'), 'Shiv Shanker Paslhu Aahar Udyog');
    expect(shown('gst_value_gstin'), '08ADRPK6597J1ZL');
    expect(shown('gst_value_address'), 'A-6, KABAR MARG, BANI PARK, Jaipur, Rajasthan, 302006');
    expect(shown('gst_value_issue_date'), '16/06/2022');
    expect(shown('gst_value_jurisdiction'), 'Circle-H, Jaipur I, AC / CTO Ward');
    expect(find.text(const ProfileStrings().notFoundOnCertificate), findsNothing);

    // The OCR misread ("Paslhu") can be corrected by the seller before saving.
    await tapKey(tester, 'btn_apply_gst_certificate');
    await tester.enterText(find.byKey(const Key('edit_company_name_field')), 'Shiv Shanker Pashu Aahar Udyog');
    await tester.pump();
    expect(field(tester, 'edit_company_name_field'), 'Shiv Shanker Pashu Aahar Udyog');
    expect(field(tester, 'edit_full_name_field'), 'HARI SHANKAR KHANDELWAL');
  });

  test('16. Hindi labels exist for the new section', () {
    const hi = ProfileStrings(isHindi: true);
    expect(hi.hasGstCertificate, contains('GST पंजीकरण प्रमाणपत्र'));
    expect(hi.uploadGstCertificate, contains('अपलोड'));
    expect(const ProfileStrings().hasGstCertificate, 'I have a GST Registration Certificate');
  });
}
