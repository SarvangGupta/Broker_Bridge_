import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/commodities/domain/lot_location.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/commodities/presentation/lot_location_sheet.dart';

const _rj = MasterState(id: 'S-RJ', name: 'Rajasthan', code: 'RJ');
const _mp = MasterState(id: 'S-MP', name: 'Madhya Pradesh', code: 'MP');
const _districts = {
  'S-RJ': [MasterDistrict(id: 'D-BKN', stateId: 'S-RJ', name: 'Bikaner')],
  'S-MP': [MasterDistrict(id: 'D-IND', stateId: 'S-MP', name: 'Indore')],
};

Future<List<MasterDistrict>> _load(String stateId) async =>
    _districts[stateId] ?? const [];

/// Opens the sheet from a button and records what Save returns.
Future<List<LotLocation?>> _open(
  WidgetTester tester, {
  LotLocation initial = const LotLocation(
    warehouse: LotAddress(stateId: 'S-RJ', districtId: 'D-BKN'),
  ),
  GpsAddressLookup? gps,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final results = <LotLocation?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showLotLocationSheet(
                context: context,
                initial: initial,
                states: const [_rj, _mp],
                loadDistricts: _load,
                gpsLookup: gps,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

/// AppTextField renders its label above the field, so match the enclosing Column.
Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextFormField),
);

Finder _labels(String label) => find.text(label);

void main() {
  group('RB-SELLER-LOCATION-UX-01: Location form', () {
    testWidgets('shows three sections and no Mandi fields', (tester) async {
      await _open(tester);
      expect(find.text('Registered Warehouse / Storage Location'), findsOneWidget);
      expect(find.text('Actual Physical Loading / Dispatch Location'), findsOneWidget);
      expect(find.text('Enterprise Office Location (Registered HQ)'), findsOneWidget);
      expect(find.textContaining('Mandi'), findsNothing);
      expect(find.textContaining('APMC'), findsNothing);
    });

    testWidgets('loading and office default to shared, one address form',
        (tester) async {
      await _open(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byKey(const Key('loadingSameAsWarehouse'))).value,
        isTrue,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byKey(const Key('officeSameAsWarehouse'))).value,
        isTrue,
      );
      expect(_labels('Address *'), findsOneWidget);
    });

    testWidgets('unchecking loading opens its form without touching office',
        (tester) async {
      await _open(tester);
      final loadingBox = find.byKey(const Key('loadingSameAsWarehouse'));
      await tester.ensureVisible(loadingBox);
      await tester.tap(loadingBox);
      await tester.pumpAndSettle();
      expect(_labels('Address *'), findsNWidgets(2));
      expect(
        tester.widget<CheckboxListTile>(find.byKey(const Key('officeSameAsWarehouse'))).value,
        isTrue,
      );
    });

    testWidgets('save is blocked until warehouse address is entered, then returns shared',
        (tester) async {
      final results = await _open(tester);
      await tester.tap(find.text('Save Location'));
      await tester.pumpAndSettle();
      expect(find.text('Address is required'), findsOneWidget);
      expect(results, isEmpty);

      await tester.enterText(_field('Address *'), 'Plot 12, Ring Road');
      await tester.enterText(
        _field('Gate / shed / platform (optional)'),
        'Gate 2',
      );
      await tester.tap(find.text('Save Location'));
      await tester.pumpAndSettle();

      final saved = results.single!;
      expect(saved.warehouse.address, 'Plot 12, Ring Road');
      expect(saved.warehouse.districtId, 'D-BKN');
      expect(saved.loadingSameAsWarehouse, isTrue);
      expect(saved.loadingRemarksText, 'Same as registered warehouse · Gate 2');
      expect(saved.officeSameAsWarehouse, isTrue);
    });

    testWidgets('changing state clears an incompatible district', (tester) async {
      final results = await _open(
        tester,
        initial: const LotLocation(
          warehouse: LotAddress(
            address: 'Godown A',
            stateId: 'S-RJ',
            districtId: 'D-BKN',
          ),
        ),
      );
      await tester.tap(find.text('Rajasthan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Madhya Pradesh').last);
      await tester.pumpAndSettle();
      expect(find.text('Bikaner'), findsNothing);

      await tester.tap(find.text('Save Location'));
      await tester.pumpAndSettle();
      expect(find.text('Select a district'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('re-checking a distinct address asks before replacing it',
        (tester) async {
      final results = await _open(
        tester,
        initial: const LotLocation(
          warehouse: LotAddress(
            address: 'Godown A',
            stateId: 'S-RJ',
            districtId: 'D-BKN',
          ),
          officeSameAsWarehouse: false,
          office: LotAddress(
            address: 'MG Road',
            stateId: 'S-MP',
            districtName: 'Indore',
          ),
        ),
      );
      final officeBox = find.byKey(const Key('officeSameAsWarehouse'));
      await tester.ensureVisible(officeBox);
      await tester.tap(officeBox);
      await tester.pumpAndSettle();
      expect(find.text('Use warehouse address?'), findsOneWidget);
      await tester.tap(find.text('Keep separate'));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(officeBox).value, isFalse);

      await tester.tap(find.text('Save Location'));
      await tester.pumpAndSettle();
      final saved = results.single!;
      expect(saved.officeSameAsWarehouse, isFalse);
      expect(saved.office.address, 'MG Road');
      expect(saved.office.districtName, 'Indore');
    });

    testWidgets('GPS is disabled with a manual-entry note when no provider',
        (tester) async {
      await _open(tester);
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Use GPS Location'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('GPS is not available'), findsOneWidget);
    });

    testWidgets('certain GPS result fills address, state and district',
        (tester) async {
      final results = await _open(
        tester,
        initial: const LotLocation(),
        gps: () async => const GpsAddress(
          address: 'Choithram Mandi Road',
          stateId: 'S-MP',
          districtId: 'D-IND',
          pinCode: '452014',
          isCertain: true,
        ),
      );
      await tester.tap(find.text('Use GPS Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Location'));
      await tester.pumpAndSettle();
      final saved = results.single!;
      expect(saved.warehouse.stateId, 'S-MP');
      expect(saved.warehouse.districtId, 'D-IND');
      expect(saved.warehouse.pinCode, '452014');
    });

    testWidgets('fits a 320px-wide screen without overflow', (tester) async {
      await _open(tester, size: const Size(320, 640));
      final loadingBox = find.byKey(const Key('loadingSameAsWarehouse'));
      await tester.ensureVisible(loadingBox);
      await tester.tap(loadingBox);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Save Location'), findsOneWidget);
    });
  });
}
