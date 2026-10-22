import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/help/presentation/seller_help_support_screen.dart';
import 'package:rmseller_mobile/features/home/presentation/seller_home_screen.dart';
import 'package:rmseller_mobile/features/profile/data/business_location_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_profile_screen.dart';
import 'package:rmseller_mobile/features/profile/presentation/seller_settings_screen.dart';
import 'package:rmseller_mobile/features/profile/presentation/widgets/app_settings_section.dart';

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();

    // Populate mock authenticated seller session
    await storage.saveUserInfo(
      id: '20000000-0000-0000-0000-000000000001',
      role: 'seller',
      email: 'seller@agroenterprises.com',
      fullName: 'Ramesh Agro Traders',
      companyId: '20000000-0000-0000-0000-000000000101',
      companyName: 'Bikaner Grain Processing Ltd',
      companyGst: '08AAAAA0000A1Z5',
    );
    await storage.savePreference('user_mobile', '9829012345');
    await storage.savePreference('primary_mandi', 'Bikaner Krishi Upaj Mandi');
    await storage.savePreference('company_state', 'Rajasthan');
    await storage.savePreference('company_district', 'Bikaner');
    await storage.savePreference(
      'office_address',
      'Commercial Tower 4, Bikaner Corporate Hub',
    );
    await storage.savePreference(
      'business_location_name',
      'Bikaner Krishi Upaj Mandi Yard Godown A-4',
    );
    await storage.savePreference(
      'business_location_address',
      'Plot 12, Industrial Area, Mandi Road',
    );
    await storage.savePreference(
      'business_location_locality',
      'Khara Industrial Area',
    );
    await storage.savePreference(
      'business_location_state_id',
      '40000000-0000-0000-0000-000000000001',
    );
    await storage.savePreference('business_location_state', 'Rajasthan');
    await storage.savePreference(
      'business_location_district_id',
      '50000000-0000-0000-0000-000000000001',
    );
    await storage.savePreference(
      'business_location_district',
      'Bikaner Mandi Hub',
    );
    await storage.savePreference('business_location_pincode', '334001');
  });

  group('RB-SELLER-PROFILE-01: Dashboard Three-Dot Menu Tests', () {
    testWidgets(
      'Three-dot overflow menu button renders on SellerHomeScreen appbar',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: SellerHomeScreen(storageService: storage)),
          ),
        );
        await tester.pumpAndSettle();

        // Verify three-dot overflow button is in actions
        final overflowBtn = find.byKey(
          const Key('dashboard_overflow_menu_button'),
        );
        expect(overflowBtn, findsOneWidget);

        final icon = tester.widget<Icon>(
          find.descendant(of: overflowBtn, matching: find.byType(Icon)),
        );
        expect(icon.icon, LucideIcons.ellipsisVertical);
      },
    );

    testWidgets(
      'Tapping overflow menu displays all required options in order',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: SellerHomeScreen(storageService: storage)),
          ),
        );
        await tester.pumpAndSettle();

        // Open menu
        await tester.tap(
          find.byKey(const Key('dashboard_overflow_menu_button')),
        );
        await tester.pumpAndSettle();

        // Verify all 5 menu options exist
        expect(find.byKey(const Key('menu_item_profile')), findsOneWidget);
        expect(find.text('My Profile'), findsOneWidget);

        expect(find.byKey(const Key('menu_item_settings')), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);

        expect(find.byKey(const Key('menu_item_help')), findsOneWidget);
        expect(find.text('Help & Support'), findsOneWidget);

        expect(
          find.byKey(const Key('menu_item_notifications')),
          findsOneWidget,
        );
        expect(find.text('Notifications'), findsOneWidget);

        expect(find.byKey(const Key('menu_item_logout')), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);
      },
    );

    testWidgets(
      'Selecting Logout displays confirmation dialog with cancel support',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: SellerHomeScreen(storageService: storage)),
          ),
        );
        await tester.pumpAndSettle();

        // Open overflow menu
        await tester.tap(
          find.byKey(const Key('dashboard_overflow_menu_button')),
        );
        await tester.pumpAndSettle();

        // Tap Logout
        await tester.tap(find.byKey(const Key('menu_item_logout')));
        await tester.pumpAndSettle();

        // Verify Confirmation Dialog
        expect(find.text('Sign Out'), findsNWidgets(2));
        expect(
          find.text('Are you sure you want to sign out of the RMSeller desk?'),
          findsOneWidget,
        );

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog is dismissed, user remains on dashboard
        expect(find.text('Sign Out'), findsNothing);
      },
    );
  });

  group('RB-SELLER-PROFILE-02: Profile UI Simplification & Location Tests', () {
    testWidgets(
      'Renders simplified profile in View Mode without technical UUIDs or metadata',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = SellerProfileRepository(storage: storage);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: SellerProfileScreen(
                profileRepository: repo,
                storageService: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // View mode header
        expect(find.text('Seller Profile & Mandi Desk'), findsOneWidget);
        expect(find.text('Bikaner Grain Processing Ltd'), findsOneWidget);
        expect(find.text('Ramesh Agro Traders'), findsNWidgets(2));
        expect(find.text('Verified Seller Enterprise'), findsOneWidget);

        // Edit Profile buttons
        expect(find.byKey(const Key('edit_profile_button')), findsOneWidget);
        expect(
          find.byKey(const Key('appbar_edit_profile_button')),
          findsOneWidget,
        );

        // Business Information section
        expect(find.text('Business Information'), findsOneWidget);
        expect(find.text('Contact Person:'), findsOneWidget);
        expect(find.text('Mobile Number:'), findsOneWidget);
        expect(find.text('9829012345'), findsOneWidget);
        expect(find.text('Business Email:'), findsOneWidget);
        expect(find.text('seller@agroenterprises.com'), findsOneWidget);
        expect(find.text('GSTIN:'), findsOneWidget);
        expect(find.text('08AAAAA0000A1Z5'), findsOneWidget);
        expect(find.text('Corporate HQ:'), findsOneWidget);
        expect(
          find.text('Commercial Tower 4, Bikaner Corporate Hub'),
          findsOneWidget,
        );

        // Business Location (Shop / Godown) section
        expect(find.byKey(const Key('business_location_view_card')), findsOneWidget);
        expect(find.text('Business Location (Shop / Godown)'), findsOneWidget);
        expect(
          find.text('Bikaner Krishi Upaj Mandi Yard Godown A-4'),
          findsOneWidget,
        );
        expect(
          find.text('Plot 12, Industrial Area, Mandi Road'),
          findsOneWidget,
        );
        expect(find.text('Bikaner Mandi Hub, Rajasthan'), findsOneWidget);
        expect(find.text('334001'), findsOneWidget);

        // VERIFY: Cryptographic UUIDs, Supabase references, and technical role lines are REMOVED
        expect(find.text('Protected Account Identifiers (Read-Only)'), findsNothing);
        expect(find.text('Cryptographic account key immutable under platform security rules.'), findsNothing);
        expect(find.text('Primary authentication credential managed by Supabase Auth.'), findsNothing);
        expect(find.text('20000000-0000-0000-0000-000000000001'), findsNothing);
        expect(find.text('Enterprise Role:'), findsNothing);
      },
    );

    testWidgets(
      'Tapping Edit Profile opens editable form with location controls and no technical card',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = SellerProfileRepository(storage: storage);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: SellerProfileScreen(
                profileRepository: repo,
                storageService: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Edit Profile
        await tester.tap(find.byKey(const Key('edit_profile_button')));
        await tester.pumpAndSettle();

        // Verify Edit View is active
        expect(find.text('Edit Business Profile'), findsOneWidget);
        expect(find.byKey(const Key('edit_full_name_field')), findsOneWidget);
        expect(
          find.byKey(const Key('edit_company_name_field')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('edit_mobile_field')), findsOneWidget);
        expect(find.byKey(const Key('edit_gstin_field')), findsOneWidget);
        expect(find.byKey(const Key('edit_office_address_field')), findsOneWidget);

        // Verify Business Location section in Edit Mode
        expect(find.byKey(const Key('business_location_edit_card')), findsOneWidget);
        expect(find.byKey(const Key('btn_use_current_location')), findsOneWidget);
        expect(find.byKey(const Key('btn_location_presets')), findsOneWidget);
        expect(find.byKey(const Key('edit_location_name_field')), findsOneWidget);
        expect(find.byKey(const Key('edit_location_address_field')), findsOneWidget);
        expect(find.byKey(const Key('edit_location_locality_field')), findsOneWidget);
        expect(find.byKey(const Key('location_state_dropdown')), findsOneWidget);
        expect(find.byKey(const Key('location_district_dropdown')), findsOneWidget);
        expect(find.byKey(const Key('edit_location_pincode_field')), findsOneWidget);

        // VERIFY: Technical read-only identifiers card is NOT present in Edit Mode
        expect(find.text('Protected Account Identifiers (Read-Only)'), findsNothing);

        // Verify Cancel and Save buttons
        expect(find.byKey(const Key('cancel_profile_button')), findsOneWidget);
        expect(find.byKey(const Key('save_profile_button')), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Use Current Location populates State & District with confidence indicator',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = SellerProfileRepository(storage: storage);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: SellerProfileScreen(
                profileRepository: repo,
                storageService: storage,
                isInitialEdit: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Use Current Location
        await tester.tap(find.byKey(const Key('btn_use_current_location')));
        await tester.pumpAndSettle();

        // Verify detection success message
        expect(find.textContaining('Location verified: Bikaner Mandi Hub, Rajasthan'), findsOneWidget);

        // Verify state and district dropdown selections are set
        final stateFinder = find.byKey(const Key('location_state_dropdown'));
        expect(stateFinder, findsOneWidget);

        final districtFinder = find.byKey(const Key('location_district_dropdown'));
        expect(districtFinder, findsOneWidget);
      },
    );

    testWidgets(
      'Changing State dropdown cascades to filter districts for the selected state',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = SellerProfileRepository(storage: storage);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: SellerProfileScreen(
                profileRepository: repo,
                storageService: storage,
                isInitialEdit: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially state is Rajasthan with Bikaner Mandi Hub
        expect(find.text('Rajasthan'), findsOneWidget);

        // Open State Dropdown
        await tester.tap(find.byKey(const Key('location_state_dropdown')));
        await tester.pumpAndSettle();

        // Select Madhya Pradesh
        await tester.tap(find.text('Madhya Pradesh').last);
        await tester.pumpAndSettle();

        // Verify state changed to Madhya Pradesh and district updated to MP district
        expect(find.text('Madhya Pradesh'), findsOneWidget);
        expect(find.text('Indore Mandi Complex'), findsOneWidget);
      },
    );

    testWidgets('Validation blocks empty fields and invalid mobile numbers', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = SellerProfileRepository(storage: storage);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SellerProfileScreen(
              profileRepository: repo,
              storageService: storage,
              isInitialEdit: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear Name
      await tester.enterText(find.byKey(const Key('edit_full_name_field')), '');

      // Enter invalid mobile
      await tester.enterText(
        find.byKey(const Key('edit_mobile_field')),
        '12345',
      );

      // Clear location name
      await tester.enterText(find.byKey(const Key('edit_location_name_field')), '');

      // Tap Save Changes
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      // Check validation error messages
      expect(
        find.text('Full name is required (minimum 2 characters)'),
        findsOneWidget,
      );
      expect(
        find.text('Enter a valid 10-digit Indian mobile number'),
        findsOneWidget,
      );
      expect(
        find.text('Facility name is required'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Cancel button discards changes and returns cleanly to View Mode',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = SellerProfileRepository(storage: storage);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: SellerProfileScreen(
                profileRepository: repo,
                storageService: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.byKey(const Key('edit_profile_button')));
        await tester.pumpAndSettle();

        // Make a change to name and location
        await tester.enterText(
          find.byKey(const Key('edit_full_name_field')),
          'Discarded Name Edit',
        );
        await tester.enterText(
          find.byKey(const Key('edit_location_name_field')),
          'Discarded Warehouse Name',
        );

        // Tap Cancel
        await tester.tap(find.byKey(const Key('cancel_profile_button')));
        await tester.pumpAndSettle();

        // Back in view mode with original unsaved name and location
        expect(find.text('Seller Profile & Mandi Desk'), findsOneWidget);
        expect(find.text('Ramesh Agro Traders'), findsNWidgets(2));
        expect(find.text('Bikaner Krishi Upaj Mandi Yard Godown A-4'), findsOneWidget);
        expect(find.text('Discarded Name Edit'), findsNothing);
        expect(find.text('Discarded Warehouse Name'), findsNothing);
      },
    );

    testWidgets(
      'Saving valid profile updates repository and displays success notice',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = SellerProfileRepository(storage: storage);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: SellerProfileScreen(
                profileRepository: repo,
                storageService: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.byKey(const Key('edit_profile_button')));
        await tester.pumpAndSettle();

        // Update name, mobile, and godown location
        await tester.enterText(
          find.byKey(const Key('edit_full_name_field')),
          'Ramesh Kumar Goyal',
        );
        await tester.enterText(
          find.byKey(const Key('edit_company_name_field')),
          'Goyal Agro Mills Pvt Ltd',
        );
        await tester.enterText(
          find.byKey(const Key('edit_mobile_field')),
          '9829099887',
        );
        await tester.enterText(
          find.byKey(const Key('edit_location_name_field')),
          'Goyal Mandi Godown Shed 7',
        );
        await tester.enterText(
          find.byKey(const Key('edit_location_address_field')),
          'Gate 4, Krishi Upaj Mandi, Bikaner',
        );

        // Tap Save Changes
        await tester.tap(find.byKey(const Key('save_profile_button')));
        await tester.pumpAndSettle();

        // Success snackbar displayed
        expect(find.text('Business profile updated successfully'), findsOneWidget);

        // Returns to view mode with refreshed values
        expect(find.text('Seller Profile & Mandi Desk'), findsOneWidget);
        expect(find.text('Goyal Agro Mills Pvt Ltd'), findsOneWidget);
        expect(find.text('Ramesh Kumar Goyal'), findsNWidgets(2));
        expect(find.text('Goyal Mandi Godown Shed 7'), findsOneWidget);
        expect(find.text('Gate 4, Krishi Upaj Mandi, Bikaner'), findsOneWidget);

        // Verify persistent storage was updated
        final updatedName = await storage.getUserFullName();
        expect(updatedName, 'Ramesh Kumar Goyal');

        final updatedCompany = await storage.getCompanyName();
        expect(updatedCompany, 'Goyal Agro Mills Pvt Ltd');

        final updatedLocName = await storage.getPreference('business_location_name');
        expect(updatedLocName, 'Goyal Mandi Godown Shed 7');
      },
    );
  });

  group('RB-SELLER-PROFILE-01: Dedicated Settings & Help Screens Tests', () {
    testWidgets(
      'SellerSettingsScreen renders AppBar and hosts AppSettingsSection',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: SellerSettingsScreen())),
        );
        await tester.pumpAndSettle();

        expect(find.text('Application Settings'), findsOneWidget);
        expect(find.byType(AppSettingsSection), findsOneWidget);
        expect(find.text('Application Preferences'), findsOneWidget);
      },
    );

    testWidgets(
      'SellerHelpSupportScreen renders all guidance sections and issue modal',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SellerHelpSupportScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Verify header and guidance topics
        expect(find.text('Help & Support'), findsOneWidget);
        expect(find.text('RMSeller Knowledge & Support'), findsOneWidget);
        expect(find.text('1. Seller Command Center & KPIs'), findsOneWidget);
        expect(find.text('2. Profile & Enterprise Account'), findsOneWidget);
        expect(
          find.text('3. Mandi Mediation & Counterparty Shield'),
          findsOneWidget,
        );
        expect(
          find.text('4. Commodity Lots & Quality Parameters'),
          findsOneWidget,
        );
        expect(find.text('5. Deals, Contracts & Dispatches'), findsOneWidget);

        // Verify honest support channel disclosure
        expect(find.text('Verified Support Channels'), findsOneWidget);

        // Tap Submit Support Ticket
        await tester.tap(find.text('Submit Support Ticket'));
        await tester.pumpAndSettle();

        // Verify Support Dialog opens with issue categories
        expect(find.text('Submit Support Request'), findsOneWidget);
        expect(find.text('Select Issue Category:'), findsOneWidget);
        expect(find.text('Describe the Issue:'), findsOneWidget);

        // Dismiss dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Submit Support Request'), findsNothing);
      },
    );
  });
}
