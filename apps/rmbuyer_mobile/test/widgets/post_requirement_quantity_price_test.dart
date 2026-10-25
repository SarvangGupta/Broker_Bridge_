import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/master_requirement_data.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/post_requirement_screen.dart';

import '../support/fake_requirements_repository.dart';

// Live `master_units` in natural row order (read-only snapshot 2026-10-25): kg first.
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
const _liveOrder = [_kg, _tonn, _metricTon, _qtl];

final _quantity = find.descendant(
  of: find.byKey(const Key('requirement-quantity-field')),
  matching: find.byType(TextField),
);
final _price = find.descendant(
  of: find.byKey(const Key('requirement-price-field')),
  matching: find.byType(TextField),
);

Future<FakeRequirementsRepository> _pump(
  WidgetTester tester, {
  List<MasterUnit> units = _liveOrder,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final repo = FakeRequirementsRepository()..units = units;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PostRequirementScreen(
        repository: repo,
        initialCommodity: 'Yellow Maize (Corn)',
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

String _text(WidgetTester tester, Finder f) =>
    tester.widget<TextField>(f).controller!.text;

MasterUnit? _selectedUnit(WidgetTester tester) => tester
    .widget<DropdownButton<MasterUnit>>(find.byType(DropdownButton<MasterUnit>))
    .value;

Future<void> _fillAndSubmit(
  WidgetTester tester, {
  String? qty,
  String? price,
  bool settle = true,
}) async {
  if (qty != null) await tester.enterText(_quantity, qty);
  if (price != null) await tester.enterText(_price, price);
  final submit = find.text('Submit Procurement Requirement');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  if (settle) await tester.pumpAndSettle();
}

void main() {
  group('RMBUYER-SELLER-QUANTITY-PRICE-01: rules', () {
    test('default unit is the "Metric Ton" MT row, not the first (kg) row', () {
      expect(PostRequirementScreen.defaultUnit(_liveOrder), _metricTon);
      expect(PostRequirementScreen.defaultUnit([_kg, _tonn, _qtl]), _tonn);
      expect(PostRequirementScreen.defaultUnit([_kg, _qtl]), isNull);
    });

    test('quantity: required, numeric, finite, greater than zero', () {
      expect(PostRequirementScreen.validateQuantity('  '), isNotNull);
      for (final bad in ['0', '-5', 'abc', '1e999', 'NaN']) {
        expect(
          PostRequirementScreen.validateQuantity(bad),
          isNotNull,
          reason: bad,
        );
      }
      expect(PostRequirementScreen.validateQuantity('25.5'), isNull);
    });

    test('price: required, numeric, finite, not negative (zero stays allowed as before)', () {
      expect(
        PostRequirementScreen.validatePrice(''),
        'Please enter your target price.',
      );
      for (final bad in ['-1', 'x', '1e999']) {
        expect(
          PostRequirementScreen.validatePrice(bad),
          isNotNull,
          reason: bad,
        );
      }
      expect(PostRequirementScreen.validatePrice('0'), isNull);
      expect(PostRequirementScreen.validatePrice('4850.50'), isNull);
    });
  });

  group('RMBUYER-SELLER-QUANTITY-PRICE-01: form', () {
    testWidgets(
      'new requirement: quantity and price empty, MT preselected with live unit order',
      (tester) async {
        await _pump(tester);
        expect(_text(tester, _quantity), isEmpty);
        expect(_text(tester, _price), isEmpty);
        expect(_selectedUnit(tester), _metricTon);
        expect(find.text('Target Price (₹/MT) *'), findsOneWidget);
        expect(find.text('50'), findsNothing);
        expect(find.text('4800'), findsNothing);
      },
    );

    for (final (label, qty, price) in [
      ('empty quantity', null, '4850'),
      ('zero quantity', '0', '4850'),
      ('nonnumeric quantity', 'abc', '4850'),
      ('non-finite quantity', '1e999', '4850'),
      ('empty price', '25', null),
      ('negative price', '25', '-1'),
      ('nonnumeric price', '25', 'x'),
    ]) {
      testWidgets('$label is rejected and nothing is submitted', (
        tester,
      ) async {
        final repo = await _pump(tester);
        await _fillAndSubmit(tester, qty: qty, price: price);
        expect(repo.submitted, isEmpty);
        expect(find.text('Requirement Created'), findsNothing);
      });
    }

    testWidgets('empty fields show field-level messages', (tester) async {
      await _pump(tester);
      await _fillAndSubmit(tester);
      expect(find.text('Please enter the required quantity.'), findsWidgets);
      expect(find.text('Please enter your target price.'), findsOneWidget);
    });

    testWidgets(
      'valid entry submits the typed values in the selected unit, unconverted',
      (tester) async {
        final repo = await _pump(tester);
        await _fillAndSubmit(tester, qty: '25.5', price: '4850.50');
        expect(repo.submitted, hasLength(1));
        final dto = repo.submitted.single;
        expect(dto.quantity, 25.5);
        expect(dto.targetPrice, 4850.50);
        expect(dto.unitId, _metricTon.id);
        expect(dto.unitSymbol, 'MT');
        final payload = dto.toSupabaseInsert(
          '30000000-0000-0000-0000-000000000101',
        );
        expect(payload['quantity'], 25.5);
        expect(payload['target_price'], 4850.50);
        expect(payload['unit_id'], _metricTon.id);
        expect(find.text('Requirement Created'), findsOneWidget);
      },
    );

    testWidgets('an explicit ₹0 target price is accepted (existing rule)', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await _fillAndSubmit(tester, qty: '10', price: '0');
      expect(repo.submitted.single.targetPrice, 0);
    });

    testWidgets(
      'with no MT unit available, nothing is preselected and submit asks for a unit',
      (tester) async {
        final repo = await _pump(tester, units: const [_kg, _qtl]);
        expect(_selectedUnit(tester), isNull);
        await _fillAndSubmit(tester, qty: '10', price: '100');
        expect(repo.submitted, isEmpty);
        expect(find.text('Please select a quantity unit.'), findsOneWidget);
      },
    );

    testWidgets(
      'failed submission keeps the typed values and shows no success',
      (tester) async {
        final repo = await _pump(tester);
        repo.submitError = Exception(
          'Failed to save requirement to server: RLS',
        );
        await _fillAndSubmit(tester, qty: '12', price: '5100');
        expect(find.text('Requirement Created'), findsNothing);
        expect(
          find.textContaining('Failed to save requirement to server'),
          findsOneWidget,
        );
        expect(_text(tester, _quantity), '12');
        expect(_text(tester, _price), '5100');
      },
    );

    testWidgets('rapid repeated taps submit once', (tester) async {
      final gate = Completer<void>();
      final repo = await _pump(tester);
      repo.submitGate = gate.future;
      await _fillAndSubmit(tester, qty: '12', price: '5100', settle: false);
      await tester.pump();
      final submit = find.text('Submit Procurement Requirement');
      if (submit.evaluate().isNotEmpty) {
        await tester.tap(submit, warnIfMissed: false);
      }
      await tester.pump();
      expect(repo.submitted, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
    });
  });
}
