import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/commodities/presentation/post_commodity_screen.dart';

import '../support/fake_commodities_repository.dart';
import '../support/fake_profile_repository.dart';

// Live `master_units` rows (read-only snapshot 2026-10-25), including the duplicate MT.
const _kg = MasterUnit(
  id: 'bfefee25-68a1-4771-8910-6d4b04db39cc',
  name: 'Kilograms',
  symbol: 'kg',
);
const _tonn = MasterUnit(
  id: 'afd6b4a9-f2f4-4828-9ca6-8ffc3d58d3e8',
  name: 'Tonn',
  symbol: 'MT',
);
const _metricTon = MasterUnit(
  id: '22000000-0000-0000-0000-000000000001',
  name: 'Metric Ton',
  symbol: 'MT',
);
const _qtl = MasterUnit(
  id: '22000000-0000-0000-0000-000000000002',
  name: 'Quintal',
  symbol: 'Qtl',
);

// The fake repository's units come from the offline list (MT, QTL, KG).
const _offlineKgId = '30000000-0000-0000-0000-000000000003';

SellerCommodity _lot({required String unit, String? unitId}) => SellerCommodity(
  id: 'lot-1',
  lotNumber: 'LOT-KG-1',
  commodityName: 'Wheat Bran',
  gradeName: 'FAQ (Fair Average Quality)',
  totalQuantity: 2500,
  availableQuantity: 2500,
  unit: unit,
  unitId: unitId,
  askingPrice: 23.5,
  stateName: 'Rajasthan',
  districtName: 'Bikaner',
  status: 'Open',
  availableFrom: DateTime(2026, 10, 20),
  validUntil: DateTime(2026, 11, 20),
  commodityId: wheatBranId,
  gradeId: wheatBranFaqId,
  createdAt: DateTime(2026, 10, 20),
);

Future<void> _pump(
  WidgetTester tester,
  FakeCommoditiesRepository repo, {
  SellerCommodity? lot,
}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PostCommodityScreen(
        commoditiesRepository: repo,
        profileRepository: FakeProfileRepository.withWarehouse(),
        initialLot: lot,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

MasterUnit? _selectedUnit(WidgetTester tester) => tester
    .widget<DropdownButton<MasterUnit>>(
      find.descendant(
        of: find.byKey(const Key('unit_dropdown')),
        matching: find.byType(DropdownButton<MasterUnit>),
      ),
    )
    .value;

Future<void> _pickWheatBran(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('commodity-picker-field')));
  await tester.tap(find.byKey(const Key('commodity-picker-field')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('commodity-picker-search')),
    'wheat bran',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('commodity-option-$wheatBranId')));
  await tester.pumpAndSettle();
}

Future<void> _submitWith(
  WidgetTester tester, {
  required String qty,
  required String price,
}) async {
  await tester.enterText(find.byKey(const Key('quantity_field')), qty);
  await tester.enterText(find.byKey(const Key('asking_price_field')), price);
  await listViaReview(tester);
}

void main() {
  group('RB-RAW-MATERIAL-QUANTITY-PRICE-01: unit selection', () {
    test('new lots default to the "Metric Ton" MT row, not the duplicate or the first row', () {
      expect(
        PostCommodityScreen.defaultUnit([_kg, _tonn, _metricTon, _qtl]),
        _metricTon,
      );
      expect(PostCommodityScreen.defaultUnit([_kg, _tonn, _qtl]), _tonn);
      expect(PostCommodityScreen.defaultUnit([_kg, _qtl]), isNull);
    });

    test('a saved lot keeps its own unit (by ID, then symbol); unknown units are not substituted', () {
      final units = [_metricTon, _qtl, _kg];
      expect(
        PostCommodityScreen.unitForLot(units, _lot(unit: 'kg', unitId: _kg.id)),
        _kg,
      );
      expect(PostCommodityScreen.unitForLot(units, _lot(unit: 'KG')), _kg);
      expect(
        PostCommodityScreen.unitForLot(
          units,
          _lot(unit: 'bags', unitId: 'missing'),
        ),
        isNull,
      );
    });
  });

  group('RB-RAW-MATERIAL-QUANTITY-PRICE-01: form', () {
    testWidgets(
      'a new listing starts with empty quantity and price, MT preselected',
      (tester) async {
        await _pump(tester, FakeCommoditiesRepository());

        expect(_text(tester, 'quantity_field'), isEmpty);
        expect(_text(tester, 'asking_price_field'), isEmpty);
        expect(find.text('100'), findsNothing);
        expect(find.text('4800'), findsNothing);
        expect(_selectedUnit(tester)?.symbol, 'MT');
        expect(find.text('Asking Price (₹ per MT) *'), findsOneWidget);
        // Collapsed summary prompts instead of showing invented values.
        await tester.tap(find.byKey(const Key('post_section_header_0')));
        await tester.pumpAndSettle();
        expect(find.text('Add commodity details'), findsOneWidget);
      },
    );

    testWidgets(
      'editing a KG lot keeps KG and the saved numbers (no relabel to MT)',
      (tester) async {
        await _pump(
          tester,
          FakeCommoditiesRepository(),
          lot: _lot(unit: 'KG', unitId: _offlineKgId),
        );
        // An edited lot opens collapsed (UX-05); expand Commodity & Pricing.
        await tester.tap(find.byKey(const Key('post_section_header_0')));
        await tester.pumpAndSettle();

        expect(_selectedUnit(tester)?.symbol, 'KG');
        expect(_text(tester, 'quantity_field'), '2500.0');
        expect(_text(tester, 'asking_price_field'), '23.5');
        expect(find.text('Asking Price (₹ per KG) *'), findsOneWidget);
      },
    );

    // RB-SELLER-POST-INTEGRITY-02: edit flow with a reversed availability
    // window shows the field error and is not submitted.
    testWidgets('reversed dates on an edited lot show the error and block listing', (
      tester,
    ) async {
      final repo = FakeCommoditiesRepository();
      final reversed = SellerCommodity(
        id: 'lot-dates',
        lotNumber: 'LOT-DATES-1',
        commodityName: 'Wheat Bran',
        gradeName: 'FAQ (Fair Average Quality)',
        totalQuantity: 25,
        availableQuantity: 25,
        unit: 'MT',
        askingPrice: 22500,
        stateName: 'Rajasthan',
        districtName: 'Bikaner',
        status: 'Open',
        availableFrom: DateTime(2026, 11, 20),
        validUntil: DateTime(2026, 11, 10),
        commodityId: wheatBranId,
        gradeId: wheatBranFaqId,
        createdAt: DateTime(2026, 10, 20),
      );
      await _pump(tester, repo, lot: reversed);

      await tester.ensureVisible(find.byKey(const Key('review_and_list_button')));
      await tester.tap(find.byKey(const Key('review_and_list_button')));
      await tester.pumpAndSettle();

      // Commodity section + Additional Details opened on the date error.
      expect(find.byKey(const Key('valid_until_field')), findsOneWidget);
      expect(
        find.text('Valid Until must be on or after Available From'),
        findsWidgets,
      );
      expect(find.byKey(const Key('confirm_list_button')), findsNothing);
      expect(repo.submitted, isEmpty);
    });

    for (final (label, qty, price) in [
      ('missing quantity', '', '22500'),
      ('zero quantity', '0', '22500'),
      ('nonnumeric quantity', 'abc', '22500'),
      ('missing price', '25', ''),
      ('negative price', '25', '-1'),
      ('nonnumeric price', '25', 'x'),
    ]) {
      testWidgets('$label blocks submission', (tester) async {
        final repo = FakeCommoditiesRepository();
        await _pump(tester, repo);
        await _pickWheatBran(tester);
        await _submitWith(tester, qty: qty, price: price);
        expect(repo.submitted, isEmpty);
      });
    }

    testWidgets(
      'valid entry submits the typed values in the selected unit; a failed save shows no success',
      (tester) async {
        final repo = FakeCommoditiesRepository();
        await _pump(tester, repo);
        await _pickWheatBran(tester);
        await _submitWith(tester, qty: '25', price: '22500');

        expect(repo.submitted, hasLength(1));
        final dto = repo.submitted.single;
        expect(dto.totalQuantity, 25);
        expect(dto.askingPrice, 22500);
        expect(dto.unitSymbol, 'MT');
        // The fake repository rejects the save: the form must report failure, not success.
        // Unexpected errors show the friendly message, never the raw exception.
        expect(find.textContaining('Unable to publish your commodity'), findsOneWidget);
        expect(find.textContaining('captured by test'), findsNothing);
        expect(find.textContaining('listed successfully'), findsNothing);
      },
    );
  });
}
