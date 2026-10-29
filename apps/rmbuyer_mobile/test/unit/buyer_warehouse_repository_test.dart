import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/profile/data/warehouse_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/company_warehouse.dart';

class FakeWarehouseDataSource implements WarehouseDataSource {
  final Map<String, CompanyWarehouse> _store = {};
  bool shouldFail = false;

  FakeWarehouseDataSource([List<CompanyWarehouse>? seed]) {
    if (seed != null) {
      for (final w in seed) {
        _store[w.id] = w;
      }
    }
  }

  @override
  Future<List<CompanyWarehouse>> listFor(String companyId) async {
    if (shouldFail) throw Exception('Database error');
    return _store.values.where((w) => w.companyId == companyId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<CompanyWarehouse> upsert(CompanyWarehouse warehouse, String userId) async {
    if (shouldFail) throw Exception('Database write error');
    final id = warehouse.id.isEmpty ? 'wh-${_store.length + 1}' : warehouse.id;
    final saved = warehouse.copyWith(
      id: id,
      createdBy: warehouse.createdBy.isEmpty ? userId : warehouse.createdBy,
      updatedAt: DateTime.now(),
    );
    _store[id] = saved;
    return saved;
  }

  @override
  Future<void> toggleActive(String warehouseId, bool isActive) async {
    if (shouldFail) throw Exception('Database write error');
    final current = _store[warehouseId];
    if (current != null) {
      _store[warehouseId] = current.copyWith(isActive: isActive, updatedAt: DateTime.now());
    }
  }

  @override
  Future<void> delete(String warehouseId) async {
    if (shouldFail) throw Exception('Database delete error');
    _store.remove(warehouseId);
  }
}

void main() {
  group('CompanyWarehouse domain and validation', () {
    test('serializes to and from row correctly including GPS fields', () {
      final now = DateTime.utc(2026, 10, 29, 12, 0, 0);
      final capturedAt = DateTime.utc(2026, 10, 29, 11, 45, 0);
      final wh = CompanyWarehouse(
        id: 'wh-001',
        companyId: 'comp-100',
        createdBy: 'user-200',
        name: 'Depot A',
        addressLine: '12 Industrial Area, Gate 4',
        stateId: 'RJ',
        districtId: 'Kota',
        pinCode: '324005',
        contactPerson: 'Ramesh',
        contactPhone: '+919876543210',
        unloadingNotes: 'Forklift on site',
        isActive: true,
        latitude: 25.1825,
        longitude: 75.8398,
        gpsAccuracy: 4.8,
        locationCapturedAt: capturedAt,
        createdAt: now,
        updatedAt: now,
      );

      final map = wh.toMap();
      expect(map['id'], 'wh-001');
      expect(map['company_id'], 'comp-100');
      expect(map['name'], 'Depot A');
      expect(map['address_line'], '12 Industrial Area, Gate 4');
      expect(map['pin_code'], '324005');
      expect(map['contact_person'], 'Ramesh');
      expect(map['is_active'], isTrue);
      expect(map['latitude'], 25.1825);
      expect(map['longitude'], 75.8398);
      expect(map['gps_accuracy'], 4.8);
      expect(map['location_captured_at'], capturedAt.toIso8601String());

      final restored = CompanyWarehouse.fromRow({
        ...map,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      expect(restored.id, wh.id);
      expect(restored.name, wh.name);
      expect(restored.addressLine, wh.addressLine);
      expect(restored.pinCode, wh.pinCode);
      expect(restored.contactPerson, wh.contactPerson);
      expect(restored.isActive, isTrue);
      expect(restored.latitude, 25.1825);
      expect(restored.longitude, 75.8398);
      expect(restored.gpsAccuracy, 4.8);
      expect(restored.locationCapturedAt, capturedAt);
      expect(restored.hasGpsCoordinates, isTrue);
      expect(
        restored.googleMapsUrl,
        'https://www.google.com/maps/search/?api=1&query=25.1825%2C75.8398',
      );
    });

    test('validates coordinate boundaries and rejects invalid coordinates', () {
      expect(WarehouseValidation.isValidCoordinate(28.6139, 77.2090), isTrue);
      expect(WarehouseValidation.isValidCoordinate(-90.0, 180.0), isTrue);
      expect(WarehouseValidation.isValidCoordinate(90.0, -180.0), isTrue);

      // Null coordinate
      expect(WarehouseValidation.isValidCoordinate(null, 77.2090), isFalse);
      expect(WarehouseValidation.isValidCoordinate(28.6139, null), isFalse);

      // Out of bounds
      expect(WarehouseValidation.isValidCoordinate(90.0001, 77.2), isFalse);
      expect(WarehouseValidation.isValidCoordinate(-90.0001, 77.2), isFalse);
      expect(WarehouseValidation.isValidCoordinate(28.6, 180.0001), isFalse);
      expect(WarehouseValidation.isValidCoordinate(28.6, -180.0001), isFalse);

      // NaN and Infinity
      expect(WarehouseValidation.isValidCoordinate(double.nan, 77.2), isFalse);
      expect(WarehouseValidation.isValidCoordinate(28.6, double.infinity), isFalse);

      // Null island (0.0, 0.0) rejection
      expect(WarehouseValidation.isValidCoordinate(0.0, 0.0), isFalse);
      expect(WarehouseValidation.isValidCoordinate(0.00000001, 0.00000001), isFalse);
    });

    test('buildGoogleMapsUrl encodes coordinates and never fabricates URLs without coords', () {
      const lat = 26.9124;
      const lng = 75.7873;
      final url = WarehouseValidation.buildGoogleMapsUrl(lat, lng);
      expect(url, 'https://www.google.com/maps/search/?api=1&query=26.9124%2C75.7873');

      // Missing or invalid coordinates produce null
      expect(WarehouseValidation.buildGoogleMapsUrl(null, null), isNull);
      expect(WarehouseValidation.buildGoogleMapsUrl(lat, null), isNull);
      expect(WarehouseValidation.buildGoogleMapsUrl(null, lng), isNull);
      expect(WarehouseValidation.buildGoogleMapsUrl(95.0, lng), isNull);
      expect(WarehouseValidation.buildGoogleMapsUrl(0.0, 0.0), isNull);
    });

    test('validates required warehouse name', () {
      expect(WarehouseValidation.validateName(''), isNotNull);
      expect(WarehouseValidation.validateName('  '), isNotNull);
      expect(WarehouseValidation.validateName('A'), isNotNull); // < 2 chars
      expect(WarehouseValidation.validateName('Central Godown'), isNull);
    });

    test('validates full street address', () {
      expect(WarehouseValidation.validateAddress(''), isNotNull);
      expect(WarehouseValidation.validateAddress('Pl'), isNotNull); // < 5 chars
      expect(
        WarehouseValidation.validateAddress('Plot 42, Mandi Phase 1'),
        isNull,
      );
    });

    test('validates 6-digit PIN code', () {
      expect(WarehouseValidation.validatePinCode(null), isNull);
      expect(WarehouseValidation.validatePinCode(''), isNull);
      expect(WarehouseValidation.validatePinCode('12345'), isNotNull);
      expect(WarehouseValidation.validatePinCode('023456'), isNotNull); // Leading 0 invalid
      expect(WarehouseValidation.validatePinCode('324005'), isNull);
    });

    test('validates 10-digit phone number', () {
      expect(WarehouseValidation.validatePhone(null), isNull);
      expect(WarehouseValidation.validatePhone(''), isNull);
      expect(WarehouseValidation.validatePhone('12345'), isNotNull);
      expect(WarehouseValidation.validatePhone('9876543210'), isNull);
      expect(WarehouseValidation.validatePhone('+919876543210'), isNull);
      expect(WarehouseValidation.validatePhone('09876543210'), isNull);
    });
  });

  group('WarehouseRepository', () {
    late FakeWarehouseDataSource fakeSource;
    late WarehouseRepository repo;

    setUp(() {
      fakeSource = FakeWarehouseDataSource([
        CompanyWarehouse(
          id: 'wh-1',
          companyId: 'comp-1',
          createdBy: 'user-1',
          name: 'Main Silo',
          addressLine: 'Mandi Road',
          latitude: 25.1825,
          longitude: 75.8398,
          gpsAccuracy: 5.2,
          locationCapturedAt: DateTime.utc(2026, 10, 29, 10, 0),
          isActive: true,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        CompanyWarehouse(
          id: 'wh-2',
          companyId: 'comp-1',
          createdBy: 'user-1',
          name: 'Secondary Yard',
          addressLine: 'Sector 4',
          isActive: false,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        CompanyWarehouse(
          id: 'wh-other',
          companyId: 'comp-other',
          createdBy: 'user-2',
          name: 'Other Company Yard',
          addressLine: 'Different Area',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      repo = WarehouseRepository(source: fakeSource);
    });

    test('lists warehouses strictly for the company (tenant isolation)', () async {
      final list = await repo.getWarehouses('comp-1');
      expect(list.length, 2);
      expect(list.map((w) => w.id), containsAll(['wh-1', 'wh-2']));
      expect(list.map((w) => w.id), isNot(contains('wh-other')));
    });

    test('persists and reloads GPS coordinates correctly', () async {
      final newWh = CompanyWarehouse(
        id: '',
        companyId: 'comp-1',
        createdBy: '',
        name: 'GPS Grain Depot',
        addressLine: 'Highway Hub 9',
        pinCode: '302001',
        latitude: 26.8521,
        longitude: 75.8052,
        gpsAccuracy: 3.5,
        locationCapturedAt: DateTime.utc(2026, 10, 29, 12, 30),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await repo.saveWarehouse(newWh, userId: 'user-1');
      expect(saved.id, isNotEmpty);
      expect(saved.hasGpsCoordinates, isTrue);
      expect(saved.latitude, 26.8521);
      expect(saved.longitude, 75.8052);
      expect(saved.gpsAccuracy, 3.5);

      final reloaded = await repo.getWarehouses('comp-1');
      final fetched = reloaded.firstWhere((w) => w.id == saved.id);
      expect(fetched.latitude, 26.8521);
      expect(fetched.longitude, 75.8052);
      expect(
        fetched.googleMapsUrl,
        'https://www.google.com/maps/search/?api=1&query=26.8521%2C75.8052',
      );
    });

    test('existing address-only warehouses without GPS continue to work', () async {
      final all = await repo.getWarehouses('comp-1');
      final wh2 = all.firstWhere((w) => w.id == 'wh-2');
      expect(wh2.hasGpsCoordinates, isFalse);
      expect(wh2.latitude, isNull);
      expect(wh2.longitude, isNull);
      expect(wh2.googleMapsUrl, isNull);
      expect(wh2.addressLine, 'Sector 4');
    });

    test('edits existing warehouse and preserves unrelated locations', () async {
      final initial = (await repo.getWarehouses('comp-1')).firstWhere((w) => w.id == 'wh-1');
      final updated = initial.copyWith(name: 'Renamed Main Silo #1');

      final saved = await repo.saveWarehouse(updated, userId: 'user-1');
      expect(saved.name, 'Renamed Main Silo #1');
      expect(saved.latitude, initial.latitude); // Coords preserved

      final all = await repo.getWarehouses('comp-1');
      final wh1 = all.firstWhere((w) => w.id == 'wh-1');
      final wh2 = all.firstWhere((w) => w.id == 'wh-2');
      expect(wh1.name, 'Renamed Main Silo #1');
      expect(wh2.name, 'Secondary Yard'); // Unrelated warehouse untouched
    });

    test('toggles active state', () async {
      await repo.toggleActive('wh-1', false);
      final all = await repo.getWarehouses('comp-1');
      final wh1 = all.firstWhere((w) => w.id == 'wh-1');
      expect(wh1.isActive, isFalse);

      await repo.toggleActive('wh-1', true);
      final all2 = await repo.getWarehouses('comp-1');
      final wh1Active = all2.firstWhere((w) => w.id == 'wh-1');
      expect(wh1Active.isActive, isTrue);
    });

    test('deletes warehouse location', () async {
      await repo.deleteWarehouse('wh-1');
      final all = await repo.getWarehouses('comp-1');
      expect(all.length, 1);
      expect(all.first.id, 'wh-2');
    });

    test('throws StateError when user is not signed in', () async {
      final newWh = CompanyWarehouse(
        id: '',
        companyId: 'comp-1',
        createdBy: '',
        name: 'Godown',
        addressLine: 'Address Line',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(() => repo.saveWarehouse(newWh, userId: null), throwsStateError);
    });
  });
}
