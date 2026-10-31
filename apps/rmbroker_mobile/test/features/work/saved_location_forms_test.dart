import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/work/data/saved_locations_repository.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/trade_master_data.dart';

import '../../support/fake_postgrest.dart';

void main() {
  Map<String, dynamic> row(String id, String company, {bool active = true, bool? isDefault, String at = '2026-01-01'}) => {
        'id': id,
        'company_id': company,
        'name': 'Yard $id',
        'address_line': 'Road $id',
        'pin_code': '324005',
        'state_id': 'st',
        'district_id': 'd',
        'is_active': active,
        'created_at': at,
        if (isDefault != null) 'is_default': isDefault,
      };

  test('editing updates the same record, persists on re-read, creates no duplicate', () async {
    final fake = await FakePostgrest.start({'company_warehouses': [row('w1', 'c1')]});
    addTearDown(fake.close);
    final repo = SavedLocationsRepository(client: fake.client);
    final saved = await repo.updateLocation(
      id: 'w1', companyId: 'c1', name: 'Edited', addressLine: 'New Road',
      stateId: 'st', districtId: 'd', pinCode: '302001',
    );
    expect(saved.id, 'w1');
    final reread = await repo.getSavedLocations('c1');
    expect(reread.map((l) => l.id), ['w1']);
    expect(reread.single.name, 'Edited');
    expect(reread.single.address, 'New Road - 302001');
  });

  test('an edit that changes no row (RLS) fails instead of reporting success', () async {
    final fake = await FakePostgrest.start({'company_warehouses': [row('w1', 'other-company')]});
    addTearDown(fake.close);
    await expectLater(
      SavedLocationsRepository(client: fake.client).updateLocation(
        id: 'w1', companyId: 'c1', name: 'X', addressLine: 'Y', stateId: 's', districtId: 'd', pinCode: '302001',
      ),
      throwsA(isA<SavedLocationsUnavailable>()),
    );
    expect(fake.tables['company_warehouses']!.single['name'], 'Yard w1');
  });

  test('deal terms copy both locations; a legacy offer keeps its text without notes', () {
    final terms = DealRepository.createdLocationTerms(
      {'delivery_location_id': 'w1'},
      {'loading_location_id': 'w2', 'loading_location_snapshot': 'Godown, Kota', 'loading_remarks': 'old'},
    );
    expect(terms, {'unloadingLocationId': 'w1', 'loadingLocationId': 'w2', 'loadingLocationSnapshot': 'Godown, Kota'});
    expect(
      DealRepository.createdLocationTerms({}, {'loading_remarks': 'Old Godown | Notes: bagged'})['loadingLocationSnapshot'],
      'Old Godown',
    );
  });

  test('a transaction snapshot resolves ids to names', () {
    const master = TradeMasterData(
      buyerCompanies: [], sellerCompanies: [], commodities: [], grades: [], units: [],
      states: [MasterDropdownItem(id: 'st', name: 'Rajasthan')],
      districts: [MasterDropdownItem(id: 'd', name: 'Kota')],
    );
    expect(master.locationSnapshot(name: 'Yard', address: 'Road - 324005', city: 'd', state: 'st'), 'Yard, Road - 324005, Kota, Rajasthan');
  });

  group('SavedLocationsRepository reads company_warehouses', () {
    test('returns only this company\'s active rows, read-only, oldest first', () async {
      final fake = await FakePostgrest.start({
        'company_warehouses': [
          row('w2', 'c1', at: '2026-02-01'),
          row('w1', 'c1', at: '2026-01-01'),
          row('w3', 'c1', active: false),
          row('w4', 'c2'),
        ],
      });
      addTearDown(fake.close);
      final list = await SavedLocationsRepository(client: fake.client).getSavedLocations('c1');
      expect(list.map((l) => l.id), ['w1', 'w2']);
      expect(list.first.address, 'Road w1 - 324005');
      expect(fake.writes(), isEmpty);
    });

    test('default wins, otherwise the first valid; none gives null', () async {
      final fake = await FakePostgrest.start({
        'company_warehouses': [
          row('w1', 'c1', isDefault: false, at: '2026-01-01'),
          row('w2', 'c1', isDefault: true, at: '2026-02-01'),
          row('w3', 'c2', at: '2026-01-01'),
        ],
      });
      addTearDown(fake.close);
      final repo = SavedLocationsRepository(client: fake.client);
      expect((await repo.getDefaultLocation('c1'))!.id, 'w2');
      expect((await repo.getDefaultLocation('c2'))!.id, 'w3');
      expect(await repo.getDefaultLocation('c3'), isNull);
    });

    test('a backend failure is an error, not "no locations"', () async {
      final fake = await FakePostgrest.start({'company_warehouses': []});
      addTearDown(fake.close);
      fake.failWith = (_) => (404, {'code': '42P01', 'message': 'relation does not exist'});
      expect(
        SavedLocationsRepository(client: fake.client).getSavedLocations('c1'),
        throwsA(isA<SavedLocationsUnavailable>()),
      );
    });
  });

  test('unitIdFor is stable when two units share a symbol', () {
    for (final units in const [
      [MasterDropdownItem(id: 'tonn', name: 'Tonn', extra: 'MT'), MasterDropdownItem(id: 'mt', name: 'Metric Ton', extra: 'MT')],
      [MasterDropdownItem(id: 'mt', name: 'Metric Ton', extra: 'MT'), MasterDropdownItem(id: 'tonn', name: 'Tonn', extra: 'MT')],
    ]) {
      final master = TradeMasterData(
        buyerCompanies: const [], sellerCompanies: const [], commodities: const [], grades: const [],
        units: units, states: const [], districts: const [],
      );
      expect(master.unitIdFor('MT'), 'mt');
    }
  });

  group('counterpartiesWithRole', () {
    final contacts = [
      {'companies': {'id': 'c2', 'name': 'Zeta'}, 'users': {'role': 'buyer'}},
      {'companies': {'id': 'c1', 'name': 'Alpha'}, 'users': {'role': 'Buyer'}},
      {'companies': {'id': 'c1', 'name': 'Alpha'}, 'users': {'role': 'buyer'}},
      {'companies': {'id': 'c3', 'name': 'Seller Co'}, 'users': {'role': 'seller'}},
      {'companies': null, 'users': {'role': 'buyer'}},
    ];

    test('keeps one entry per company of that role, A to Z', () {
      expect(WorkRepository.counterpartiesWithRole(contacts, 'buyer').map((c) => c.id), ['c1', 'c2']);
      expect(WorkRepository.counterpartiesWithRole(contacts, 'seller').map((c) => c.id), ['c3']);
    });
  });
}