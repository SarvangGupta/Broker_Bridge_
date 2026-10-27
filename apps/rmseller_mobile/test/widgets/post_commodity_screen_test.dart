import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/commodities/presentation/post_commodity_screen.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';

import '../support/fake_commodities_repository.dart';
import '../support/fake_profile_repository.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

Future<FakeCommoditiesRepository> _pump(
  WidgetTester tester, {
  FakeProfileRepository? profile,
  Size size = const Size(1080, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  final repo = FakeCommoditiesRepository();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PostCommodityScreen(
        commoditiesRepository: repo,
        profileRepository: profile ?? FakeProfileRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _toggle(WidgetTester tester, int section) async {
  final header = find.byKey(Key('post_section_header_$section'));
  // The page is a lazy ListView: scroll until the header is built.
  final page = find.byType(Scrollable).first;
  if (header.evaluate().isEmpty) {
    await tester.scrollUntilVisible(header, 200, scrollable: page);
  }
  await tester.ensureVisible(header);
  await tester.tap(header);
  await tester.pumpAndSettle();
}

Future<void> _fillCommodity(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('commodity-picker-field')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('commodity-picker-search')),
    'wheat bran',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('commodity-option-$wheatBranId')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('quantity_field')), '25');
  await tester.enterText(find.byKey(const Key('asking_price_field')), '2450');
  await tester.pumpAndSettle();
}

void main() {
  group('RB-SELLER-POST-UX-05: compact Post Commodity Lot', () {
    testWidgets('shows four compact sections and one primary action', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Post Commodity Lot'), findsOneWidget);
      expect(find.text('1. Commodity & Pricing'), findsOneWidget);
      expect(find.text('2. Warehouse & Loading'), findsOneWidget);
      expect(find.text('3. Lab Testing & Reports'), findsOneWidget);
      expect(find.text('4. My Trusted Broker'), findsOneWidget);
      expect(find.text('Review & List Commodity'), findsOneWidget);
      // The old inline review card is gone from the main page.
      expect(find.text('List Commodity on Desk'), findsNothing);
    });

    testWidgets('only one section is open; collapsing keeps typed values', (
      tester,
    ) async {
      await _pump(tester);
      // Commodity opens by default while incomplete.
      expect(find.byKey(const Key('quantity_field')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('quantity_field')), '40');

      await _toggle(tester, 3); // open Broker → Commodity closes
      expect(find.byKey(const Key('quantity_field')), findsNothing);

      await _toggle(tester, 0);
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('quantity_field')),
      );
      expect(field.controller!.text, '40');
    });

    testWidgets('section headers are accessible expandable buttons', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      final node = tester.getSemantics(
        find.byKey(const Key('post_section_header_3')),
      );
      expect(
        node,
        matchesSemantics(
          label: '4. My Trusted Broker. No broker selected · open broker pool',
          isButton: true,
          hasExpandedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('collapsed summaries reflect current values', (tester) async {
      await _pump(tester);
      await _fillCommodity(tester);
      await _toggle(tester, 0); // collapse
      expect(find.textContaining('Wheat Bran'), findsWidgets);
      expect(find.text('25 MT · ₹2450/MT'), findsOneWidget);
      expect(find.text('Testing not requested'), findsOneWidget);
      expect(find.text('No report attached'), findsOneWidget);
    });

    testWidgets('no saved location: prompt shown, nothing preselected', (
      tester,
    ) async {
      final repo = await _pump(tester);
      // Collapsed summary + the readiness card's action (QUICK-POST-01).
      expect(find.text('Add warehouse location'), findsNWidgets(2));
      expect(find.byKey(const Key('readiness-location-missing')), findsOneWidget);
      await _fillCommodity(tester);

      await listViaReview(tester);
      // Review does not open; the location section opens instead.
      expect(find.byKey(const Key('confirm_list_button')), findsNothing);
      expect(find.byKey(const Key('edit_location_button')), findsOneWidget);
      expect(find.text('Add Location'), findsOneWidget);
      expect(repo.submitted, isEmpty);
    });

    testWidgets('saved profile location fills the location summary', (
      tester,
    ) async {
      await _pump(tester, profile: FakeProfileRepository.withWarehouse());
      expect(find.textContaining('Test Godown'), findsOneWidget);
      expect(find.text('Loading: same as warehouse'), findsOneWidget);

      await _toggle(tester, 1);
      expect(
        find.byKey(const Key('location_from_profile_note')),
        findsOneWidget,
      );
      expect(find.text('Edit Location'), findsOneWidget);
    });

    testWidgets('saved location with an unknown district asks for it once', (
      tester,
    ) async {
      final state = MasterCommodityData.verifiedStates.first;
      await _pump(
        tester,
        profile: FakeProfileRepository(
          savedLocation: BusinessLocationModel(
            name: 'Old Godown',
            addressLine: 'Plot 1',
            locality: '',
            stateId: state.id,
            stateName: state.name,
            districtId: 'not-in-master',
            districtName: 'Retired District',
            pinCode: '',
            latitude: null,
            longitude: null,
          ),
        ),
      );
      expect(find.text('Saved address loaded · choose district'), findsOneWidget);
      await _toggle(tester, 1);
      expect(find.textContaining('needs to be chosen again'), findsOneWidget);
      expect(find.textContaining('No warehouse location yet'), findsNothing);
      expect(find.textContaining('Filled from your saved'), findsNothing);
    });

    testWidgets('a saved distinct office is kept separate', (tester) async {
      await _pump(
        tester,
        profile: FakeProfileRepository.withWarehouse(office: 'HQ Tower, MG Road'),
      );
      await _toggle(tester, 1);
      expect(find.text('HQ Tower, MG Road'), findsOneWidget);
    });

    testWidgets('empty submit shows field errors and opens Commodity', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await _toggle(tester, 0); // collapse first
      await listViaReview(tester);
      expect(find.text('Required'), findsWidgets);
      expect(repo.submitted, isEmpty);
    });

    testWidgets('review shows current values; Edit returns to the section', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        profile: FakeProfileRepository.withWarehouse(),
      );
      await _fillCommodity(tester);

      await tester.tap(find.byKey(const Key('review_and_list_button')));
      await tester.pumpAndSettle();
      expect(find.text('Supply Quantity'), findsOneWidget);
      expect(find.text('25 MT'), findsOneWidget);
      expect(find.text('Asking Price'), findsOneWidget);
      expect(find.text('Office HQ'), findsOneWidget);
      expect(find.text('Commercial Terms'), findsOneWidget);
      expect(find.text('Trusted Broker Routing'), findsOneWidget);
      expect(repo.submitted, isEmpty); // reviewing never submits

      await tester.tap(find.byKey(const Key('review_edit_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm_list_button')), findsNothing);
      expect(find.byKey(const Key('edit_location_button')), findsOneWidget);
      expect(repo.submitted, isEmpty);
    });

    testWidgets('confirming the review submits once through the repository', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        profile: FakeProfileRepository.withWarehouse(),
      );
      await _fillCommodity(tester);
      await listViaReview(tester);

      expect(repo.submitted, hasLength(1));
      final dto = repo.submitted.single;
      expect(dto.commodityId, wheatBranId);
      expect(dto.totalQuantity, 25);
      expect(dto.warehouseName, contains('Test Godown'));
      // The fake save fails: no false success.
      expect(find.textContaining('listed successfully'), findsNothing);
    });

    // RB-SELLER-AVAILABILITY-RLS-FIX-01
    testWidgets('an RLS rejection shows a clear message and keeps the form', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        profile: FakeProfileRepository.withWarehouse(),
      );
      repo.submitError = const ListingSubmitException(
        'Your account is not yet allowed to publish listings. Please contact support.',
        code: '42501',
      );
      await _fillCommodity(tester);
      await listViaReview(tester);

      expect(repo.submitted, hasLength(1));
      expect(find.textContaining('not yet allowed to publish'), findsOneWidget);
      expect(find.textContaining('42501'), findsNothing);
      expect(find.textContaining('listed successfully'), findsNothing);
      // Still on the form, values intact.
      if (find.byKey(const Key('quantity_field')).evaluate().isEmpty) {
        await _toggle(tester, 0);
      }
      final qty = tester.widget<TextFormField>(
        find.byKey(const Key('quantity_field')),
      );
      expect(qty.controller!.text, '25');
    });

    // RB-SELLER-POST-REGRESSION-01 (BUG-08): a failed or cancelled picker
    // must never fabricate an attached report.
    // Under the test binding image_picker returns null (= cancel) while
    // file_picker throws (= failure), so both paths are covered.
    for (final (option, fails) in [
      ('Choose Image', false),
      ('Choose Document', true),
    ]) {
      testWidgets('lab report picker ${fails ? 'failure' : 'cancel'} attaches nothing', (
        tester,
      ) async {
        await _pump(tester, profile: FakeProfileRepository.withWarehouse());
        await _toggle(tester, 2); // Lab Testing & Reports
        final add = find.text('Add Lab Report');
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        await tester.tap(find.text(option));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Could not open the'),
          fails ? findsOneWidget : findsNothing,
        );
        expect(find.text('Add Lab Report'), findsOneWidget); // still empty
        expect(find.textContaining('lab_certificate'), findsNothing);
        expect(find.textContaining('assay_report'), findsNothing);
        await _toggle(tester, 2); // collapse → summary
        expect(find.text('No report attached'), findsOneWidget);
      });
    }

    // RB-SELLER-LAB-PAYMENT-SAFETY-01: starting UPI payment and checking status
    // never shows "Paid — Payment Verified" without authoritative confirmation.
    testWidgets('UPI payment check stays pending; label never claims verified', (
      tester,
    ) async {
      // No real UPI app: the launcher just reports "opened".
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncher();
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      await _pump(tester, profile: FakeProfileRepository.withWarehouse());
      await _toggle(tester, 2); // Lab Testing & Reports
      final toggle = find.byType(Switch).first;
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      final pay = find.textContaining('Pay via UPI');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(find.text('Payment Verification Pending'), findsOneWidget);
      expect(find.textContaining('cannot confirm UPI payments'), findsOneWidget);

      final check = find.text('Check Status');
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      // SnackBars queue: let "UPI app opened…" expire to see the result.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('Paid — Payment Verified'), findsNothing);
      expect(find.textContaining('Payment verified'), findsNothing);
      expect(find.textContaining('Payment not confirmed yet'), findsOneWidget);
      expect(find.text('Payment Verification Pending'), findsOneWidget);
    });

    testWidgets('each section opens at 320px without overflow', (tester) async {
      await _pump(
        tester,
        profile: FakeProfileRepository.withWarehouse(),
        // Width is what matters for horizontal overflow; tall keeps headers on screen.
        size: const Size(320, 2400),
      );
      for (final s in [1, 2, 3, 0]) {
        await _toggle(tester, s);
        expect(tester.takeException(), isNull, reason: 'section $s');
      }
    });
  });
}
