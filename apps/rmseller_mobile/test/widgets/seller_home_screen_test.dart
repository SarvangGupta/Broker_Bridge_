import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/core/widgets/app_loading_indicator.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/deals/data/seller_deals_repository.dart';
import 'package:rmseller_mobile/features/home/presentation/seller_home_screen.dart';

void main() {
  group('RB-SELLER-DASH-01: SellerHomeScreen Widget Tests', () {
    late SecureStorageService testStorage;
    late CommoditiesRepository testCommoditiesRepo;
    late SellerDealsRepository testDealsRepo;

    setUp(() async {
      testStorage = SecureStorageService()..enableMemoryFallbackForTesting();
      await testStorage.saveUserInfo(
        id: 'user-001',
        role: 'seller',
        email: 'seller@demo.com',
        fullName: 'Seller Desk',
        companyId: 'comp-001',
        companyName: 'Bikaner Agro Traders',
      );
      testCommoditiesRepo = CommoditiesRepository(storage: testStorage);
      testDealsRepo = SellerDealsRepository(storage: testStorage);
    });

    Widget createTestApp({ThemeData? theme, Size? physicalSize}) {
      return MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: SellerHomeScreen(
          storageService: testStorage,
          commoditiesRepository: testCommoditiesRepo,
          dealsRepository: testDealsRepo,
        ),
      );
    }

    testWidgets(
      'Initial pump shows loading state indicator for Seller Command Center',
      (tester) async {
        await tester.pumpWidget(createTestApp());

        expect(find.byType(AppLoadingIndicator), findsOneWidget);
        expect(find.text('Loading Seller Command Center...'), findsOneWidget);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Prominent banner is removed and primary metric cards start naturally at top of dashboard',
      (tester) async {
        await tester.pumpWidget(createTestApp());

        // Settle data loading
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // 1. Prominent disclaimer banner is NO LONGER in the dashboard body
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('Mandi Mediation Active'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.textContaining(
              'All commodity negotiations and bookings are mediated',
            ),
          ),
          findsNothing,
        );

        // 2. Primary KPI metric cards start immediately
        expect(find.text('Active Lots'), findsOneWidget);
        expect(find.text('In Negotiation'), findsOneWidget);
        expect(find.text('Booked Deals'), findsOneWidget);
        expect(
          find.text('Ready to Load'),
          findsNWidgets(2),
        ); // 1 Metric card + 1 lot status tag

        // 3. Quick Operations intact
        expect(find.text('Quick Operations'), findsOneWidget);
        expect(find.text('+ Post Commodity'), findsOneWidget);
        expect(find.text('Discover Brokers'), findsOneWidget);
      },
    );

    testWidgets(
      'Compact information icon renders near dashboard heading with accessible tooltip',
      (tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Verify dashboard heading is present
        expect(find.text('Bikaner Agro Traders'), findsOneWidget);
        expect(find.text('Seller Desk • Seller Desk'), findsOneWidget);

        // Verify compact information button
        final infoButtonFinder = find.byKey(const Key('mediation_info_button'));
        expect(infoButtonFinder, findsOneWidget);

        // Verify tooltip and icon
        final iconButton = tester.widget<IconButton>(infoButtonFinder);
        expect(iconButton.tooltip, equals('Mediation information'));
        expect(
          find.descendant(
            of: infoButtonFinder,
            matching: find.byIcon(LucideIcons.info),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tapping information icon displays detailed mediation disclosure in a dialog with verbatim text',
      (tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Tap compact information icon
        await tester.tap(find.byKey(const Key('mediation_info_button')));
        await tester.pumpAndSettle();

        // Verify dialog appears
        expect(find.byType(AlertDialog), findsOneWidget);

        // Verify title with verbatim text and shield icon
        expect(find.text('Mandi Mediation Active'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(LucideIcons.shieldCheck),
          ),
          findsOneWidget,
        );

        // Verify verbatim substantive disclaimer text
        expect(
          find.text(
            'All commodity negotiations and bookings are mediated through authorized mandi brokers. Buyer identities are shielded.',
          ),
          findsOneWidget,
        );

        // Verify Close action button exists
        expect(find.text('Close'), findsOneWidget);
      },
    );

    testWidgets(
      'Disclosure dialog can be dismissed reliably via Close button',
      (tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Open dialog
        await tester.tap(find.byKey(const Key('mediation_info_button')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        // Tap Close button
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Verify dialog is dismissed
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Active Lots'), findsOneWidget);
      },
    );

    testWidgets(
      'Disclosure dialog renders properly without overflow on compact mobile screens',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestApp());

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.byKey(const Key('mediation_info_button')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Mandi Mediation Active'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Respects dark theme styling', (tester) async {
      await tester.pumpWidget(createTestApp(theme: AppTheme.darkTheme));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('mediation_info_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Mandi Mediation Active'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
