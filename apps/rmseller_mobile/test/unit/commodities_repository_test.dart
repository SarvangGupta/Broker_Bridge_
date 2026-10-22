import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';

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

    test('getMasterCommodities returns verified catalog', () async {
      final commodities = await repository.getMasterCommodities();
      expect(commodities, isNotEmpty);
      expect(commodities.any((c) => c.name.contains('Soybean')), isTrue);
      expect(commodities.any((c) => c.name.contains('Chana')), isTrue);
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

        final success = await repository.updateCommodityStatus(
          created.id,
          'Cancelled',
        );
        expect(success, isTrue);

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

      final success = await repository.updateCommodityPrice(created.id, 5250.0);
      expect(success, isTrue);

      final updated = await repository.getCommodityById(created.id);
      expect(updated?.askingPrice, 5250.0);
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
