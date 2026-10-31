import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/widgets/home_add_sheet.dart';
import 'package:rmbroker_mobile/features/work/data/saved_locations_repository.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/domain/saved_location_model.dart';
import 'package:rmbroker_mobile/features/work/domain/trade_master_data.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/change_location_sheet.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/create_offer_sheet.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/create_requirement_sheet.dart';

const _master = TradeMasterData(
  buyerCompanies: [
    MasterDropdownItem(id: 'b1', name: 'Buyer One'),
    MasterDropdownItem(id: 'b2', name: 'Buyer Two'),
    MasterDropdownItem(id: 'b3', name: 'Buyer None'),
  ],
  sellerCompanies: [
    MasterDropdownItem(id: 's1', name: 'Seller One'),
    MasterDropdownItem(id: 's2', name: 'Seller None'),
    MasterDropdownItem(id: 's3', name: 'Seller Bad'),
  ],
  commodities: [
    MasterDropdownItem(id: 'c-maize', name: 'Maize', categoryName: 'Grains'),
  ],
  grades: [MasterDropdownItem(id: 'g-maize', name: 'FAQ', parentId: 'c-maize')],
  units: [
    MasterDropdownItem(id: 'u-mt', name: 'Metric Ton', extra: 'MT'),
    MasterDropdownItem(id: 'u-qtl', name: 'Quintal', extra: 'Qtl'),
  ],
  states: [MasterDropdownItem(id: 'st-rj', name: 'Rajasthan')],
  districts: [MasterDropdownItem(id: 'd-kota', name: 'Kota', parentId: 'st-rj')],
);

SavedLocation _loc(String id, String company, String name, {bool primary = false, String? city = 'd-kota', String? state = 'st-rj'}) =>
    SavedLocation(id: id, companyId: company, name: name, address: '$name Road', city: city, state: state, isPrimary: primary);

class _Locations extends SavedLocationsRepository {
  bool fail = false;
  final Map<String, List<SavedLocation>> data = {
    'b1': [_loc('w1', 'b1', 'First Yard'), _loc('w2', 'b1', 'Default Yard', primary: true)],
    'b2': [_loc('w3', 'b2', 'Only Yard'), _loc('w4', 'b2', 'Later Yard')],
    's1': [_loc('w5', 's1', 'Kota Godown')],
    's3': [_loc('w6', 's3', 'Bad Godown', city: null)],
  };

  String? addedTo;
  String? updatedId;

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required String companyId,
    required String name,
    required String addressLine,
    required String stateId,
    required String districtId,
    required String pinCode,
  }) async {
    updatedId = id;
    final saved = SavedLocation(id: id, companyId: companyId, name: name, address: addressLine, addressLine: addressLine, city: districtId, state: stateId, pinCode: pinCode);
    data[companyId] = [for (final l in data[companyId]!) if (l.id == id) saved else l];
    return saved;
  }

  @override
  Future<SavedLocation> addLocation({
    required String companyId,
    required String name,
    required String addressLine,
    required String stateId,
    required String districtId,
    String? pinCode,
  }) async {
    addedTo = companyId;
    final saved = SavedLocation(id: 'w-new', companyId: companyId, name: name, address: addressLine, city: districtId, state: stateId);
    data[companyId] = [...?data[companyId], saved];
    return saved;
  }

  @override
  Future<List<SavedLocation>> getSavedLocations(String companyId) async {
    if (fail) throw const SavedLocationsUnavailable('Saved locations could not be loaded. Please try again.');
    return data[companyId] ?? const [];
  }
}

class _Repo extends WorkRepository {
  TradeMasterData master = _master;
  Completer<void>? masterGate;
  Completer<void>? saveGate;
  Completer<void>? listGate;
  WorkDataResult<String> saveResult = const WorkSuccess('new-id');
  CreateRequirementDto? requirement;
  CreateOfferDto? offer;
  int saves = 0;
  int listLoads = 0;

  @override
  Future<WorkDataResult<TradeMasterData>> getMasterData() async {
    await masterGate?.future;
    return WorkSuccess(master);
  }

  @override
  Future<WorkDataResult<String>> createRequirement(CreateRequirementDto dto) async {
    saves++;
    requirement = dto;
    await saveGate?.future;
    return saveResult;
  }

  @override
  Future<WorkDataResult<String>> createOffer(CreateOfferDto dto) async {
    saves++;
    offer = dto;
    await saveGate?.future;
    return saveResult;
  }

  @override
  Future<WorkDataResult<List<RequirementItem>>> getRequirements() async {
    listLoads++;
    await listGate?.future;
    return const WorkSuccess([]);
  }

  @override
  Future<WorkDataResult<List<OfferItem>>> getOffers() async {
    listLoads++;
    await listGate?.future;
    return const WorkSuccess([]);
  }
}

const _fab = Key('fab');
const _reqItem = ValueKey('home_add_requirement');
const _offerItem = ValueKey('home_add_offer');
const _saveReq = Key('save_requirement_button');
const _saveOffer = Key('save_offer_button');

Future<void> _pumpHome(WidgetTester tester, _Repo repo, {_Locations? locations, Size size = const Size(800, 2000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workRepositoryProvider.overrideWithValue(repo),
        savedLocationsRepositoryProvider.overrideWithValue(locations ?? _Locations()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (_) => Align(
              alignment: Alignment.bottomRight,
              child: Builder(
                builder: (context) => SizedBox(
                  width: 56,
                  height: 56,
                  child: ElevatedButton(key: _fab, onPressed: () => HomeAddSheet.show(context), child: const Text('+')),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openForm(WidgetTester tester, Key item) async {
  await tester.tap(find.byKey(_fab));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(item));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, Finder dropdown, String option) async {
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Finder get _party => find.byType(DropdownButtonFormField<String>).first;

Future<void> _pickDate(WidgetTester tester, Key field) async {
  await tester.ensureVisible(find.byKey(field));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _pickProduct(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('commodity-picker-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('commodity-option-c-maize')));
  await tester.pumpAndSettle();
}

Future<void> _fillRequirement(WidgetTester tester, {String buyer = 'Buyer One'}) async {
  await _choose(tester, _party, buyer);
  await _pickProduct(tester);
  await tester.enterText(find.byKey(const Key('requirement_quantity_field')), '50');
  await tester.enterText(find.byKey(const Key('requirement_price_field')), '4800');
  await _pickDate(tester, const Key('requirement_date_field'));
}

Future<void> _fillOffer(WidgetTester tester, {String seller = 'Seller One'}) async {
  await _choose(tester, _party, seller);
  await _pickProduct(tester);
  await tester.enterText(find.byKey(const Key('offer_quantity_field')), '100');
  await tester.enterText(find.byKey(const Key('offer_price_field')), '5200');
  await _choose(tester, find.byKey(const Key('offer_ready_dropdown')), 'Within 3 Days');
  await _pickDate(tester, const Key('offer_valid_until_field'));
}

Future<void> _save(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  group('Home + menu', () {
    testWidgets('each option opens its own form, repeatedly, leaving nothing blocking', (tester) async {
      await _pumpHome(tester, _Repo());
      for (var i = 0; i < 3; i++) {
        await _openForm(tester, _reqItem);
        expect(find.byType(CreateRequirementSheet), findsOneWidget);
        expect(find.byType(CreateOfferSheet), findsNothing);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        await _openForm(tester, _offerItem);
        expect(find.byType(CreateOfferSheet), findsOneWidget);
        expect(find.byType(CreateRequirementSheet), findsNothing);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('duplicate taps open one menu and one form', (tester) async {
      await _pumpHome(tester, _Repo());
      final button = tester.widget<ElevatedButton>(find.byKey(_fab));
      button.onPressed!();
      button.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(HomeAddSheet), findsOneWidget);
      expect(find.byKey(_reqItem), findsOneWidget);
      await tester.tap(find.byKey(_reqItem));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(_reqItem), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(CreateRequirementSheet), findsOneWidget);
    });

    testWidgets('rapid open and dismiss leaves nothing blocking', (tester) async {
      await _pumpHome(tester, _Repo());
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(_fab));
        // A pushed page route is offstage for its first frame.
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tapAt(const Offset(5, 5));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pumpAndSettle();
        expect(find.byType(HomeAddSheet), findsNothing);
      }
    });

    testWidgets('close button, backdrop and system back each close the menu; the close button sits over +', (tester) async {
      await _pumpHome(tester, _Repo());
      final fabCenter = tester.getCenter(find.byKey(_fab));

      await tester.tap(find.byKey(_fab));
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.byKey(const ValueKey('home_add_close'))), fabCenter);
      expect(tester.getBottomRight(find.byKey(_offerItem)).dy, lessThan(fabCenter.dy));
      expect(tester.getBottomRight(find.byKey(_reqItem)).dy, lessThan(tester.getTopRight(find.byKey(_offerItem)).dy));
      expect(tester.getSize(find.byKey(_offerItem)).height, greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const ValueKey('home_add_close')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeAddSheet), findsNothing);

      await tester.tap(find.byKey(_fab));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(HomeAddSheet), findsNothing);

      await tester.tap(find.byKey(_fab));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeAddSheet), findsNothing);
      expect(find.byType(CreateRequirementSheet), findsNothing);
    });

    testWidgets('menu fits narrow screens without overflow', (tester) async {
      await _pumpHome(tester, _Repo(), size: const Size(320, 568));
      await tester.tap(find.byKey(_fab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.byKey(_reqItem)).dx, greaterThanOrEqualTo(0));
    });
  });

  group('Snapshot structure', () {
    testWidgets('requirement sections and labels; no hardcoded defaults', (tester) async {
      await _pumpHome(tester, _Repo());
      await _openForm(tester, _reqItem);
      for (final text in ['Buyer & Product', 'Quantity & Price', 'Delivery (Unloading)', 'Buyer *', 'Commodity *', 'Grade *',
          'Quantity *', 'Unit *', 'Unload at *', 'Required by *', 'View', 'Add notes (Optional)']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Enter quantity'), findsOneWidget);
      expect(find.text('Enter price'), findsOneWidget);
    });

    testWidgets('offer sections and labels; no hardcoded defaults', (tester) async {
      await _pumpHome(tester, _Repo());
      await _openForm(tester, _offerItem);
      for (final text in ['Seller & Product', 'Quantity & Price', 'Stock & Dispatch (Loading)', 'Additional (Optional)',
          'Seller *', 'Price visibility *', 'Load from *', 'Ready in *', 'Valid until *', 'Lab report', 'Notes']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Enter quantity'), findsOneWidget);
    });

    testWidgets('both forms fit a small phone, with a location selected', (tester) async {
      await _pumpHome(tester, _Repo(), size: const Size(360, 640));
      await _openForm(tester, _offerItem);
      await _choose(tester, _party, 'Seller One');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await _openForm(tester, _reqItem);
      await _choose(tester, _party, 'Buyer One');
      expect(tester.takeException(), isNull);
    });
  });

  group('Automatic locations', () {
    testWidgets('buyer: uses the default, else the first valid; switching refreshes', (tester) async {
      await _pumpHome(tester, _Repo());
      await _openForm(tester, _reqItem);
      await _choose(tester, _party, 'Buyer One');
      expect(find.text('Default Yard'), findsOneWidget);
      expect(find.text('Default Yard Road'), findsOneWidget);
      await _choose(tester, _party, 'Buyer Two');
      expect(find.text('Only Yard'), findsOneWidget);
      expect(find.text('Default Yard'), findsNothing);
      await _choose(tester, _party, 'Buyer None');
      expect(find.text('Only Yard'), findsNothing);
      expect(find.textContaining('has no saved location'), findsOneWidget);
    });

    testWidgets('seller: selection loads the location; switching never keeps the old one', (tester) async {
      await _pumpHome(tester, _Repo());
      await _openForm(tester, _offerItem);
      await _choose(tester, _party, 'Seller One');
      expect(find.text('Kota Godown'), findsOneWidget);
      await _choose(tester, _party, 'Seller None');
      expect(find.text('Kota Godown'), findsNothing);
      expect(find.textContaining('has no saved location'), findsOneWidget);
    });

    testWidgets('Change picks another location of the same counterparty, and it is saved', (tester) async {
      final repo = _Repo();
      final locations = _Locations();
      await _pumpHome(tester, repo, locations: locations);
      await _openForm(tester, _reqItem);
      await _fillRequirement(tester, buyer: 'Buyer Two');
      await tester.tap(find.byKey(const Key('change_delivery_location_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(ChangeLocationSheet), findsOneWidget);
      expect(find.text('Default Yard'), findsNothing);
      await tester.tap(find.text('Later Yard'));
      await tester.pumpAndSettle();

      await _save(tester, _saveReq);
      expect(repo.requirement!.locationId, 'w4');
      expect(repo.requirement!.locationSnapshot, contains('Later Yard'));
      expect(locations.data['b2']!.first.isPrimary, isFalse, reason: 'saved address data untouched');
    });

    testWidgets('missing location blocks saving and invents no address', (tester) async {
      final repo = _Repo();
      await _pumpHome(tester, repo);
      await _openForm(tester, _reqItem);
      await _fillRequirement(tester, buyer: 'Buyer None');
      await _save(tester, _saveReq);
      expect(find.text('Please select an unload location'), findsOneWidget);
      expect(repo.saves, 0);
    });

    testWidgets('broker adds a location for the counterparty; its id is saved', (tester) async {
      final repo = _Repo();
      final locations = _Locations();
      await _pumpHome(tester, repo, locations: locations);
      await _openForm(tester, _offerItem);
      await _fillOffer(tester, seller: 'Seller None');
      await tester.ensureVisible(find.byKey(const Key('no_location_add_btn')));
      await tester.tap(find.byKey(const Key('no_location_add_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_location_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('new_location_save')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a location name'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('new_location_name')), 'New Yard');
      await tester.enterText(find.byKey(const Key('new_location_address')), 'Mandi Road');
      await _choose(tester, find.byKey(const Key('new_location_state')), 'Rajasthan');
      await _choose(tester, find.byKey(const ValueKey('new_location_district_st-rj')), 'Kota');
      await tester.enterText(find.byKey(const Key('new_location_pin')), '324005');
      await tester.tap(find.byKey(const Key('new_location_save')));
      await tester.pumpAndSettle();

      expect(locations.addedTo, 's2');
      expect(find.text('New Yard'), findsOneWidget);
      await _save(tester, _saveOffer);
      expect(repo.offer!.locationId, 'w-new');
      expect(repo.offer!.districtId, 'd-kota');
    });

    testWidgets('editing a location updates that record, keeps one row, and selects it', (tester) async {
      final repo = _Repo();
      final locations = _Locations();
      await _pumpHome(tester, repo, locations: locations);
      await _openForm(tester, _offerItem);
      await _fillOffer(tester);
      await tester.tap(find.byKey(const Key('change_loading_location_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit_location_w5')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('new_location_name')), 'Kota Godown 2');
      await tester.enterText(find.byKey(const Key('new_location_pin')), '324005');
      await tester.tap(find.byKey(const Key('new_location_save')));
      await tester.pumpAndSettle();

      expect(locations.updatedId, 'w5');
      expect(locations.data['s1'], hasLength(1));
      expect(find.text('Kota Godown 2'), findsOneWidget);
      await _save(tester, _saveOffer);
      expect(repo.offer!.locationId, 'w5');
      expect(repo.offer!.locationSnapshot, contains('Kota Godown 2'));
      expect(repo.offer!.locationSnapshot, contains('Rajasthan'));
    });

    testWidgets('a location load failure is shown with Retry', (tester) async {
      final locations = _Locations()..fail = true;
      await _pumpHome(tester, _Repo(), locations: locations);
      await _openForm(tester, _offerItem);
      await _choose(tester, _party, 'Seller One');
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      locations.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Kota Godown'), findsOneWidget);
    });
  });

  group('Save', () {
    testWidgets('requirement carries counterparty, product, grade, unit, price and location id', (tester) async {
      final repo = _Repo();
      await _pumpHome(tester, repo);
      await _openForm(tester, _reqItem);
      await _fillRequirement(tester);
      await _choose(tester, find.byKey(const Key('requirement_unit_dropdown')), 'Quintal');
      await _save(tester, _saveReq);
      final dto = repo.requirement!;
      expect(dto.companyId, 'b1');
      expect(dto.commodityId, 'c-maize');
      expect(dto.gradeId, 'g-maize');
      expect(dto.quantity, 50);
      expect(dto.unitId, 'u-qtl');
      expect(dto.targetPrice, 4800);
      expect(dto.locationId, 'w2');
      expect(find.byType(CreateRequirementSheet), findsNothing);
      expect(repo.listLoads, greaterThan(1), reason: 'list refreshed');
    });

    testWidgets('offer carries location id, state and district from the location', (tester) async {
      final repo = _Repo();
      await _pumpHome(tester, repo);
      await _openForm(tester, _offerItem);
      await _fillOffer(tester);
      await _save(tester, _saveOffer);
      final dto = repo.offer!;
      expect(dto.companyId, 's1');
      expect(dto.locationId, 'w5');
      expect(dto.stateId, 'st-rj');
      expect(dto.districtId, 'd-kota');
    });

    testWidgets('offer refuses a location with no valid district', (tester) async {
      final repo = _Repo();
      await _pumpHome(tester, repo);
      await _openForm(tester, _offerItem);
      await _fillOffer(tester, seller: 'Seller Bad');
      await _save(tester, _saveOffer);
      expect(find.textContaining('has no valid state or district'), findsOneWidget);
      expect(repo.saves, 0);
    });

    testWidgets('save failure is reported, not success, and the form stays usable', (tester) async {
      final repo = _Repo()..saveResult = const WorkError(message: 'violates foreign key');
      await _pumpHome(tester, repo);
      await _openForm(tester, _reqItem);
      await _fillRequirement(tester);
      await _save(tester, _saveReq);
      expect(find.text('violates foreign key'), findsOneWidget);
      expect(find.textContaining('saved successfully'), findsNothing);
      expect(find.text('Save Requirement'), findsOneWidget);
    });

    testWidgets('a failed save keeps entered data; retry saves once with the same values', (tester) async {
      final repo = _Repo()..saveResult = const WorkError(message: 'The requirement could not be saved.');
      await _pumpHome(tester, repo);
      await _openForm(tester, _reqItem);
      await _fillRequirement(tester);
      await _save(tester, _saveReq);
      expect(find.text('The requirement could not be saved.'), findsOneWidget);
      expect(find.text('Default Yard'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('4800'), findsOneWidget);
      expect(repo.saves, 1);

      repo.saveResult = const WorkSuccess('new-id');
      await _save(tester, _saveReq);
      expect(repo.saves, 2, reason: 'one attempt per tap');
      expect(repo.requirement!.locationId, 'w2');
      expect(repo.requirement!.quantity, 50);
      expect(find.byType(CreateRequirementSheet), findsNothing);
      expect(find.textContaining('saved successfully'), findsOneWidget);
    });

    testWidgets('duplicate submit is ignored while saving; slow refresh does not hold the form', (tester) async {
      final repo = _Repo();
      await _pumpHome(tester, repo);
      await _openForm(tester, _offerItem);
      await _fillOffer(tester);
      repo.saveGate = Completer<void>();
      repo.listGate = Completer<void>();
      await tester.ensureVisible(find.byKey(_saveOffer));
      await tester.tap(find.byKey(_saveOffer));
      await tester.pump();
      await tester.tap(find.byKey(_saveOffer), warnIfMissed: false);
      await tester.pump();
      expect(repo.saves, 1);
      repo.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CreateOfferSheet), findsNothing);
      repo.listGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('sample lists cannot be saved; Retry loads live data', (tester) async {
      final repo = _Repo()..master = TradeMasterData.fallback();
      await _pumpHome(tester, repo);
      await _openForm(tester, _offerItem);
      expect(find.byKey(const Key('live-master-unavailable')), findsOneWidget);
      repo.master = _master;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-master-unavailable')), findsNothing);
    });
  });
}