// RB-SELLER-QUICK-POST-01: first-time vs returning seller journeys.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/commodities/domain/posting_history.dart';
import 'package:rmseller_mobile/features/commodities/presentation/post_commodity_screen.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';

import '../support/fake_commodities_repository.dart';
import '../support/fake_profile_repository.dart';

SellerCommodity _lot(
  String commodityId,
  String gradeId,
  String name,
  String grade,
  DateTime at, {
  double qty = 40,
  double price = 3333,
}) => SellerCommodity(
  id: 'lot-$commodityId-$gradeId-${at.millisecondsSinceEpoch}',
  lotNumber: 'LOT-OLD',
  commodityName: name,
  gradeName: grade,
  totalQuantity: qty,
  availableQuantity: qty,
  unit: 'MT',
  askingPrice: price,
  stateName: 'Rajasthan',
  districtName: 'Bikaner',
  status: 'Fulfilled',
  availableFrom: DateTime(2026, 1, 1),
  validUntil: DateTime(2026, 1, 8),
  commodityId: commodityId,
  gradeId: gradeId,
  brokerId: 'b0000000-0000-4000-8000-00000000000a',
  createdAt: at,
);

Future<(FakeCommoditiesRepository, FakeProfileRepository)> _pump(
  WidgetTester tester, {
  List<SellerCommodity>? history,
  Object? historyError,
  FakeProfileRepository? profile,
}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = FakeCommoditiesRepository()
    ..history = history
    ..historyError = historyError;
  final prof = profile ?? FakeProfileRepository.withWarehouse();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PostCommodityScreen(commoditiesRepository: repo, profileRepository: prof),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, prof);
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('commodity-picker-field')));
  await tester.tap(find.byKey(const Key('commodity-picker-field')));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

MasterGrade? _grade(WidgetTester tester) => tester
    .widget<DropdownButton<MasterGrade>>(
      find.descendant(
        of: find.byKey(const Key('grade_dropdown')),
        matching: find.byType(DropdownButton<MasterGrade>),
      ),
    )
    .value;

void main() {
  test('history: distinct (product, grade), most recent first, no stale values', () {
    final items = PreviousCommodity.fromListings([
      _lot(maizeId, maizeFeedId, 'Maize', 'Feed', DateTime(2026, 10, 1)),
      _lot(maizeId, maizeFeedId, 'Maize', 'Feed', DateTime(2026, 10, 20)),
      _lot(maizeId, maizeGradeAId, 'Maize', 'Grade A', DateTime(2026, 10, 5)),
      _lot(wheatBranId, wheatBranFaqId, 'Wheat Bran', 'FAQ', DateTime(2026, 10, 10)),
    ]);
    expect(items.map((p) => '${p.commodityId}|${p.gradeId}'), [
      '$maizeId|$maizeFeedId',
      '$wheatBranId|$wheatBranFaqId',
      '$maizeId|$maizeGradeAId',
    ]);
    expect(items.first.lastPostedAt, DateTime(2026, 10, 20));
  });

  group('Journey A: first-time seller', () {
    testWidgets('incomplete profile: asks only for what is missing', (tester) async {
      await _pump(tester, history: const [], profile: FakeProfileRepository());
      expect(find.text('Complete your business details once'), findsOneWidget);
      expect(find.text('• Warehouse / godown address'), findsOneWidget);
      expect(find.text('• State'), findsOneWidget);
      await _openPicker(tester);
      expect(find.byKey(const Key('picker-first-commodity')), findsOneWidget);
      expect(find.byKey(const Key('picker-previous-header')), findsNothing);
    });

    testWidgets('complete profile: no blocking step', (tester) async {
      await _pump(tester, history: const []);
      expect(find.byKey(const Key('readiness-location-missing')), findsNothing);
      expect(find.byKey(const Key('readiness-incomplete')), findsNothing);
      expect(find.byKey(const Key('readiness-unverified')), findsNothing);
    });

    testWidgets('firm region prefilled from the server; completing the address '
        'keeps the lot and saves the default once', (tester) async {
      final state = MasterCommodityData.verifiedStates.first;
      final district = MasterCommodityData.verifiedDistricts.firstWhere(
        (d) => d.stateId == state.id,
      );
      final (_, prof) = await _pump(
        tester,
        history: const [],
        profile: FakeProfileRepository(
          readiness: ListingReadiness.complete(
            firmName: 'Test Agro Firm',
            companyStateId: state.id,
            companyDistrictId: district.id,
          ),
        ),
      );
      // Only the address is missing now.
      expect(find.text('• Warehouse / godown address'), findsOneWidget);
      expect(find.text('• State'), findsNothing);
      expect(find.text('• District'), findsNothing);

      await tester.enterText(find.byKey(const Key('quantity_field')), '12');
      await tester.tap(find.text('Add warehouse location').last);
      await tester.pumpAndSettle();
      // Opened with the missing field already flagged.
      expect(find.text('Address is required'), findsOneWidget);
      final address = find.descendant(
        of: find.ancestor(of: find.text('Address *'), matching: find.byType(Column)).first,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(address, 'Plot 9, Godown Road');
      await tester.tap(find.text('Save Location'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('readiness-location-missing')), findsNothing);
      expect(prof.savedDefaults.single.addressLine, 'Plot 9, Godown Road');
      expect(_text(tester, 'quantity_field'), '12'); // in-progress lot kept
    });

    testWidgets('firm not linked: clear blocking message, review blocked', (tester) async {
      await _pump(
        tester,
        history: const [],
        profile: FakeProfileRepository.withWarehouse(
          readiness: const ListingReadiness.incomplete([
            'Your account is not linked to a business (firm). Please contact support.',
          ]),
        ),
      );
      expect(find.byKey(const Key('readiness-incomplete')), findsOneWidget);
      expect(find.textContaining('not linked to a business'), findsOneWidget);
    });
  });

  group('Journey B: returning seller', () {
    final history = [
      _lot(maizeId, maizeGradeAId, 'Maize', 'Grade A', DateTime(2026, 10, 20)),
      _lot(maizeId, maizeGradeAId, 'Maize', 'Grade A', DateTime(2026, 9, 1)),
      _lot(wheatBranId, wheatBranFaqId, 'Wheat Bran', 'FAQ', DateTime(2026, 10, 10)),
    ];

    testWidgets('previous commodities on top, deduplicated, newest first', (tester) async {
      await _pump(tester, history: history);
      await _openPicker(tester);
      expect(find.byKey(const Key('picker-previous-header')), findsOneWidget);
      final maize = find.byKey(Key('previous-option-$maizeId-$maizeGradeAId'));
      final bran = find.byKey(Key('previous-option-$wheatBranId-$wheatBranFaqId'));
      expect(maize, findsOneWidget);
      expect(bran, findsOneWidget);
      expect(tester.getTopLeft(maize).dy, lessThan(tester.getTopLeft(bran).dy));
      expect(find.byKey(const Key('picker-first-commodity')), findsNothing);
    });

    testWidgets('picking a previous commodity prefills product, category and its '
        'grade, but never the old quantity or price', (tester) async {
      await _pump(tester, history: history);
      await _openPicker(tester);
      await tester.tap(find.byKey(Key('previous-option-$maizeId-$maizeGradeAId')));
      await tester.pumpAndSettle();

      expect(find.text('Category: Grains & Energy Ingredients'), findsOneWidget);
      // Remembered grade, not the product's first grade (Feed).
      expect(_grade(tester)?.id, maizeGradeAId);
      // Old lot had qty 40 / ₹3333: never copied.
      expect(_text(tester, 'quantity_field'), isEmpty);
      expect(_text(tester, 'asking_price_field'), isEmpty);
      expect(find.text('40'), findsNothing);
      expect(find.text('3333'), findsNothing);
    });

    testWidgets('quick post still requires new quantity and price', (tester) async {
      final (repo, _) = await _pump(tester, history: history);
      await _openPicker(tester);
      await tester.tap(find.byKey(Key('previous-option-$wheatBranId-$wheatBranFaqId')));
      await tester.pumpAndSettle();
      await listViaReview(tester);
      expect(find.text('Required'), findsWidgets);
      expect(repo.submitted, isEmpty);

      await tester.enterText(find.byKey(const Key('quantity_field')), '18');
      await tester.enterText(find.byKey(const Key('asking_price_field')), '2100');
      await listViaReview(tester);
      final dto = repo.submitted.single;
      expect(dto.commodityId, wheatBranId);
      expect(dto.gradeId, wheatBranFaqId);
      expect(dto.totalQuantity, 18);
      expect(dto.askingPrice, 2100);
      expect(dto.brokerId, isNull, reason: 'old broker not carried over');
    });

    testWidgets('returning seller without a saved location is asked for it', (tester) async {
      await _pump(tester, history: history, profile: FakeProfileRepository());
      expect(find.text('Add your warehouse location'), findsOneWidget);
    });
  });

  group('Failures', () {
    testWidgets('profile lookup failure: retryable, not treated as first-time, '
        'and blocks listing', (tester) async {
      final prof = FakeProfileRepository.withWarehouse(
        readiness: const ListingReadiness.unverified(
          'Could not check your business profile. Check your connection and retry.',
        ),
      );
      final (repo, _) = await _pump(tester, history: const [], profile: prof);
      expect(find.byKey(const Key('readiness-unverified')), findsOneWidget);
      expect(find.text('Complete your business details once'), findsNothing);

      await _openPicker(tester);
      await tester.tap(find.text('Wheat Bran'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quantity_field')), '5');
      await tester.enterText(find.byKey(const Key('asking_price_field')), '100');
      await listViaReview(tester);
      expect(find.byKey(const Key('confirm_list_button')), findsNothing);
      expect(repo.submitted, isEmpty);
      expect(_text(tester, 'quantity_field'), '5'); // form kept

      prof.readiness = const ListingReadiness.complete(firmName: 'Test Agro Firm');
      // The card's Retry (the blocked-review SnackBar has one too).
      final cardRetry = find.descendant(
        of: find.byKey(const Key('readiness-unverified')),
        matching: find.text('Retry'),
      );
      await tester.ensureVisible(cardRetry);
      await tester.tap(cardRetry);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readiness-unverified')), findsNothing);
    });

    testWidgets('history failure: error with retry, never "first commodity", '
        'catalogue still usable', (tester) async {
      final (repo, _) = await _pump(
        tester,
        historyError: const CommodityListException(CommodityListException.generic),
      );
      await _openPicker(tester);
      expect(find.byKey(const Key('picker-history-error')), findsOneWidget);
      expect(find.byKey(const Key('picker-first-commodity')), findsNothing);

      repo
        ..historyError = null
        ..history = [_lot(maizeId, maizeFeedId, 'Maize', 'Feed', DateTime(2026, 10, 1))];
      await tester.tap(find.descendant(
        of: find.byKey(const Key('picker-history-error')),
        matching: find.text('Retry'),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('picker-previous-header')), findsOneWidget);

      await tester.tap(find.byKey(const Key('commodity-option-$wheatBranId')));
      await tester.pumpAndSettle();
      expect(find.text('Category: Bran, Polish & Milling By-products'), findsOneWidget);
    });

    testWidgets('offline mode never shows sample lots as history', (tester) async {
      await _pump(tester); // history == null → offline
      await _openPicker(tester);
      expect(find.byKey(const Key('picker-previous-header')), findsNothing);
      expect(find.byKey(const Key('picker-first-commodity')), findsNothing);
      expect(find.textContaining('Desi Chana'), findsNothing);
    });
  });
}
