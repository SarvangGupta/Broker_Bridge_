import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/master_requirement_data.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/post_requirement_screen.dart';

import '../support/fake_requirements_repository.dart';

Widget _app(FakeRequirementsRepository repo, {String? initialCommodity}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: PostRequirementScreen(repository: repo, initialCommodity: initialCommodity),
    );

final _pickerField = find.byKey(const Key('commodity-picker-field'));

/// Default test width (800 dp; the Ahem test font is wider than real fonts) but tall
/// enough that the whole picker list is built without scrolling.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.ensureVisible(_pickerField);
  await tester.tap(_pickerField);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String commodityId) async {
  await _openPicker(tester);
  await tester.tap(find.byKey(Key('commodity-option-$commodityId')));
  await tester.pumpAndSettle();
}

/// Fills quantity and target price (the form has no defaults), then submits.
Future<void> _submit(WidgetTester tester) async {
  for (final (key, value) in [('requirement-quantity-field', '25'), ('requirement-price-field', '4850')]) {
    final field = find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));
    if (field.evaluate().isNotEmpty && tester.widget<TextField>(field).controller!.text.isEmpty) {
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }
  }
  final submit = find.text('Submit Procurement Requirement');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  group('RMBUYER-PRODUCT-PICKER-FIX-01: commodity picker', () {
    testWidgets('loads the catalogue from the repository and preselects nothing', (tester) async {
      final repo = FakeRequirementsRepository();
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(repo.commodityLoads, 1);
      expect(find.text('Tap to select a commodity'), findsOneWidget);
      expect(find.text('Dal'), findsNothing);
    });

    testWidgets('lists active Product Master products and excludes deactivated duplicates', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(_app(FakeRequirementsRepository()));
      await tester.pumpAndSettle();
      await _openPicker(tester);

      for (final id in [maizeId, wheatId, soybeanId, dalId, riceId]) {
        expect(find.byKey(Key('commodity-option-$id')), findsOneWidget);
      }
      expect(find.text('Yellow Maize (Corn)'), findsOneWidget);
      expect(find.text('Sharbati Wheat'), findsOneWidget);
      expect(find.text('Soybean Seed'), findsOneWidget);
      expect(find.byKey(const Key('commodity-option-$inactiveMaizeId')), findsNothing);
      expect(find.byKey(const Key('commodity-option-$inactiveWheatId')), findsNothing);
      expect(find.text('maize'), findsNothing);
      expect(find.text('Wheat'), findsNothing);
    });

    testWidgets('search filters by fetched product names', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(_app(FakeRequirementsRepository()));
      await tester.pumpAndSettle();
      await _openPicker(tester);

      await tester.enterText(
        find.descendant(of: find.byKey(const Key('commodity-picker-search')), matching: find.byType(TextField)),
        'soy',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('commodity-option-$soybeanId')), findsOneWidget);
      expect(find.byKey(const Key('commodity-option-$maizeId')), findsNothing);
      expect(find.byKey(const Key('commodity-option-$dalId')), findsNothing);

      await tester.enterText(
        find.descendant(of: find.byKey(const Key('commodity-picker-search')), matching: find.byType(TextField)),
        'groundnut',
      );
      await tester.pumpAndSettle();
      expect(find.text('No commodity matches "groundnut".'), findsOneWidget);
    });

    for (final entry in {
      maizeId: ('Yellow Maize (Corn)', '21000000-0000-0000-0000-000000000002'),
      wheatId: ('Sharbati Wheat', '21000000-0000-0000-0000-000000000003'),
      soybeanId: ('Soybean Seed', '21000000-0000-0000-0000-000000000004'),
    }.entries) {
      final (name, gradeId) = entry.value;
      testWidgets('selecting $name submits its product ID ${entry.key}', (tester) async {
        final repo = FakeRequirementsRepository();
        _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
        await tester.pumpAndSettle();

        await _pick(tester, entry.key);
        expect(
          find.descendant(of: _pickerField, matching: find.text(name)),
          findsOneWidget,
        );

        await _submit(tester);

        expect(repo.submitted, hasLength(1));
        final dto = repo.submitted.single;
        expect(dto.commodityId, entry.key);
        expect(dto.commodityName, name);
        expect(dto.gradeId, gradeId);
        final payload = dto.toSupabaseInsert('30000000-0000-0000-0000-000000000101');
        expect(payload['commodity_id'], entry.key);
        expect(payload['grade_id'], gradeId);
        expect(find.text('Requirement Created'), findsOneWidget);
      });
    }

    testWidgets('submitting without a selection is blocked (no silent Dal default)', (tester) async {
      final repo = FakeRequirementsRepository();
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _submit(tester);

      expect(repo.submitted, isEmpty);
      expect(find.text('Please select a commodity.'), findsOneWidget);
    });

    testWidgets('changing commodity replaces the grade with one from the new product', (tester) async {
      final repo = FakeRequirementsRepository();
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _pick(tester, maizeId);
      await _pick(tester, wheatId);
      await _submit(tester);

      final dto = repo.submitted.single;
      expect(dto.commodityId, wheatId);
      expect(dto.gradeId, '21000000-0000-0000-0000-000000000003');
    });

    testWidgets('request failure shows an error with retry and no stale list', (tester) async {
      final repo = FakeRequirementsRepository(commodityError: Exception('network down'));
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('commodity-load-error')), findsOneWidget);
      expect(_pickerField, findsNothing);
      expect(find.text('Mustard Seeds'), findsNothing);

      await _submit(tester);
      expect(repo.submitted, isEmpty);

      repo.commodityError = null;
      await tester.ensureVisible(find.byKey(const Key('commodity-retry')));
      await tester.tap(find.byKey(const Key('commodity-retry')));
      await tester.pumpAndSettle();

      expect(repo.commodityLoads, 2);
      expect(find.byKey(const Key('commodity-load-error')), findsNothing);
      expect(_pickerField, findsOneWidget);
    });

    testWidgets('shows loading state while the catalogue request is in flight', (tester) async {
      final gate = Completer<void>();
      final repo = FakeRequirementsRepository()..commodityGate = gate.future;
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
      // Spinners never settle; pump enough for the other master data to resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byKey(const Key('commodity-loading')), findsOneWidget);
      expect(_pickerField, findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('commodity-loading')), findsNothing);
      expect(_pickerField, findsOneWidget);
    });

    testWidgets('empty catalogue shows an empty state with refresh', (tester) async {
      final repo = FakeRequirementsRepository(rows: const []);
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('commodity-empty')), findsOneWidget);
      expect(find.text('No active commodities are available in the catalogue.'), findsOneWidget);
    });

    testWidgets('picker refresh fetches the current catalogue', (tester) async {
      final repo = FakeRequirementsRepository(
        rows: productMasterRows.where((r) => r['id'] != soybeanId).toList(),
      );
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await _openPicker(tester);
      expect(find.byKey(const Key('commodity-option-$soybeanId')), findsNothing);

      repo.rows = productMasterRows;
      await tester.tap(find.byKey(const Key('commodity-picker-refresh')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('commodity-option-$soybeanId')), findsOneWidget);
    });

    testWidgets('PM-07: search "Soybean DOC" shows its category, and the label follows the selection', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(_app(FakeRequirementsRepository()));
      await tester.pumpAndSettle();
      await _openPicker(tester);

      await tester.enterText(
        find.descendant(of: find.byKey(const Key('commodity-picker-search')), matching: find.byType(TextField)),
        'soybean doc',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('commodity-option-$soybeanDocId')), findsOneWidget);
      expect(find.text('Category: Oil Cakes & Oil Meals'), findsOneWidget);
      expect(find.byKey(const Key('commodity-option-$soybeanId')), findsNothing);

      await tester.tap(find.byKey(const Key('commodity-option-$soybeanDocId')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _pickerField, matching: find.text('Category: Oil Cakes & Oil Meals')), findsOneWidget);

      await _pick(tester, maizeId);
      expect(find.descendant(of: _pickerField, matching: find.text('Category: Grains & Energy Ingredients')), findsOneWidget);
      expect(find.text('Category: Oil Cakes & Oil Meals'), findsNothing);
    });

    testWidgets('PM-07: product without a grade explains and blocks submission', (tester) async {
      final repo = FakeRequirementsRepository();
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _pick(tester, soybeanDocId);
      expect(find.byKey(const Key('no-grade-notice')), findsOneWidget);

      await _submit(tester);
      expect(repo.submitted, isEmpty);
      expect(find.textContaining('No grade is defined for Soybean DOC'), findsWidgets);
    });

    for (final (label, gradeId) in [('Good', maizeDdgsGoodId), ('Average', maizeDdgsAverageId)]) {
      testWidgets('GRADE-01: Maize DDGS offers Good/Average and posts with "$label"', (tester) async {
        final repo = FakeRequirementsRepository();
        _tallPhone(tester);
        await tester.pumpWidget(_app(repo));
        await tester.pumpAndSettle();

        await _pick(tester, maizeDdgsId);
        expect(find.byKey(const Key('no-grade-notice')), findsNothing);
        expect(
          find.descendant(of: _pickerField, matching: find.text('Category: Distillery & Fermentation By-products')),
          findsOneWidget,
        );

        await tester.tap(find.byType(DropdownButton<MasterGrade>));
        await tester.pumpAndSettle();
        expect(find.text('Good').hitTestable(), findsWidgets);
        expect(find.text('Average').hitTestable(), findsWidgets);
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();

        await _submit(tester);
        expect(repo.submitted, hasLength(1));
        expect(repo.submitted.single.commodityId, maizeDdgsId);
        expect(repo.submitted.single.gradeId, gradeId);
        expect(repo.submitted.single.gradeName, label);
        expect(find.textContaining('No grade is defined'), findsNothing);
        expect(find.text('Requirement Created'), findsOneWidget);
      });
    }

    testWidgets('PM-07: missing category association shows "Category unavailable"', (tester) async {
      final repo = FakeRequirementsRepository(rows: [
        {'id': maizeId, 'name': 'Yellow Maize (Corn)', 'code': 'MAIZE-01', 'status': true, 'category_id': null},
      ]);
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await _pick(tester, maizeId);
      expect(find.descendant(of: _pickerField, matching: find.text('Category unavailable')), findsOneWidget);
    });

    testWidgets('initial commodity from a route preselects the matching live product', (tester) async {
      final repo = FakeRequirementsRepository();
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo, initialCommodity: 'Yellow Maize'));
      await tester.pumpAndSettle();

      expect(find.descendant(of: _pickerField, matching: find.text('Yellow Maize (Corn)')), findsOneWidget);
    });

    testWidgets('ambiguous route commodity ("Maize" → Yellow Maize, Maize DDGS) preselects nothing', (tester) async {
      final repo = FakeRequirementsRepository();
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo, initialCommodity: 'Maize'));
      await tester.pumpAndSettle();

      expect(find.text('Tap to select a commodity'), findsOneWidget);
      expect(find.descendant(of: _pickerField, matching: find.text('Maize DDGS')), findsNothing);
    });

    testWidgets('unmatched initial commodity selects nothing and explains why', (tester) async {
      final repo = FakeRequirementsRepository();
      _tallPhone(tester);
      await tester.pumpWidget(_app(repo, initialCommodity: 'Mustard Seeds'));
      await tester.pumpAndSettle();

      expect(find.text('Tap to select a commodity'), findsOneWidget);
      expect(find.textContaining('"Mustard Seeds" is not in the current catalogue'), findsOneWidget);
    });
  });

  group('matchInitialCommodity', () {
    const catalogue = [
      MasterCommodity(id: dalId, name: 'Dal', code: ''),
      MasterCommodity(id: wheatId, name: 'Sharbati Wheat', code: 'WHEAT-01'),
      MasterCommodity(id: soybeanId, name: 'Soybean Seed', code: 'SOY-01'),
      MasterCommodity(id: maizeId, name: 'Yellow Maize (Corn)', code: 'MAIZE-01'),
    ];

    MasterCommodity? match(String? q) =>
        PostRequirementScreen.matchInitialCommodity(catalogue, q);

    test('exact and partial names resolve to the live product', () {
      expect(match('Sharbati Wheat')?.id, wheatId);
      expect(match('wheat')?.id, wheatId);
      expect(match('Yellow Maize')?.id, maizeId);
      expect(match('Soybean')?.id, soybeanId);
    });

    test('ambiguous partial match returns null instead of the first hit', () {
      final withDdgs = [...catalogue, const MasterCommodity(id: maizeDdgsId, name: 'Maize DDGS', code: '')];
      expect(PostRequirementScreen.matchInitialCommodity(withDdgs, 'maize'), isNull);
      expect(PostRequirementScreen.matchInitialCommodity(withDdgs, 'Maize DDGS')?.id, maizeDdgsId);
    });

    test('no match never falls back to the first product', () {
      expect(match('Soyabean'), isNull);
      expect(match('Chana (Gram)'), isNull);
      expect(match(''), isNull);
      expect(match(null), isNull);
    });
  });
}
