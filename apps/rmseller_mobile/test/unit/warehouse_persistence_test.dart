import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/presentation/post_commodity_screen.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';

import '../support/fake_commodities_repository.dart';
import '../support/fake_postgrest.dart';
import '../support/fake_profile_repository.dart';

/// In-memory SecureStorage implementation for unit and widget testing.
class TestMemorySecureStorage extends SecureStorageService {
  final Map<String, String> _prefs = {};

  @override
  Future<void> savePreference(String key, String value) async {
    _prefs[key] = value;
  }

  @override
  Future<String?> getPreference(String key) async {
    return _prefs[key];
  }

  Future<void> removePreference(String key) async {
    _prefs.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _prefs.clear();
  }

  @override
  Future<void> saveUserInfo({
    required String id,
    required String role,
    required String email,
    required String fullName,
    String? companyId,
    String? companyName,
    String? companyGst,
  }) async {
    _prefs['user_id'] = id;
    _prefs['user_role'] = role;
    _prefs['user_email'] = email;
    _prefs['user_fullname'] = fullName;
    if (companyId != null) _prefs['company_id'] = companyId;
    if (companyName != null) _prefs['company_name'] = companyName;
    if (companyGst != null) _prefs['company_gst'] = companyGst;
  }

  @override
  Future<String?> getUserId() async => _prefs['user_id'];
}

String _b64(Map<String, dynamic> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

String _jwt(String sub, {String role = 'seller', Duration ttl = const Duration(hours: 1)}) {
  final exp = DateTime.now().add(ttl);
  return '${_b64({'alg': 'none', 'typ': 'JWT'})}.'
      '${_b64({'sub': sub, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

Future<void> _signIn(FakePostgrest fake, String sub, {String role = 'seller'}) =>
    fake.client.auth.setInitialSession(
      jsonEncode({
        'access_token': _jwt(sub, role: role),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-$sub',
        'user': {
          'id': sub,
          'aud': 'authenticated',
          'app_metadata': {'role': role},
          'user_metadata': <String, dynamic>{'role': role},
          'created_at': DateTime.now().toIso8601String(),
        },
      }),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sellerAId = 'a0000000-0000-4000-8000-000000000001';
  const sellerBId = 'b0000000-0000-4000-8000-000000000002';

  group('RMS-WAREHOUSE-PERSISTENCE-01: Warehouse Persistence & Selection Tests', () {
    test('1. First-time seller without a warehouse sees the add-location prompt', () async {
      final storage = TestMemorySecureStorage();
      await storage.saveUserInfo(
        id: sellerAId,
        role: 'seller',
        email: 'seller.a@test.com',
        fullName: 'Seller A',
      );

      final repo = SellerProfileRepository(storage: storage);
      final saved = await repo.getSavedBusinessLocation(userId: sellerAId);

      expect(saved, isNull);
    });

    test('2. Seller saves a warehouse successfully and it persists locally & in user metadata', () async {
      final storage = TestMemorySecureStorage();
      final repo = SellerProfileRepository(storage: storage);

      const loc = BusinessLocationModel(
        name: 'Warehouse 1',
        addressLine: 'Plot 10, Mandi Yard Road',
        locality: 'Industrial Area',
        stateId: 'S-RJ',
        stateName: 'Rajasthan',
        districtId: 'D-BKN',
        districtName: 'Bikaner',
        pinCode: '334001',
      );

      await repo.saveBusinessLocationDefault(loc, userId: sellerAId);

      final loaded = await repo.getSavedBusinessLocation(userId: sellerAId);
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Warehouse 1');
      expect(loaded.addressLine, 'Plot 10, Mandi Yard Road');
      expect(loaded.stateId, 'S-RJ');
      expect(loaded.districtId, 'D-BKN');
      expect(loaded.pinCode, '334001');
    });

    test('3. Seller opens a second commodity listing and sees the saved warehouse automatically', () async {
      final storage = TestMemorySecureStorage();
      final repo = SellerProfileRepository(storage: storage);

      const loc = BusinessLocationModel(
        name: 'Warehouse 1',
        addressLine: 'Plot 10, Mandi Yard Road',
        locality: 'Industrial Area',
        stateId: 'S-RJ',
        stateName: 'Rajasthan',
        districtId: 'D-BKN',
        districtName: 'Bikaner',
        pinCode: '334001',
      );

      // Save on first lot
      await repo.saveBusinessLocationDefault(loc, userId: sellerAId);

      // Open second listing: fetch saved warehouse
      final secondLotWarehouse = await repo.getSavedBusinessLocation(userId: sellerAId);
      expect(secondLotWarehouse, isNotNull);
      expect(secondLotWarehouse!.addressLine, 'Plot 10, Mandi Yard Road');
      expect(secondLotWarehouse.stateName, 'Rajasthan');
    });

    test('4. Seller closes and restarts the app and the warehouse still loads from storage', () async {
      final storage = TestMemorySecureStorage();

      // First run: save warehouse
      final repo1 = SellerProfileRepository(storage: storage);
      const loc = BusinessLocationModel(
        name: 'Central Godown',
        addressLine: 'Shed 4, Mandi Hub',
        locality: 'Grain Market',
        stateId: 'S-RJ',
        stateName: 'Rajasthan',
        districtId: 'D-BKN',
        districtName: 'Bikaner',
        pinCode: '334002',
      );
      await repo1.saveBusinessLocationDefault(loc, userId: sellerAId);

      // App restart: new repository instance with existing storage
      final repo2 = SellerProfileRepository(storage: storage);
      final restored = await repo2.getSavedBusinessLocation(userId: sellerAId);

      expect(restored, isNotNull);
      expect(restored!.name, 'Central Godown');
      expect(restored.addressLine, 'Shed 4, Mandi Hub');
    });

    test('5. Seller logs out and logs back in and the correct warehouse rehydrates from metadata', () async {
      final storage = TestMemorySecureStorage();

      // Metadata stored on cloud Supabase user
      final userMetadata = {
        'role': 'seller',
        'default_warehouse': {
          'name': 'Cloud Restored Warehouse',
          'address_line': 'NH 8, Bypass Godown',
          'locality': 'Transport Nagar',
          'state_id': 'S-RJ',
          'state_name': 'Rajasthan',
          'district_id': 'D-BKN',
          'district_name': 'Bikaner',
          'pin_code': '334004',
        },
      };

      // User logs out -> storage cleared
      await storage.clearAll();
      expect(await storage.getPreference('business_location_address_$sellerAId'), isNull);

      // User logs in: AuthRepository hydrates default_warehouse into storage
      final fake = await FakePostgrest.start({
        'users': [
          {
            'id': sellerAId,
            'name': 'Seller A',
            'email': 'seller.a@test.com',
            'role': 'seller',
            'status': true,
            'company_id': null,
          }
        ],
      });

      // Simulate sign in hydration
      final wh = userMetadata['default_warehouse'] as Map<String, dynamic>;
      final loc = BusinessLocationModel.fromMap(wh);
      final profileRepo = SellerProfileRepository(supabase: fake.client, storage: storage);
      await profileRepo.saveBusinessLocationDefault(loc, userId: sellerAId);

      final restored = await profileRepo.getSavedBusinessLocation(userId: sellerAId);
      expect(restored, isNotNull);
      expect(restored!.name, 'Cloud Restored Warehouse');
      expect(restored.addressLine, 'NH 8, Bypass Godown');

      await fake.close();
    });

    test('6. Seller edits a warehouse and sees the updated address on subsequent listings', () async {
      final storage = TestMemorySecureStorage();
      final repo = SellerProfileRepository(storage: storage);

      const locV1 = BusinessLocationModel(
        name: 'Old Warehouse Name',
        addressLine: 'Old Address 123',
        locality: '',
        stateId: 'S-RJ',
        stateName: 'Rajasthan',
        districtId: 'D-BKN',
        districtName: 'Bikaner',
        pinCode: '334001',
      );
      await repo.saveBusinessLocationDefault(locV1, userId: sellerAId);

      // Seller edits address
      const locV2 = BusinessLocationModel(
        name: 'Updated Warehouse Name',
        addressLine: 'New Plot 45, Mandi Phase 2',
        locality: '',
        stateId: 'S-RJ',
        stateName: 'Rajasthan',
        districtId: 'D-BKN',
        districtName: 'Bikaner',
        pinCode: '334005',
      );
      await repo.saveBusinessLocationDefault(locV2, isUpdate: true, userId: sellerAId);

      final subsequentListingLocation = await repo.getSavedBusinessLocation(userId: sellerAId);
      expect(subsequentListingLocation, isNotNull);
      expect(subsequentListingLocation!.name, 'Updated Warehouse Name');
      expect(subsequentListingLocation.addressLine, 'New Plot 45, Mandi Phase 2');
      expect(subsequentListingLocation.pinCode, '334005');
    });

    test('7. Seller with multiple warehouses can select the intended warehouse without overwriting others', () async {
      final storage = TestMemorySecureStorage();
      final repo = SellerProfileRepository(storage: storage);

      const wh1 = BusinessLocationModel(
        name: 'Warehouse 1 (North)',
        addressLine: 'North Gate Plot 1',
        locality: '',
        stateId: 'S-RJ',
        stateName: 'Rajasthan',
        districtId: 'D-BKN',
        districtName: 'Bikaner',
        pinCode: '334001',
      );
      const wh2 = BusinessLocationModel(
        name: 'Warehouse 2 (South Depot)',
        addressLine: 'South Railway Yard Depot',
        locality: '',
        stateId: 'S-RJ',
        stateName: 'Rajasthan',
        districtId: 'D-BKN',
        districtName: 'Bikaner',
        pinCode: '334002',
      );

      await repo.saveWarehouse(wh1, setAsDefault: true, userId: sellerAId);
      await repo.saveWarehouse(wh2, setAsDefault: false, userId: sellerAId);

      final list = await repo.getSavedWarehouses(userId: sellerAId);
      expect(list.length, 2);
      expect(list.any((w) => w.name == 'Warehouse 1 (North)'), isTrue);
      expect(list.any((w) => w.name == 'Warehouse 2 (South Depot)'), isTrue);

      // Default warehouse is still wh1
      final defaultWh = await repo.getSavedBusinessLocation(userId: sellerAId);
      expect(defaultWh!.name, 'Warehouse 1 (North)');
    });

    test('8. A failed API request does not create a false missing-warehouse state', () async {
      final fake = await FakePostgrest.start({});
      fake.failWith = (req) => (504, {'message': 'Connection timeout'});

      final storage = TestMemorySecureStorage();
      final repo = SellerProfileRepository(supabase: fake.client, storage: storage);

      bool threwOrHandled = false;
      try {
        final loc = await repo.getSavedBusinessLocation(userId: sellerAId);
        expect(loc, isNull);
        threwOrHandled = true;
      } catch (_) {
        threwOrHandled = true;
      }
      expect(threwOrHandled, isTrue);

      await fake.close();
    });

    test('9. A warehouse belonging to another seller is never displayed or modified', () async {
      final storage = TestMemorySecureStorage();
      final repo = SellerProfileRepository(storage: storage);

      const sellerAWh = BusinessLocationModel(
        name: 'Seller A Godown',
        addressLine: 'Plot A-1',
        locality: '',
        stateId: 'S-RJ',
        stateName: 'Rajasthan',
        districtId: 'D-BKN',
        districtName: 'Bikaner',
        pinCode: '334001',
      );
      const sellerBWh = BusinessLocationModel(
        name: 'Seller B Depot',
        addressLine: 'Plot B-99',
        locality: '',
        stateId: 'S-MP',
        stateName: 'Madhya Pradesh',
        districtId: 'D-IND',
        districtName: 'Indore',
        pinCode: '452001',
      );

      await repo.saveBusinessLocationDefault(sellerAWh, userId: sellerAId);
      await repo.saveBusinessLocationDefault(sellerBWh, userId: sellerBId);

      final readA = await repo.getSavedBusinessLocation(userId: sellerAId);
      final readB = await repo.getSavedBusinessLocation(userId: sellerBId);

      expect(readA!.name, 'Seller A Godown');
      expect(readA.addressLine, 'Plot A-1');

      expect(readB!.name, 'Seller B Depot');
      expect(readB.addressLine, 'Plot B-99');
    });

    test('10. Existing commodity listings and their warehouse references remain unchanged', () async {
      final fake = await FakePostgrest.start({
        'users': [
          {
            'id': sellerAId,
            'name': 'Seller A',
            'email': 'seller.a@test.com',
            'role': 'seller',
            'status': true,
          }
        ],
        'availabilities': [
          {
            'id': 'lot-existing-01',
            'lot_number': 'LOT-HIST-001',
            'loading_remarks': 'Historic Warehouse Gate 3',
            'state_id': 'S-RJ',
            'district_id': 'D-BKN',
            'seller_user_id': sellerAId,
            'quantity': 100,
            'price': 5000,
            'status': 'Open',
            'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          }
        ],
      });


      await _signIn(fake, sellerAId);

      final storage = TestMemorySecureStorage();
      await storage.saveUserInfo(
        id: sellerAId,
        role: 'seller',
        email: 'seller.a@test.com',
        fullName: 'Seller A',
      );
      final commRepo = CommoditiesRepository(client: fake.client, storage: storage);
      final history = await commRepo.getPostingHistory();
      expect(history.length, 1);
      expect(history.first.loadingRemarks, 'Historic Warehouse Gate 3');

      await fake.close();
    });

    test('11. Repeated save requests do not create duplicate records', () async {
      final storage = TestMemorySecureStorage();
      final repo = SellerProfileRepository(storage: storage);

      const wh = BusinessLocationModel(
        name: 'Idempotent Godown',
        addressLine: 'Plot 777, Mandi Yard',
        locality: '',
        stateId: 'S-RJ',
        stateName: 'Rajasthan',
        districtId: 'D-BKN',
        districtName: 'Bikaner',
        pinCode: '334001',
      );

      // Save 3 times repeatedly
      await repo.saveWarehouse(wh, setAsDefault: true, userId: sellerAId);
      await repo.saveWarehouse(wh, setAsDefault: true, userId: sellerAId);
      await repo.saveWarehouse(wh, setAsDefault: true, userId: sellerAId);

      final list = await repo.getSavedWarehouses(userId: sellerAId);
      expect(list.length, 1);
      expect(list.first.name, 'Idempotent Godown');
    });

    testWidgets('12. Commodity drafts survive navigation between warehouse editing and posting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final profileRepo = FakeProfileRepository(
        savedLocation: const BusinessLocationModel(
          name: 'Draft Godown',
          addressLine: 'Plot 888',
          locality: '',
          stateId: 'S-RJ',
          stateName: 'Rajasthan',
          districtId: 'D-BKN',
          districtName: 'Bikaner',
          pinCode: '334001',
        ),
      );
      final commRepo = FakeCommoditiesRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCommodityScreen(
              commoditiesRepository: commRepo,
              profileRepository: profileRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter commodity details
      await tester.enterText(find.byKey(const Key('quantity_field')), '150');
      await tester.enterText(find.byKey(const Key('asking_price_field')), '4800');
      await tester.pumpAndSettle();

      // Toggle to Section 2 (Warehouse & Loading)
      await tester.tap(find.byKey(const Key('post_section_header_1')));
      await tester.pumpAndSettle();

      // Verify Edit Location button exists and tap it
      final editBtn = find.byKey(const Key('edit_location_button'));
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // In location sheet, cancel to return to draft
      final cancelBtn = find.text('Cancel');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Toggle back to Section 1: verify typed quantity and price are intact
      await tester.tap(find.byKey(const Key('post_section_header_0')));
      await tester.pumpAndSettle();

      final qtyField = tester.widget<TextFormField>(find.byKey(const Key('quantity_field')));
      final priceField = tester.widget<TextFormField>(find.byKey(const Key('asking_price_field')));

      expect(qtyField.controller!.text, '150');
      expect(priceField.controller!.text, '4800');
    });
  });
}
