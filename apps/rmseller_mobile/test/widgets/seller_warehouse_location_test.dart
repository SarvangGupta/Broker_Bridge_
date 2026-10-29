import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/profile/data/device_location_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';
import 'package:rmseller_mobile/features/profile/presentation/widgets/warehouse_map.dart';

import '../support/fake_commodities_repository.dart';

/// RB-SELLER-WAREHOUSE-UI-01 — Warehouse address + GPS / Set on Map.
class _FakeDeviceLocation extends DeviceLocationService {
  DeviceLocationResult next;
  _FakeDeviceLocation(this.next);
  @override
  Future<DeviceLocationResult> getCurrentPosition() async => next;
}

class _FailingRepo extends SellerProfileRepository {
  _FailingRepo({required super.storage});
  @override
  Future<SellerProfileModel> updateProfile(SellerProfileModel updatedProfile,
          {String operationType = 'MANUAL_EDIT', String? requestId, List<String>? confirmedFields, String? customSummary}) async =>
      throw Exception('simulated server rejection');
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

void main() {
  late SecureStorageService storage;

  setUp(() async {
    WarehouseMapTiles.enabled = false; // no network tiles in tests
    storage = SecureStorageService()..enableMemoryFallbackForTesting();
    await storage.clearAll();
  });

  Future<void> pump(WidgetTester tester, SellerProfileRepository repo,
      {bool edit = true, bool? hindi, DeviceLocationService? device}) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SellerProfileScreen(
          key: UniqueKey(),
          profileRepository: repo,
          storageService: storage,
          commoditiesRepository: _Master(),
          deviceLocationService: device ?? _FakeDeviceLocation(const DeviceLocationResult(DeviceLocationStatus.unavailable)),
          isInitialEdit: edit,
          isHindi: hindi,
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

  /// flutter_map fires onTap only after its double-tap window, so pump past it.
  Future<void> tapMap(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('warehouse_map_picker')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  String gpsShown(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('warehouse_gps_value'))).data!;
  String field(WidgetTester tester, String key) => tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  testWidgets('renamed Warehouse section (EN/HI); no presets, name or locality fields', (tester) async {
    await pump(tester, SellerProfileRepository(storage: storage));
    expect(tester.widget<Text>(find.byKey(const Key('warehouse_section_title'))).data, 'Warehouse');
    expect(find.text('Shop & Godown'), findsNothing);
    expect(find.byKey(const Key('btn_location_presets')), findsNothing);
    expect(find.byKey(const Key('btn_use_current_location')), findsNothing);
    expect(find.byKey(const Key('edit_location_name_field')), findsNothing);
    expect(find.byKey(const Key('edit_location_locality_field')), findsNothing);
    final addr = tester.widget<TextField>(find.descendant(of: find.byKey(const Key('edit_location_address_field')), matching: find.byType(TextField)));
    expect(addr.maxLines, isNull, reason: 'address must wrap');
    expect(find.text('Warehouse Address'), findsOneWidget);

    await pump(tester, SellerProfileRepository(storage: storage), hindi: true);
    expect(tester.widget<Text>(find.byKey(const Key('warehouse_section_title'))).data, 'गोदाम');
    expect(find.text('गोदाम का पता'), findsOneWidget);
    expect(find.text('मैप पर सेट करें'), findsOneWidget);
  });

  testWidgets('GPS starts unset (no fake coordinates); address works without GPS', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    await pump(tester, repo);
    expect(gpsShown(tester), 'Not set yet');
    expect(find.byKey(const Key('warehouse_map_preview')), findsNothing);
    expect(find.byKey(const Key('edit_open_in_google_maps')), findsNothing);
  });

  testWidgets('Set on Map → tap to place → confirm → coordinates, preview and Google Maps link', (tester) async {
    await pump(tester, SellerProfileRepository(storage: storage));
    await tapKey(tester, 'btn_set_on_map');
    expect(find.byKey(const Key('warehouse_map_picker')), findsOneWidget);
    // Confirm is disabled until a pin is placed.
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('btn_picker_confirm'))).onPressed, isNull);
    await tapMap(tester);
    final picked = tester.widget<Text>(find.byKey(const Key('warehouse_picker_coordinates'))).data!;
    expect(picked, matches(RegExp(r'^-?\d+\.\d{6}, -?\d+\.\d{6}$')));
    await tapKey(tester, 'btn_picker_confirm');

    expect(gpsShown(tester), picked);
    expect(find.byKey(const Key('warehouse_map_preview')), findsOneWidget);
    expect(find.byKey(const Key('edit_open_in_google_maps')), findsOneWidget);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await pump(tester, SellerProfileRepository(storage: storage));
    await tapKey(tester, 'btn_set_on_map');
    await tapMap(tester);
    await tapKey(tester, 'btn_picker_cancel');
    expect(gpsShown(tester), 'Not set yet');
  });

  testWidgets('use current location: real fix fills pin; PIN/State/District/address untouched', (tester) async {
    final device = _FakeDeviceLocation(const DeviceLocationResult(DeviceLocationStatus.ok, latitude: 26.912434, longitude: 75.787271));
    await pump(tester, SellerProfileRepository(storage: storage), device: device);
    await tester.enterText(find.byKey(const Key('edit_location_address_field')), 'B-391, Shanti Nagar, Jaipur');
    final pinBefore = field(tester, 'edit_location_pincode_field');
    await tapKey(tester, 'btn_set_on_map');
    await tapKey(tester, 'btn_picker_use_current_location');
    expect(tester.widget<Text>(find.byKey(const Key('warehouse_picker_coordinates'))).data, '26.912434, 75.787271');
    await tapKey(tester, 'btn_picker_confirm');
    expect(gpsShown(tester), '26.912434, 75.787271');
    expect(field(tester, 'edit_location_pincode_field'), pinBefore, reason: 'GPS never rewrites PIN');
    expect(field(tester, 'edit_location_address_field'), 'B-391, Shanti Nagar, Jaipur', reason: 'GPS never rewrites address');
  });

  for (final c in {
    DeviceLocationStatus.permissionDenied: 'Location permission was not given',
    DeviceLocationStatus.permissionDeniedForever: 'Location permission is blocked',
    DeviceLocationStatus.serviceDisabled: 'Location is turned off',
    DeviceLocationStatus.timeout: 'took too long',
    DeviceLocationStatus.unavailable: 'could not be found right now',
  }.entries) {
    testWidgets('current location ${c.key.name}: message shown, no coordinates invented', (tester) async {
      await pump(tester, SellerProfileRepository(storage: storage), device: _FakeDeviceLocation(DeviceLocationResult(c.key)));
      await tapKey(tester, 'btn_set_on_map');
      await tapKey(tester, 'btn_picker_use_current_location');
      expect(tester.widget<Text>(find.byKey(const Key('warehouse_picker_notice'))).data, contains(c.value));
      expect(tester.widget<Text>(find.byKey(const Key('warehouse_picker_coordinates'))).data, 'Tap the map to place the pin');
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('btn_picker_confirm'))).onPressed, isNull);
    });
  }

  testWidgets('save → reopen persists address + confirmed GPS; adjust reopens at saved pin; old name kept', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    final before = await repo.getProfile();
    final device = _FakeDeviceLocation(const DeviceLocationResult(DeviceLocationStatus.ok, latitude: 26.912434, longitude: 75.787271));
    await pump(tester, repo, device: device);
    await tester.enterText(find.byKey(const Key('edit_company_name_field')), 'Test Warehouse Traders');
    await tester.enterText(find.byKey(const Key('edit_location_address_field')),
        'Godown 7, Road No. 9,\nVishwakarma Industrial Area, Jaipur, Rajasthan 302013');
    await tapKey(tester, 'btn_set_on_map');
    await tapKey(tester, 'btn_picker_use_current_location');
    await tapKey(tester, 'btn_picker_confirm');
    await tapKey(tester, 'save_profile_button');
    if (find.byKey(const Key('confirm_and_save_button')).evaluate().isEmpty) {
      final errs = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((d) =>
          RegExp('required|valid|select|चुनें', caseSensitive: false).hasMatch(d));
      fail('save blocked by validation: ${errs.toList()}');
    }
    await tapKey(tester, 'confirm_and_save_button');

    final saved = await repo.getProfile();
    expect(saved.businessLocation.addressLine, 'Godown 7, Road No. 9,\nVishwakarma Industrial Area, Jaipur, Rajasthan 302013');
    expect(saved.businessLocation.latitude, closeTo(26.912434, 1e-6));
    expect(saved.businessLocation.longitude, closeTo(75.787271, 1e-6));
    expect(saved.businessLocation.isGpsDetected, isTrue);
    expect(saved.businessLocation.name, before.businessLocation.name, reason: 'hidden location name preserved');
    expect(saved.businessLocation.pinCode, before.businessLocation.pinCode);

    // Reopen view mode: address, coordinates, preview and Google Maps link shown.
    await pump(tester, repo, edit: false, device: device);
    await tester.ensureVisible(find.byKey(const Key('business_location_view_card')));
    await tester.tap(find.descendant(of: find.byKey(const Key('business_location_view_card')), matching: find.byType(InkWell)).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Vishwakarma Industrial Area'), findsOneWidget);
    expect(find.text('26.912434, 75.787271'), findsOneWidget);
    expect(find.byKey(const Key('view_open_in_google_maps')), findsOneWidget);

    // Reopen edit: picker opens at the saved pin; adjusting moves it.
    await pump(tester, repo, device: device);
    expect(gpsShown(tester), '26.912434, 75.787271');
    await tapKey(tester, 'btn_set_on_map');
    expect(tester.widget<Text>(find.byKey(const Key('warehouse_picker_coordinates'))).data, '26.912434, 75.787271');
  });

  testWidgets('legacy placeholder coordinates are kept in data but not shown as a confirmed pin', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    final p = await repo.getProfile();
    await repo.updateProfile(p.copyWith(
        businessLocation: p.businessLocation.copyWith(latitude: 28.0229, longitude: 73.3119, isGpsDetected: true)));
    await pump(tester, repo);
    expect(gpsShown(tester), 'Not set yet');
    final stored = await repo.getProfile();
    expect(stored.businessLocation.latitude, 28.0229);
  });

  testWidgets('6. manual pin works after GPS permission is refused; retry and Open Settings offered', (tester) async {
    final device = _FakeDeviceLocation(const DeviceLocationResult(DeviceLocationStatus.permissionDeniedForever));
    await pump(tester, SellerProfileRepository(storage: storage), device: device);
    await tapKey(tester, 'btn_set_on_map');
    await tapKey(tester, 'btn_picker_use_current_location');
    expect(find.byKey(const Key('btn_picker_open_settings')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tapMap(tester);
    final picked = tester.widget<Text>(find.byKey(const Key('warehouse_picker_coordinates'))).data!;
    expect(find.byKey(const Key('warehouse_picker_phone_notice')), findsNothing, reason: 'manual pin is not the phone location');
    await tapKey(tester, 'btn_picker_confirm');
    expect(gpsShown(tester), picked);
  });

  testWidgets('live fix: accuracy + "phone location, confirm only at the warehouse" shown; moving the pin clears it', (tester) async {
    final device = _FakeDeviceLocation(
        const DeviceLocationResult(DeviceLocationStatus.ok, latitude: 26.912434, longitude: 75.787271, accuracyMeters: 8.4));
    await pump(tester, SellerProfileRepository(storage: storage), device: device);
    await tapKey(tester, 'btn_set_on_map');
    await tapKey(tester, 'btn_picker_use_current_location');
    expect(tester.widget<Text>(find.byKey(const Key('warehouse_picker_accuracy'))).data, 'Accuracy ±8 m');
    expect(find.byKey(const Key('warehouse_picker_phone_notice')), findsOneWidget);
    // Draft is not touched until Confirm.
    expect(find.byKey(const Key('warehouse_map_picker')), findsOneWidget);
    await tapMap(tester);
    expect(find.byKey(const Key('warehouse_picker_phone_notice')), findsNothing);
  });

  testWidgets('8. cancel keeps previously saved coordinates', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    final p = await repo.getProfile();
    await repo.updateProfile(p.copyWith(
        businessLocation: p.businessLocation.copyWith(latitude: 26.912434, longitude: 75.787271, isGpsDetected: true)));
    await pump(tester, repo);
    expect(gpsShown(tester), '26.912434, 75.787271');
    await tapKey(tester, 'btn_set_on_map');
    await tapMap(tester);
    await tapKey(tester, 'btn_picker_cancel');
    expect(gpsShown(tester), '26.912434, 75.787271');
  });

  testWidgets('10. save failure keeps the confirmed GPS in the draft for retry', (tester) async {
    final repo = _FailingRepo(storage: storage);
    final device = _FakeDeviceLocation(const DeviceLocationResult(DeviceLocationStatus.ok, latitude: 26.912434, longitude: 75.787271));
    await pump(tester, repo, device: device);
    await tester.enterText(find.byKey(const Key('edit_company_name_field')), 'Test Warehouse Traders');
    await tapKey(tester, 'btn_set_on_map');
    await tapKey(tester, 'btn_picker_use_current_location');
    await tapKey(tester, 'btn_picker_confirm');
    await tapKey(tester, 'save_profile_button');
    await tapKey(tester, 'confirm_and_save_button');
    expect(find.byKey(const Key('save_profile_button')), findsOneWidget, reason: 'still editing');
    expect(gpsShown(tester), '26.912434, 75.787271');
    expect((await repo.getProfile()).businessLocation.isGpsDetected, isFalse);
  });

  testWidgets('Clear GPS changes only the draft until saved', (tester) async {
    final repo = SellerProfileRepository(storage: storage);
    final p = await repo.getProfile();
    await repo.updateProfile(p.copyWith(
        businessLocation: p.businessLocation.copyWith(latitude: 26.912434, longitude: 75.787271, isGpsDetected: true)));
    await pump(tester, repo);
    await tapKey(tester, 'btn_clear_gps');
    expect(gpsShown(tester), 'Not set yet');
    expect((await repo.getProfile()).businessLocation.latitude, 26.912434, reason: 'not saved yet');
  });

  testWidgets('15. Hindi picker messages', (tester) async {
    await pump(tester, SellerProfileRepository(storage: storage), hindi: true,
        device: _FakeDeviceLocation(const DeviceLocationResult(DeviceLocationStatus.timeout)));
    await tapKey(tester, 'btn_set_on_map');
    expect(find.text('पिन लगाने के लिए मैप पर टैप करें'), findsOneWidget);
    await tapKey(tester, 'btn_picker_use_current_location');
    expect(tester.widget<Text>(find.byKey(const Key('warehouse_picker_notice'))).data, contains('बहुत समय लगा'));
    expect(find.text('फिर कोशिश करें'), findsOneWidget);
  });

  test('Google Maps link points at the confirmed coordinates', () {
    expect(googleMapsUri(26.912434, 75.787271).toString(),
        'https://www.google.com/maps/search/?api=1&query=26.912434,75.787271');
  });
}
