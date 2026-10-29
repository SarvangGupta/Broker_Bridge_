import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';

import '../support/fake_commodities_repository.dart';

/// RB-SELLER-OCR-STAGING-01 Phase 3 (offline): OCR text → apply → confirm → save → reopen,
/// plus cancel and failed-save paths. Uses the app's local repository (no Supabase client,
/// no network) and a master shaped like staging after migration 0052.
class _StagingMaster extends FakeCommoditiesRepository {
  static const rj = MasterState(id: 'rj', name: 'Rajasthan', code: 'RJ');
  static const up = MasterState(id: 'up', name: 'Uttar Pradesh', code: 'UP');

  @override
  Future<List<MasterState>> getMasterStates() async => const [rj, up];

  @override
  Future<List<MasterDistrict>> getMasterDistricts(String stateId) async => switch (stateId) {
        'rj' => const [
            MasterDistrict(id: 'rj-bikaner', stateId: 'rj', name: 'Bikaner'),
            MasterDistrict(id: 'rj-jaipur', stateId: 'rj', name: 'Jaipur'),
          ],
        'up' => const [MasterDistrict(id: 'up-kaushambi', stateId: 'up', name: 'Kaushambi')],
        _ => const [],
      };
}

class _FailingRepo extends SellerProfileRepository {
  _FailingRepo({required super.storage});

  @override
  Future<SellerProfileModel> updateProfile(
    SellerProfileModel updatedProfile, {
    String operationType = 'MANUAL_EDIT',
    String? requestId,
    List<String>? confirmedFields,
    String? customSummary,
  }) async =>
      throw Exception('simulated server rejection');
}

class _Ocr extends InvoiceOcrService {
  const _Ocr() : super(nativeEngineAvailable: true);
}

const _binaOcr = '''
GSTIN No. 08BCIPJ4336H1ZK
BINA ENTERPRISES
Address: 82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019
Mob. : 8094689777
For BINA ENTERPRISES
''';

const _upOcr = '''
GSTIN : 09EBCPR5003P1Z8
मे0 सियाराम ट्रेडिंग कम्पनी
पता: मुख्य बाज़ार, भरवारी, कौशाम्बी - 212201
मो० : 9696700510
वास्ते-मे० सियाराम ट्रेडिंग कम्पनी
''';

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService()..enableMemoryFallbackForTesting();
    await storage.clearAll();
  });

  Future<void> pumpScreen(WidgetTester tester, SellerProfileRepository repo, {String? ocrText, bool edit = true}) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    const ocr = _Ocr();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SellerProfileScreen(
          key: UniqueKey(),
          profileRepository: repo,
          storageService: storage,
          ocrService: ocr,
          commoditiesRepository: _StagingMaster(),
          initialExtractedInvoiceData: ocrText == null ? null : ocr.extractFromText(ocrText),
          isInitialEdit: edit,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Expands the view-mode accordions a seller opens to read business and location details.
  Future<void> expandSections(WidgetTester tester) async {
    for (final k in ['profile_section_business', 'business_location_view_card']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.tap(find.descendant(of: find.byKey(Key(k)), matching: find.byType(InkWell)).first);
      await tester.pumpAndSettle();
    }
  }

  Future<void> applyAndOpenConfirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('btn_apply_invoice_suggestions')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save_profile_button')));
    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_review_confirmation_sheet')), findsOneWidget);
  }

  testWidgets('English invoice with PIN: save then reopen persists address + PIN-derived location', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    final before = await repo.getProfile();
    await pumpScreen(tester, repo, ocrText: _binaOcr);
    await applyAndOpenConfirm(tester);
    await tester.tap(find.byKey(const Key('confirm_and_save_button')));
    await tester.pumpAndSettle();

    final saved = await repo.getProfile();
    expect(saved.companyName, 'BINA ENTERPRISES');
    expect(saved.fullName, 'BINA ENTERPRISES');
    expect(saved.companyGst, '08BCIPJ4336H1ZK');
    expect(saved.mobile, '8094689777');
    expect(saved.email, before.email, reason: 'login email untouched');
    expect(saved.officeAddress, '82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019');
    expect(saved.businessLocation.addressLine, saved.officeAddress);
    expect(saved.businessLocation.name, 'BINA ENTERPRISES');
    expect(saved.businessLocation.pinCode, '302019');
    expect(saved.businessLocation.stateName, 'Rajasthan');
    expect(saved.businessLocation.districtId, 'rj-jaipur');
    expect(saved.businessLocation.districtName, 'Jaipur');

    // Reopen: a fresh screen instance reads the persisted values back.
    await pumpScreen(tester, repo, edit: false);
    await expandSections(tester);
    expect(find.text('82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019'), findsWidgets);
    expect(find.text('BINA ENTERPRISES'), findsWidgets);
    expect(find.text('302019'), findsWidgets);
    expect(find.textContaining('Jaipur'), findsWidgets);
    final reopened = await repo.getProfile();
    expect(reopened.toMap(), saved.toMap());
  });

  testWidgets('Hindi invoice with UP PIN: Devanagari address and Kaushambi persist through save/reopen', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    await pumpScreen(tester, repo, ocrText: _upOcr);
    await applyAndOpenConfirm(tester);
    await tester.tap(find.byKey(const Key('confirm_and_save_button')));
    await tester.pumpAndSettle();

    final saved = await repo.getProfile();
    expect(saved.companyName, 'मे० सियाराम ट्रेडिंग कम्पनी');
    expect(saved.officeAddress, 'मुख्य बाज़ार, भरवारी, कौशाम्बी - 212201');
    expect(saved.businessLocation.pinCode, '212201');
    expect(saved.businessLocation.stateName, 'Uttar Pradesh');
    expect(saved.businessLocation.districtName, 'Kaushambi');

    await pumpScreen(tester, repo, edit: false);
    await expandSections(tester);
    expect(find.text('मुख्य बाज़ार, भरवारी, कौशाम्बी - 212201'), findsWidgets);
    expect(find.text('212201'), findsWidgets);
    expect((await repo.getProfile()).officeAddress, 'मुख्य बाज़ार, भरवारी, कौशाम्बी - 212201');
  });

  testWidgets('cancelling the confirmation leaves the stored profile unchanged', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    final before = (await repo.getProfile()).toMap();
    await pumpScreen(tester, repo, ocrText: _binaOcr);
    await applyAndOpenConfirm(tester);
    await tester.tap(find.byKey(const Key('cancel_confirmation_button')));
    await tester.pumpAndSettle();
    expect((await repo.getProfile()).toMap(), before);
  });

  testWidgets('a failed save keeps the stored profile unchanged and does not report success', (tester) async {
    final repo = _FailingRepo(storage: storage);
    final before = (await repo.getProfile()).toMap();
    await pumpScreen(tester, repo, ocrText: _binaOcr);
    await applyAndOpenConfirm(tester);
    await tester.tap(find.byKey(const Key('confirm_and_save_button')));
    await tester.pumpAndSettle();
    expect((await repo.getProfile()).toMap(), before);
    expect(find.byKey(const Key('save_profile_button')), findsOneWidget, reason: 'still editing after failure');
  });
}
