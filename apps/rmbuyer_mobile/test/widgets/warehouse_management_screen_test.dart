import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/profile/data/buyer_profile_repository.dart';
import 'package:rmbuyer_mobile/features/profile/data/device_location_service.dart';
import 'package:rmbuyer_mobile/features/profile/data/warehouse_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/buyer_profile.dart';
import 'package:rmbuyer_mobile/features/profile/domain/company_warehouse.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/warehouse_management_screen.dart';

import '../support/fake_buyer_profile_repository.dart';

class _FakeWarehouseSource implements WarehouseDataSource {
  final List<CompanyWarehouse> items;
  bool failNextSave = false;

  _FakeWarehouseSource(List<CompanyWarehouse> seed) : items = List.from(seed);

  @override
  Future<List<CompanyWarehouse>> listFor(String companyId) async {
    return items.where((w) => w.companyId == companyId).toList();
  }

  @override
  Future<CompanyWarehouse> upsert(CompanyWarehouse warehouse, String userId) async {
    if (failNextSave) throw Exception('Server write failed');
    final id = warehouse.id.isEmpty ? 'wh-${items.length + 1}' : warehouse.id;
    final saved = warehouse.copyWith(
      id: id,
      createdBy: warehouse.createdBy.isEmpty ? userId : warehouse.createdBy,
      updatedAt: DateTime.now(),
    );
    final idx = items.indexWhere((w) => w.id == id);
    if (idx != -1) {
      items[idx] = saved;
    } else {
      items.add(saved);
    }
    return saved;
  }

  @override
  Future<void> toggleActive(String warehouseId, bool isActive) async {
    final idx = items.indexWhere((w) => w.id == warehouseId);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(isActive: isActive);
    }
  }

  @override
  Future<void> delete(String warehouseId) async {
    items.removeWhere((w) => w.id == warehouseId);
  }
}

class FakeLocationProvider implements LocationProvider {
  DeviceLocationResult nextResult;
  bool appSettingsOpened = false;
  bool locationSettingsOpened = false;

  FakeLocationProvider({
    this.nextResult = const DeviceLocationResult(
      DeviceLocationStatus.ok,
      latitude: 26.9124,
      longitude: 75.7873,
      accuracyMeters: 5.5,
    ),
  });

  @override
  Future<DeviceLocationResult> getCurrentPosition({
    double maxAcceptableAccuracyMeters = WarehouseValidation.acceptableAccuracyThresholdMeters,
    bool allowPoorAccuracy = false,
  }) async {
    return nextResult;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened = true;
    return true;
  }
}

void main() {
  const profile = BuyerProfile(
    id: 'user-001',
    name: 'Rohan Gupta',
    role: 'buyer',
    companyId: 'comp-100',
    companyName: 'Apex Commodities',
    companyGst: '08AAAAA1111A1Z',
    companyVerified: true,
  );

  Widget makeTestWidget({
    required WarehouseRepository repo,
    BuyerProfileRepository? profiles,
    LocationProvider? locationProvider,
  }) {
    return MaterialApp(
      home: WarehouseManagementScreen(
        repository: repo,
        profileRepository: profiles ?? FakeBuyerProfileRepository(profile: profile),
        locationProvider: locationProvider,
      ),
    );
  }

  group('WarehouseManagementScreen', () {
    testWidgets('renders operational notice banner and empty state when 0 warehouses', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([]);
      final repo = WarehouseRepository(source: source);

      await tester.pumpWidget(makeTestWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Warehouses & Unloading'), findsOneWidget);
      expect(find.byKey(const Key('warehouse-info-banner')), findsOneWidget);
      expect(
        find.textContaining('separate from your registered GST address'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('warehouse-empty-state')), findsOneWidget);
      expect(find.byKey(const Key('warehouse-empty-add-button')), findsOneWidget);
    });

    testWidgets('renders list of warehouses with GPS badge and no-GPS fallback badge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([
        CompanyWarehouse(
          id: 'wh-1',
          companyId: 'comp-100',
          createdBy: 'user-001',
          name: 'Central Mill Depot',
          addressLine: 'Plot 4, Industrial Area',
          pinCode: '324005',
          contactPerson: 'Harish Kumar',
          contactPhone: '9876543210',
          unloadingNotes: 'Forklift available',
          latitude: 25.1825,
          longitude: 75.8398,
          gpsAccuracy: 4.8,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        CompanyWarehouse(
          id: 'wh-2',
          companyId: 'comp-100',
          createdBy: 'user-001',
          name: 'Old Mandi Yard',
          addressLine: 'Gate 2, Old Mandi',
          isActive: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      final repo = WarehouseRepository(source: source);

      await tester.pumpWidget(makeTestWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Saved Locations'), findsOneWidget);
      expect(find.text('2 locations'), findsOneWidget);

      expect(find.byKey(const Key('warehouse-card-wh-1')), findsOneWidget);
      expect(find.text('Central Mill Depot'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('PRIMARY UNLOADING POINT'), findsOneWidget);
      expect(find.text('Plot 4, Industrial Area, 324005'), findsOneWidget);
      expect(find.byKey(const Key('warehouse-gps-badge-wh-1')), findsOneWidget);
      expect(find.byKey(const Key('warehouse-map-preview-wh-1')), findsOneWidget);
      expect(find.byKey(const Key('warehouse-open-maps-wh-1')), findsWidgets);

      expect(find.byKey(const Key('warehouse-card-wh-2')), findsOneWidget);
      expect(find.text('Old Mandi Yard'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.byKey(const Key('warehouse-nogps-badge-wh-2')), findsOneWidget);
      expect(find.text('GPS not added'), findsOneWidget);
      expect(find.text('Add GPS to guide trucks to the exact gate.'), findsOneWidget);
      expect(find.byKey(const Key('warehouse-add-gps-wh-2')), findsOneWidget);
      expect(find.text('Add Location'), findsOneWidget);
      expect(find.textContaining('Brokers can receive the saved Google Maps link'), findsOneWidget);
    });

    testWidgets('toggles warehouse active/inactive status', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([
        CompanyWarehouse(
          id: 'wh-1',
          companyId: 'comp-100',
          createdBy: 'user-001',
          name: 'Godown 1',
          addressLine: 'Mandi Road',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      final repo = WarehouseRepository(source: source);

      await tester.pumpWidget(makeTestWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      await tester.tap(find.byKey(const Key('warehouse-toggle-wh-1')));
      await tester.pumpAndSettle();

      expect(find.text('Inactive'), findsOneWidget);
      expect(source.items.first.isActive, isFalse);
    });

    testWidgets('1. successful GPS capture records coordinates and accuracy', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([]);
      final repo = WarehouseRepository(source: source);
      final locationProvider = FakeLocationProvider(
        nextResult: const DeviceLocationResult(
          DeviceLocationStatus.ok,
          latitude: 26.9124,
          longitude: 75.7873,
          accuracyMeters: 4.2,
        ),
      );

      await tester.pumpWidget(makeTestWidget(
        repo: repo,
        locationProvider: locationProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('warehouse-add-fab')));
      await tester.pumpAndSettle();

      // Before capture: status not captured
      expect(find.byKey(const Key('warehouse-gps-status-none')), findsOneWidget);
      expect(find.byKey(const Key('warehouse-gps-capture-button')), findsOneWidget);

      // Tap Use Current GPS Location
      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.pumpAndSettle();

      // After capture: coordinates displayed
      expect(find.byKey(const Key('warehouse-gps-status-captured')), findsOneWidget);
      expect(find.byKey(const Key('warehouse-gps-lat-text')), findsOneWidget);
      expect(find.text('26.912400'), findsOneWidget);
      expect(find.byKey(const Key('warehouse-gps-lng-text')), findsOneWidget);
      expect(find.text('75.787300'), findsOneWidget);
      expect(find.text('Accuracy: ±4.2 m'), findsOneWidget);
      expect(find.byKey(const Key('warehouse-gps-preview-button')), findsOneWidget);
      expect(find.byKey(const Key('warehouse-gps-refresh-button')), findsOneWidget);

      // Enter required address and save
      await tester.enterText(
        find.byKey(const Key('warehouse-input-name')),
        'GPS Mandi Silo',
      );
      await tester.enterText(
        find.byKey(const Key('warehouse-input-address')),
        'Plot 18, Grain Market Road',
      );

      await tester.ensureVisible(find.byKey(const Key('warehouse-form-submit')));
      await tester.tap(find.byKey(const Key('warehouse-form-submit')));
      await tester.pumpAndSettle();

      expect(source.items.length, 1);
      final saved = source.items.first;
      expect(saved.hasGpsCoordinates, isTrue);
      expect(saved.latitude, 26.9124);
      expect(saved.longitude, 75.7873);
      expect(saved.gpsAccuracy, 4.2);
    });

    testWidgets('2. permission denied displays clear warning status', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([]);
      final repo = WarehouseRepository(source: source);
      final locationProvider = FakeLocationProvider(
        nextResult: const DeviceLocationResult(
          DeviceLocationStatus.permissionDenied,
        ),
      );

      await tester.pumpWidget(makeTestWidget(
        repo: repo,
        locationProvider: locationProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('warehouse-add-fab')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('warehouse-gps-status-denied')), findsOneWidget);
      expect(find.textContaining('Location permission was denied'), findsOneWidget);
    });

    testWidgets('2b. permission permanently denied offers link to App Settings', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([]);
      final repo = WarehouseRepository(source: source);
      final locationProvider = FakeLocationProvider(
        nextResult: const DeviceLocationResult(
          DeviceLocationStatus.permissionDeniedForever,
        ),
      );

      await tester.pumpWidget(makeTestWidget(
        repo: repo,
        locationProvider: locationProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('warehouse-add-fab')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('warehouse-gps-settings-button')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-settings-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-settings-button')));
      await tester.pumpAndSettle();

      expect(locationProvider.appSettingsOpened, isTrue);
    });

    testWidgets('3. GPS disabled offers link to Location Settings', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([]);
      final repo = WarehouseRepository(source: source);
      final locationProvider = FakeLocationProvider(
        nextResult: const DeviceLocationResult(
          DeviceLocationStatus.serviceDisabled,
        ),
      );

      await tester.pumpWidget(makeTestWidget(
        repo: repo,
        locationProvider: locationProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('warehouse-add-fab')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('warehouse-gps-loc-settings-button')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-loc-settings-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-loc-settings-button')));
      await tester.pumpAndSettle();

      expect(locationProvider.locationSettingsOpened, isTrue);
    });

    testWidgets('3b. GPS timeout displays retry guidance', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([]);
      final repo = WarehouseRepository(source: source);
      final locationProvider = FakeLocationProvider(
        nextResult: const DeviceLocationResult(
          DeviceLocationStatus.timeout,
        ),
      );

      await tester.pumpWidget(makeTestWidget(
        repo: repo,
        locationProvider: locationProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('warehouse-add-fab')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('GPS fix timed out'), findsOneWidget);
    });

    testWidgets('4. poor accuracy offers retry and optional accept anyway', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([]);
      final repo = WarehouseRepository(source: source);
      final locationProvider = FakeLocationProvider(
        nextResult: const DeviceLocationResult(
          DeviceLocationStatus.poorAccuracy,
          latitude: 26.9124,
          longitude: 75.7873,
          accuracyMeters: 140.0,
        ),
      );

      await tester.pumpWidget(makeTestWidget(
        repo: repo,
        locationProvider: locationProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('warehouse-add-fab')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-capture-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('warehouse-gps-retry-button')), findsOneWidget);
      expect(find.byKey(const Key('warehouse-gps-accept-poor-button')), findsOneWidget);
      expect(find.textContaining('GPS signal is weak (accuracy: ±140m)'), findsOneWidget);
    });

    testWidgets('6. GPS refresh failure preserves previously saved coordinates', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initial = CompanyWarehouse(
        id: 'wh-1',
        companyId: 'comp-100',
        createdBy: 'user-001',
        name: 'Preserved Depot',
        addressLine: 'Mandi Sector 1',
        latitude: 25.1825,
        longitude: 75.8398,
        gpsAccuracy: 3.5,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final source = _FakeWarehouseSource([initial]);
      final repo = WarehouseRepository(source: source);

      // Next GPS attempt will fail with serviceDisabled
      final locationProvider = FakeLocationProvider(
        nextResult: const DeviceLocationResult(
          DeviceLocationStatus.serviceDisabled,
        ),
      );

      await tester.pumpWidget(makeTestWidget(
        repo: repo,
        locationProvider: locationProvider,
      ));
      await tester.pumpAndSettle();

      // Edit initial warehouse
      await tester.tap(find.byKey(const Key('warehouse-edit-wh-1')));
      await tester.pumpAndSettle();

      expect(find.text('25.182500'), findsOneWidget);
      expect(find.text('75.839800'), findsOneWidget);

      // Tap refresh GPS
      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-refresh-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-refresh-button')));
      await tester.pumpAndSettle();

      // Error message shown, but coordinates NOT wiped
      expect(find.textContaining('Device GPS / Location Services are turned off'), findsOneWidget);
      expect(find.text('25.182500'), findsOneWidget);
      expect(find.text('75.839800'), findsOneWidget);
    });

    testWidgets('clear coordinates button removes captured GPS', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initial = CompanyWarehouse(
        id: 'wh-1',
        companyId: 'comp-100',
        createdBy: 'user-001',
        name: 'Depot To Clear',
        addressLine: 'Mandi Sector 1',
        latitude: 25.1825,
        longitude: 75.8398,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final source = _FakeWarehouseSource([initial]);
      final repo = WarehouseRepository(source: source);

      await tester.pumpWidget(makeTestWidget(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('warehouse-edit-wh-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('warehouse-gps-clear-button')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('warehouse-gps-clear-button')));
      await tester.tap(find.byKey(const Key('warehouse-gps-clear-button')));
      await tester.pumpAndSettle();

      // Cleared -> shows capture button and Location not captured status
      expect(find.byKey(const Key('warehouse-gps-status-none')), findsOneWidget);
      expect(find.byKey(const Key('warehouse-gps-capture-button')), findsOneWidget);
    });

    testWidgets('deletes warehouse location with confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initial = CompanyWarehouse(
        id: 'wh-del',
        companyId: 'comp-100',
        createdBy: 'user-001',
        name: 'Warehouse To Delete',
        addressLine: 'Mandi Outskirts',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final source = _FakeWarehouseSource([initial]);
      final repo = WarehouseRepository(source: source);

      await tester.pumpWidget(makeTestWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Warehouse To Delete'), findsOneWidget);

      // Open popup menu
      await tester.tap(find.byKey(const Key('warehouse-more-menu-wh-del')));
      await tester.pumpAndSettle();

      // Tap Delete
      expect(find.byKey(const Key('warehouse-delete-wh-del')), findsOneWidget);
      await tester.tap(find.byKey(const Key('warehouse-delete-wh-del')));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Delete Location?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to delete "Warehouse To Delete"?'), findsOneWidget);

      // Cancel keeps the warehouse
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Warehouse To Delete'), findsOneWidget);
      expect(source.items.length, 1);

      // Open popup again and confirm delete
      await tester.tap(find.byKey(const Key('warehouse-more-menu-wh-del')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('warehouse-delete-wh-del')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('warehouse-confirm-delete-button')));
      await tester.pumpAndSettle();

      // Warehouse is gone, shows empty state
      expect(find.text('Warehouse To Delete'), findsNothing);
      expect(source.items.isEmpty, isTrue);
      expect(find.byKey(const Key('warehouse-empty-state')), findsOneWidget);
    });

    testWidgets('tapping Add GPS button on card without GPS opens form with automatic GPS capture', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initial = CompanyWarehouse(
        id: 'wh-nogps',
        companyId: 'comp-100',
        createdBy: 'user-001',
        name: 'Kota Storage Point',
        addressLine: 'Industrial Area, Kota, Rajasthan',
        pinCode: '324005',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final source = _FakeWarehouseSource([initial]);
      final repo = WarehouseRepository(source: source);
      final locationProvider = FakeLocationProvider(
        nextResult: const DeviceLocationResult(
          DeviceLocationStatus.ok,
          latitude: 25.1800,
          longitude: 75.8300,
          accuracyMeters: 6.0,
        ),
      );

      await tester.pumpWidget(makeTestWidget(
        repo: repo,
        locationProvider: locationProvider,
      ));
      await tester.pumpAndSettle();

      // Tap Add GPS button on the card
      expect(find.byKey(const Key('warehouse-add-gps-wh-nogps')), findsOneWidget);
      await tester.tap(find.byKey(const Key('warehouse-add-gps-wh-nogps')));
      await tester.pumpAndSettle();

      // Form is open and GPS has been automatically captured
      expect(find.byKey(const Key('warehouse-gps-status-captured')), findsOneWidget);
      expect(find.text('25.180000'), findsOneWidget);
      expect(find.text('75.830000'), findsOneWidget);
    });

    testWidgets('primary unloading point badge appears on first active warehouse only', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeWarehouseSource([
        CompanyWarehouse(
          id: 'wh-1',
          companyId: 'comp-100',
          createdBy: 'user-001',
          name: 'Primary Site',
          addressLine: 'Road 1',
          isActive: true,
          latitude: 26.9,
          longitude: 75.7,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        CompanyWarehouse(
          id: 'wh-2',
          companyId: 'comp-100',
          createdBy: 'user-001',
          name: 'Secondary Site',
          addressLine: 'Road 2',
          isActive: true,
          latitude: 26.8,
          longitude: 75.6,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      final repo = WarehouseRepository(source: source);

      await tester.pumpWidget(makeTestWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('warehouse-primary-badge-wh-1')), findsOneWidget);
      expect(find.byKey(const Key('warehouse-primary-badge-wh-2')), findsNothing);
      expect(find.text('PRIMARY UNLOADING POINT'), findsOneWidget);
    });
  });
}
