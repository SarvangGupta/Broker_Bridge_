import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('RB-SELLER-02: CommoditiesRepository Unit Tests', () {
    late SecureStorageService storage;
    late CommoditiesRepository repository;

    setUp(() async {
      storage = SecureStorageService();
      storage.enableMemoryFallbackForTesting();
      await storage.saveUserInfo(
        id: '20000000-0000-0000-0000-000000000001',
        role: 'seller',
        email: 'seller@demo.com',
        fullName: 'Bikaner Agro Lead',
        companyId: '20000000-0000-0000-0000-000000000101',
      );
      repository = CommoditiesRepository(storage: storage);
      CommoditiesRepository.clearSessionCache();
    });

    test('getMasterCommodities fails loudly without a backend (no stale fallback list)', () async {
      await expectLater(repository.getMasterCommodities(), throwsStateError);
    });

    test('getMasterGrades never invents a grade', () async {
      await expectLater(repository.getMasterGrades('any-id'), throwsStateError);
    });

    test('createCommodity successfully creates and stores lot listing with broker and extended fields', () async {
      final dto = CreateCommodityDto(
        commodityId: '10000000-0000-0000-0000-000000000001',
        commodityName: 'Yellow Soybean',
        gradeId: '20000000-0000-0000-0000-000000000001',
        gradeName: 'Grade A FAQ',
        lotNumber: 'LOT-TEST-SOY-01',
        totalQuantity: 120.0,
        unitId: '30000000-0000-0000-0000-000000000001',
        unitSymbol: 'MT',
        askingPrice: 4950.0,
        confidentialMinimumPrice: 4850.0,
        stateId: '40000000-0000-0000-0000-000000000001',
        stateName: 'Rajasthan',
        districtId: '50000000-0000-0000-0000-000000000001',
        districtName: 'Bikaner Mandi Hub',
        loadingStatus: 'Ready to Load',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
        brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        brokerName: 'Bikaner Mandi Broker Desk',
        brokerPhone: '+919829012345',
        paymentTerms: 'Payment on Delivery (CAD)',
        officeLocation: 'Bikaner Commercial Head Office',
        labReportNumber: 'AGMARK-RAL-2026-9021',
      );

      final result = await repository.createCommodity(dto);
      expect(result.lotNumber, 'LOT-TEST-SOY-01');
      expect(result.commodityName, 'Yellow Soybean');
      expect(result.totalQuantity, 120.0);
      expect(result.availableQuantity, 120.0);
      expect(result.askingPrice, 4950.0);
      expect(result.status, 'Open');
      expect(result.brokerId, 'b354958e-779a-41f2-b7a3-5899eca32e32');
      expect(result.brokerPhone, '+919829012345');
      expect(result.paymentTerms, 'Payment on Delivery (CAD)');
      expect(result.officeLocation, 'Bikaner Commercial Head Office');

      // Check it surfaces in getCommodities
      final list = await repository.getCommodities();
      expect(list.any((c) => c.lotNumber == 'LOT-TEST-SOY-01'), isTrue);

      // Check getCommodityById returns the persisted lot
      final fetched = await repository.getCommodityById(result.id);
      expect(fetched, isNotNull);
      expect(fetched!.lotNumber, 'LOT-TEST-SOY-01');
      expect(fetched.brokerName, 'Bikaner Mandi Broker Desk');
    });

    test(
      'updateCommodityStatus updates listing status and notifies listeners',
      () async {
        final dto = CreateCommodityDto(
          commodityId: '10000000-0000-0000-0000-000000000001',
          commodityName: 'Yellow Soybean',
          gradeId: '20000000-0000-0000-0000-000000000001',
          gradeName: 'Grade A FAQ',
          lotNumber: 'LOT-STATUS-01',
          totalQuantity: 80.0,
          unitId: '30000000-0000-0000-0000-000000000001',
          unitSymbol: 'MT',
          askingPrice: 5000.0,
          stateId: '40000000-0000-0000-0000-000000000001',
          stateName: 'Rajasthan',
          districtId: '50000000-0000-0000-0000-000000000001',
          districtName: 'Bikaner Mandi Hub',
          availableFrom: DateTime.now(),
          validUntil: DateTime.now().add(const Duration(days: 7)),
        );

        final created = await repository.createCommodity(dto);
        expect(created.status, 'Open');

        // Now returns the server-confirmed status (RB-SELLER-POST-INTEGRITY-02).
        final saved = await repository.updateCommodityStatus(
          created.id,
          'Cancelled',
        );
        expect(saved, 'Cancelled');

        final updated = await repository.getCommodityById(created.id);
        expect(updated?.status, 'Cancelled');
      },
    );

    test('updateCommodityPrice updates listing asking price', () async {
      final dto = CreateCommodityDto(
        commodityId: '10000000-0000-0000-0000-000000000001',
        commodityName: 'Yellow Soybean',
        gradeId: '20000000-0000-0000-0000-000000000001',
        gradeName: 'Grade A FAQ',
        lotNumber: 'LOT-PRICE-01',
        totalQuantity: 100.0,
        unitId: '30000000-0000-0000-0000-000000000001',
        unitSymbol: 'MT',
        askingPrice: 5000.0,
        stateId: '40000000-0000-0000-0000-000000000001',
        stateName: 'Rajasthan',
        districtId: '50000000-0000-0000-0000-000000000001',
        districtName: 'Bikaner Mandi Hub',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
      );

      final created = await repository.createCommodity(dto);
      expect(created.askingPrice, 5000.0);

      final notified = CommoditiesRepository.commoditiesUpdatedNotifier.value;
      final saved = await repository.updateCommodityPrice(created.id, 5250.0);
      expect(saved, 5250.0);
      expect(
        CommoditiesRepository.commoditiesUpdatedNotifier.value,
        notified + 1,
      );

      final updated = await repository.getCommodityById(created.id);
      expect(updated?.askingPrice, 5250.0);

      // A second update wins everywhere the list is read.
      expect(await repository.updateCommodityPrice(created.id, 5400.0), 5400.0);
      expect((await repository.getCommodityById(created.id))?.askingPrice, 5400.0);
    });

    // RB-SELLER-PRICE-SYNC-FIX-01
    test('price update of an unsaved (sample) lot fails without notifying', () async {
      final notified = CommoditiesRepository.commoditiesUpdatedNotifier.value;
      final sample = (await repository.getCommodities()).first;

      await expectLater(
        repository.updateCommodityPrice(sample.id, sample.askingPrice + 100),
        throwsA(isA<PriceUpdateException>()),
      );
      expect(CommoditiesRepository.commoditiesUpdatedNotifier.value, notified);
      expect(
        (await repository.getCommodityById(sample.id))?.askingPrice,
        sample.askingPrice,
      );
    });

    test('with a backend, a non-server lot id is rejected before any request', () async {
      final online = CommoditiesRepository(
        client: SupabaseClient('http://localhost:54321', 'test-anon-key'),
        storage: storage,
      );
      await expectLater(
        online.updateCommodityPrice('AVL-2026-001', 6000),
        throwsA(isA<PriceUpdateException>()),
      );
    });

    test('a failed request is reported, not treated as success', () async {
      // Nothing listens on this port: the request fails.
      final online = CommoditiesRepository(
        client: SupabaseClient('http://127.0.0.1:9', 'test-anon-key'),
        storage: storage,
      );
      await expectLater(
        online.updateCommodityPrice(
          '11111111-1111-4111-8111-111111111111',
          6000,
        ),
        throwsA(isA<PriceUpdateException>()),
      );
    });

    // RB-SELLER-AVAILABILITY-RLS-FIX-01
    test('with a backend but no session, listing is refused with a safe message', () async {
      final online = CommoditiesRepository(
        client: SupabaseClient('http://127.0.0.1:9', 'test-anon-key'),
        storage: storage,
      );
      final dto = CreateCommodityDto(
        commodityId: '10000000-0000-0000-0000-000000000001',
        commodityName: 'Yellow Soybean',
        gradeId: '20000000-0000-0000-0000-000000000001',
        gradeName: 'Grade A FAQ',
        lotNumber: 'LOT-NOSESSION',
        totalQuantity: 10.0,
        unitId: '30000000-0000-0000-0000-000000000001',
        unitSymbol: 'MT',
        askingPrice: 100.0,
        stateId: '40000000-0000-0000-0000-000000000001',
        stateName: 'Rajasthan',
        districtId: '50000000-0000-0000-0000-000000000001',
        districtName: 'Bikaner Mandi Hub',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
      );
      await expectLater(
        online.createCommodity(dto),
        throwsA(
          isA<ListingSubmitException>().having(
            (e) => e.message,
            'message',
            contains('session has expired'),
          ),
        ),
      );
      // Nothing is cached as if it had been listed.
      expect(
        (await repository.getCommodities()).any((c) => c.lotNumber == 'LOT-NOSESSION'),
        isFalse,
      );
    });

    test('price update rejects a non-positive price', () async {
      await expectLater(
        repository.updateCommodityPrice('any', 0),
        throwsA(isA<PriceUpdateException>()),
      );
    });

    test('updating one lot never changes another lot', () async {
      CreateCommodityDto dto(String lot, double price) => CreateCommodityDto(
        commodityId: '10000000-0000-0000-0000-000000000001',
        commodityName: 'Yellow Soybean',
        gradeId: '20000000-0000-0000-0000-000000000001',
        gradeName: 'Grade A FAQ',
        lotNumber: lot,
        totalQuantity: 10.0,
        unitId: '30000000-0000-0000-0000-000000000001',
        unitSymbol: 'MT',
        askingPrice: price,
        stateId: '40000000-0000-0000-0000-000000000001',
        stateName: 'Rajasthan',
        districtId: '50000000-0000-0000-0000-000000000001',
        districtName: 'Bikaner Mandi Hub',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
      );
      final a = await repository.createCommodity(dto('LOT-A', 1000));
      // createCommodity derives ids from the clock; keep them distinct.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final b = await repository.createCommodity(dto('LOT-B', 2000));
      expect(a.id, isNot(b.id));

      await repository.updateCommodityPrice(a.id, 1500);
      expect((await repository.getCommodityById(a.id))?.askingPrice, 1500);
      expect((await repository.getCommodityById(b.id))?.askingPrice, 2000);
    });

    test(
      'createCommodity rejects negative or zero quantity with ArgumentError',
      () async {
        final dto = CreateCommodityDto(
          commodityId: '10000000-0000-0000-0000-000000000001',
          commodityName: 'Yellow Soybean',
          gradeId: '20000000-0000-0000-0000-000000000001',
          gradeName: 'Grade A FAQ',
          lotNumber: 'LOT-INV-01',
          totalQuantity: 0.0,
          unitId: '30000000-0000-0000-0000-000000000001',
          unitSymbol: 'MT',
          askingPrice: 4950.0,
          stateId: '40000000-0000-0000-0000-000000000001',
          stateName: 'Rajasthan',
          districtId: '50000000-0000-0000-0000-000000000001',
          districtName: 'Bikaner Mandi Hub',
          availableFrom: DateTime.now(),
          validUntil: DateTime.now().add(const Duration(days: 7)),
        );

        expect(() => repository.createCommodity(dto), throwsArgumentError);
      },
    );

    test(
      'createCommodity rejects non-positive asking price with ArgumentError',
      () async {
        final dto = CreateCommodityDto(
          commodityId: '10000000-0000-0000-0000-000000000001',
          commodityName: 'Yellow Soybean',
          gradeId: '20000000-0000-0000-0000-000000000001',
          gradeName: 'Grade A FAQ',
          lotNumber: 'LOT-INV-02',
          totalQuantity: 50.0,
          unitId: '30000000-0000-0000-0000-000000000001',
          unitSymbol: 'MT',
          askingPrice: -100.0,
          stateId: '40000000-0000-0000-0000-000000000001',
          stateName: 'Rajasthan',
          districtId: '50000000-0000-0000-0000-000000000001',
          districtName: 'Bikaner Mandi Hub',
          availableFrom: DateTime.now(),
          validUntil: DateTime.now().add(const Duration(days: 7)),
        );

        expect(() => repository.createCommodity(dto), throwsArgumentError);
      },
    );
  });
}
