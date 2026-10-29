import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';

import '../support/fake_commodities_repository.dart';

/// Mirrors the live master shape (2026-10-28): duplicate Rajasthan rows, Uttar Pradesh
/// present with no districts.
class _LiveShapeMasterRepo extends FakeCommoditiesRepository {
  static const rjSeed = MasterState(id: 'rj-seed', name: 'Rajasthan', code: 'RJ');
  static const rjLive = MasterState(id: 'rj-live', name: 'Rajasthan', code: 'RJ');
  static const up = MasterState(id: 'up', name: 'Uttar Pradesh', code: 'UP');

  @override
  Future<List<MasterState>> getMasterStates() async => const [rjSeed, rjLive, up];

  @override
  Future<List<MasterDistrict>> getMasterDistricts(String stateId) async => switch (stateId) {
        'rj-live' => const [
            MasterDistrict(id: 'd-jaipur', stateId: 'rj-live', name: 'Jaipur'),
            MasterDistrict(id: 'd-bikaner', stateId: 'rj-live', name: 'Bikaner'),
          ],
        _ => const [],
      };
}

class _TextOcr extends InvoiceOcrService {
  const _TextOcr() : super(nativeEngineAvailable: true);
}

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService()..enableMemoryFallbackForTesting();
    await storage.clearAll();
  });

  Future<void> pumpWithInvoice(WidgetTester tester, String ocrText) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    const ocr = _TextOcr();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SellerProfileScreen(
          profileRepository: SellerProfileRepository(storage: storage),
          storageService: storage,
          ocrService: ocr,
          commoditiesRepository: _LiveShapeMasterRepo(),
          initialExtractedInvoiceData: ocr.extractFromText(ocrText),
          isInitialEdit: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_apply_invoice_suggestions')));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  testWidgets('verified PIN 302019 selects Rajasthan / Jaipur from the live master', (tester) async {
    await pumpWithInvoice(tester, '''
BINA ENTERPRISES
Address: 82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019
For BINA ENTERPRISES
''');
    expect(fieldText(tester, 'edit_location_pincode_field'), '302019');
    expect(fieldText(tester, 'edit_office_address_field'), '82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019');
    expect(fieldText(tester, 'edit_location_address_field'), '82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019');
    expect(find.byKey(const Key('edit_location_name_field')), findsNothing); // name field removed (WAREHOUSE-UI-01)
    expect(find.descendant(of: find.byKey(const Key('location_state_dropdown')), matching: find.text('Rajasthan')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('location_district_dropdown')), matching: find.text('Jaipur')), findsOneWidget);
    expect(find.byKey(const Key('district_review_notice')), findsNothing);
  });

  testWidgets('UP PIN with no master district selects the state and flags the district', (tester) async {
    await pumpWithInvoice(tester, '''
SHREE RAM TRADING COMPANY
Address: Main Road, Bharwari, Kaushambi - 212201
For SHREE RAM TRADING COMPANY
''');
    expect(find.descendant(of: find.byKey(const Key('location_state_dropdown')), matching: find.text('Uttar Pradesh')), findsOneWidget);
    expect(find.byKey(const Key('district_review_notice')), findsOneWidget);
    expect(find.textContaining('Kaushambi'), findsWidgets);
  });

  testWidgets('long Hindi address wraps over multiple lines in both address fields', (tester) async {
    await pumpWithInvoice(tester, '''
मे0 सियाराम ट्रेडिंग कम्पनी
पता: ग्राम मलिकपुर महेवा, पोस्ट भरवारी, तहसील चायल, जिला कौशाम्बी, उत्तर प्रदेश
वास्ते-मे० सियाराम ट्रेडिंग कम्पनी
''');
    for (final key in ['edit_office_address_field', 'edit_location_address_field']) {
      final field = tester.widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)));
      expect(field.maxLines, isNull, reason: '$key must wrap');
      expect(field.controller!.text, contains('जिला कौशाम्बी'));
    }
  });
}
