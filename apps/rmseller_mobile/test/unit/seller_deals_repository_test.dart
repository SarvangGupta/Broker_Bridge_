import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/deals/data/seller_deals_repository.dart';

void main() {
  group('RB-SELLER-01: SellerDealsRepository Unit Tests', () {
    late SecureStorageService storage;
    late SellerDealsRepository repository;

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
      repository = SellerDealsRepository(storage: storage);
    });

    test(
      'getDeals returns authenticated seller deals with booking references',
      () async {
        final deals = await repository.getDeals();
        expect(deals, isNotEmpty);
        expect(deals.any((d) => d.commodityName.contains('Soybean')), isTrue);
        expect(deals.every((d) => d.agreedQuantity > 0), isTrue);
        expect(deals.every((d) => d.agreedPrice > 0), isTrue);
      },
    );

    test('getDeals filters by status correctly', () async {
      final dispatched = await repository.getDeals(statusFilter: 'Dispatched');
      expect(
        dispatched.every((d) => d.status.toLowerCase() == 'dispatched'),
        isTrue,
      );
    });

    test('getDealById returns correct contract details', () async {
      final deal = await repository.getDealById('DEAL-2026-088');
      expect(deal, isNotNull);
      expect(deal!.commodityName, 'Yellow Soybean');
      expect(deal.agreedQuantity, 50.0);
      expect(deal.bookingReference, 'BKG-2026-0881');
    });
  });
}
