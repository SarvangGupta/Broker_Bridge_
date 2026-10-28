import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/commodities/presentation/commodity_picker_sheet.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_commodity_expertise.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';

class MockCommoditiesRepository extends CommoditiesRepository {
  final List<MasterCommodity> mockCommodities;

  MockCommoditiesRepository({required this.mockCommodities});

  @override
  Future<List<MasterCommodity>> getMasterCommodities() async {
    return mockCommodities;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storage;
  late SellerProfileRepository profileRepo;
  late MockCommoditiesRepository commoditiesRepo;

  final sampleMasterCommodities = [
    const MasterCommodity(
      id: 'comm-wheat-01',
      name: 'Wheat Sharbati',
      code: 'WHT-01',
      categoryName: 'Grains',
    ),
    const MasterCommodity(
      id: 'comm-mustard-01',
      name: 'Mustard Seed Bold',
      code: 'MST-01',
      categoryName: 'Oilseeds',
    ),
    const MasterCommodity(
      id: 'comm-chana-01',
      name: 'Chana Desi',
      code: 'CHN-01',
      categoryName: 'Pulses',
    ),
    const MasterCommodity(
      id: 'comm-barley-01',
      name: 'Barley Feed Grade',
      code: 'BRL-01',
      categoryName: 'Grains',
    ),
  ];

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
    profileRepo = SellerProfileRepository(storage: storage);
    commoditiesRepo = MockCommoditiesRepository(
      mockCommodities: sampleMasterCommodities,
    );
  });

  Widget buildProfileWidget({bool isInitialEdit = false}) {
    return ProviderScope(
      child: MaterialApp(
        home: SellerProfileScreen(
          profileRepository: profileRepo,
          storageService: storage,
          commoditiesRepository: commoditiesRepo,
          isInitialEdit: isInitialEdit,
        ),
      ),
    );
  }

  group('RB-SELLER-PROFILE-INVOICE-01 ADDENDUM: Commodity Expertise UI Tests', () {
    testWidgets('1. Profile View Mode renders "My Commodity Expertise" section with chips', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Pre-save expertise
      final initial = await profileRepo.getProfile();
      await profileRepo.updateProfile(
        initial.copyWith(
          commodityExpertise: [
            const SellerCommodityExpertise(
              id: 'comm-wheat-01',
              commodityName: 'Wheat Sharbati',
              categoryName: 'Grains',
              isApproved: true,
            ),
            SellerCommodityExpertise.pending(
              commodityName: 'Organic Mustard Rare',
              categoryName: 'Oilseeds',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildProfileWidget());
      await tester.pumpAndSettle();

      // Verify accordion exists
      final sectionFinder = find.byKey(const Key('profile_section_commodity_expertise'));
      expect(sectionFinder, findsOneWidget);
      expect(find.text('My Commodity Expertise'), findsOneWidget);

      // Expand accordion
      await tester.tap(sectionFinder);
      await tester.pumpAndSettle();

      // Verify chips rendered
      expect(find.text('Wheat Sharbati'), findsOneWidget);
      expect(find.text('Organic Mustard Rare (Pending)'), findsOneWidget);
    });

    testWidgets('2. Edit Mode: Seller can manually select multiple commodities from catalogue', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildProfileWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Verify "My Commodity Expertise" edit card exists
      expect(find.byKey(const Key('edit_commodity_expertise_card')), findsOneWidget);

      // Tap "+ Select from Catalogue"
      final selectBtn = find.byKey(const Key('btn_add_expertise_from_catalogue'));
      expect(selectBtn, findsOneWidget);
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();

      // Bottom sheet is open with catalogue options
      expect(find.text('Select Commodities'), findsOneWidget);
      expect(find.byKey(const Key('catalogue_option_comm-wheat-01')), findsOneWidget);
      expect(find.byKey(const Key('catalogue_option_comm-mustard-01')), findsOneWidget);

      // Check Wheat and Mustard
      await tester.tap(find.byKey(const Key('catalogue_option_comm-wheat-01')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalogue_option_comm-mustard-01')));
      await tester.pumpAndSettle();

      // Tap Done
      await tester.tap(find.byKey(const Key('btn_apply_catalogue_selection')));
      await tester.pumpAndSettle();

      // Verify both selected chips are displayed
      expect(find.text('Wheat Sharbati'), findsOneWidget);
      expect(find.text('Mustard Seed Bold'), findsOneWidget);

      // Remove Wheat
      final wheatChip = find.byKey(const Key('selected_expertise_chip_comm-wheat-01'));
      expect(wheatChip, findsOneWidget);
      // Tap delete icon on wheat chip
      final deleteIconFinder = find.descendant(
        of: wheatChip,
        matching: find.byType(InkWell),
      );
      if (deleteIconFinder.evaluate().isNotEmpty) {
        await tester.tap(deleteIconFinder.last);
      } else {
        await tester.tap(wheatChip);
      }
      await tester.pumpAndSettle();
    });

    testWidgets('3. Edit Mode: Seller can add missing commodity (pending approval, non-mutation of master)', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildProfileWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Tap "Add Commodity"
      await tester.tap(find.byKey(const Key('btn_add_custom_commodity')));
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.byKey(const Key('add_missing_commodity_dialog')), findsOneWidget);

      // Enter custom commodity details
      await tester.enterText(
        find.byKey(const Key('custom_commodity_name_input')),
        'Speciality Guar Gum Pure',
      );
      await tester.enterText(
        find.byKey(const Key('custom_commodity_category_input')),
        'Agro Derivatives',
      );
      await tester.pumpAndSettle();

      // Tap Add Commodity button in dialog
      await tester.tap(find.byKey(const Key('btn_confirm_add_custom_commodity')));
      await tester.pumpAndSettle();

      // Dialog closed, custom chip with (Pending) appears in list
      expect(find.text('Speciality Guar Gum Pure (Pending)'), findsOneWidget);
    });

    testWidgets('4. Explicit save confirmation workflow commits expertise', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildProfileWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Add a commodity
      await tester.tap(find.byKey(const Key('btn_add_custom_commodity')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom_commodity_name_input')),
        'Organic Soybean Grade A',
      );
      await tester.tap(find.byKey(const Key('btn_confirm_add_custom_commodity')));
      await tester.pumpAndSettle();

      // Fill required business fields to pass form validation
      await tester.enterText(
        find.byKey(const Key('edit_company_name_field')),
        'Bikaner Agro Hub Ltd',
      );
      await tester.enterText(
        find.byKey(const Key('edit_full_name_field')),
        'Ramesh Sharma',
      );
      await tester.enterText(
        find.byKey(const Key('edit_mobile_field')),
        '9829012345',
      );
      await tester.enterText(
        find.byKey(const Key('edit_location_name_field')),
        'Mandi Godown 5',
      );
      await tester.pumpAndSettle();

      // Tap Save in AppBar
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      // Mandatory Confirmation Sheet appears
      expect(find.byKey(const Key('profile_review_confirmation_sheet')), findsOneWidget);
      expect(find.text('Confirm and Save'), findsOneWidget);

      // Confirm save
      await tester.tap(find.byKey(const Key('confirm_and_save_button')));
      await tester.pumpAndSettle();

      // Profile is saved, back in view mode
      final saved = await profileRepo.getProfile();
      expect(saved.commodityExpertise, isNotEmpty);
      expect(
        saved.commodityExpertise.any((c) => c.commodityName == 'Organic Soybean Grade A'),
        isTrue,
      );
    });

    testWidgets('5. Cancel edit discards unsaved commodity selections', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildProfileWidget(isInitialEdit: true));
      await tester.pumpAndSettle();

      // Add commodity
      await tester.tap(find.byKey(const Key('btn_add_custom_commodity')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom_commodity_name_input')),
        'Unsaved Millet Crop',
      );
      await tester.tap(find.byKey(const Key('btn_confirm_add_custom_commodity')));
      await tester.pumpAndSettle();

      // Tap Cancel in AppBar
      await tester.tap(find.byKey(const Key('cancel_profile_button')));
      await tester.pumpAndSettle();

      // Discard confirmation dialog appears
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('discard_changes_button')));
      await tester.pumpAndSettle();

      // Verify view mode has not saved the draft
      final profile = await profileRepo.getProfile();
      expect(
        profile.commodityExpertise.any((c) => c.commodityName == 'Unsaved Millet Crop'),
        isFalse,
      );
    });
  });

  group('Priority Commodity Posting Order Tests', () {
    testWidgets('6. CommodityPickerSheet renders "My Expertise" first when seller has expertise', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final expertiseList = [
        sampleMasterCommodities[0], // Wheat
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showCommodityPickerSheet(
                    context: ctx,
                    commodities: sampleMasterCommodities,
                    expertiseCommodities: expertiseList,
                    onRefresh: () async => sampleMasterCommodities,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // "My Expertise" header appears first
      expect(find.byKey(const Key('picker-expertise-header')), findsOneWidget);
      expect(find.byKey(const Key('expertise-commodity-option-comm-wheat-01')), findsOneWidget);

      // "All Commodities" section appears below
      expect(find.byKey(const Key('picker-all-commodities-header')), findsOneWidget);
      expect(find.byKey(const Key('commodity-option-comm-mustard-01')), findsOneWidget);

      // Selecting from My Expertise returns the commodity
      await tester.tap(find.byKey(const Key('expertise-commodity-option-comm-wheat-01')));
      await tester.pumpAndSettle();

      // Sheet is closed
      expect(find.byKey(const Key('picker-expertise-header')), findsNothing);
    });

    testWidgets('7. CommodityPickerSheet with no expertise renders normal list without clutter', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showCommodityPickerSheet(
                    context: ctx,
                    commodities: sampleMasterCommodities,
                    expertiseCommodities: const [], // Empty expertise
                    onRefresh: () async => sampleMasterCommodities,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // No "My Expertise" clutter
      expect(find.byKey(const Key('picker-expertise-header')), findsNothing);
      expect(find.byKey(const Key('picker-all-commodities-header')), findsNothing);

      // Complete catalogue is immediately available and selectable
      expect(find.byKey(const Key('commodity-option-comm-wheat-01')), findsOneWidget);
      expect(find.byKey(const Key('commodity-option-comm-mustard-01')), findsOneWidget);
    });

    testWidgets('8. Permitted commodities remain searchable even if not in expertise', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final expertiseList = [
        sampleMasterCommodities[0], // Wheat only
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showCommodityPickerSheet(
                    context: ctx,
                    commodities: sampleMasterCommodities,
                    expertiseCommodities: expertiseList,
                    onRefresh: () async => sampleMasterCommodities,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Search for Barley (which is NOT in expertise)
      await tester.enterText(find.byType(TextField), 'Barley');
      await tester.pumpAndSettle();

      // Barley is displayed and selectable
      expect(find.byKey(const Key('commodity-option-comm-barley-01')), findsOneWidget);
      await tester.tap(find.byKey(const Key('commodity-option-comm-barley-01')));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });
  });
}
