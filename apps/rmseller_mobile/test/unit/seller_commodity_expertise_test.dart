import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_commodity_expertise.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storage;
  late SellerProfileRepository repository;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    repository = SellerProfileRepository(storage: storage);
  });

  group('SellerCommodityExpertise Domain Model Tests', () {
    test('normalization handles case, whitespace, and special characters', () {
      expect(
        SellerCommodityExpertise.normalizeName('  Wheat  (Sharbati)  '),
        'wheat sharbati',
      );
      expect(
        SellerCommodityExpertise.normalizeName('MUSTARD-SEED'),
        'mustardseed',
      );
      expect(
        SellerCommodityExpertise.normalizeName('Chana   Desi  Bold'),
        'chana desi bold',
      );
    });

    test('areNamesMatching accurately matches normalized variations', () {
      expect(
        SellerCommodityExpertise.areNamesMatching('Wheat', '  wheat  '),
        isTrue,
      );
      expect(
        SellerCommodityExpertise.areNamesMatching('Mustard Seed', 'Mustard  Seed'),
        isTrue,
      );
      expect(
        SellerCommodityExpertise.areNamesMatching('Wheat', 'Barley'),
        isFalse,
      );
    });

    test('fromMaster creates verified approved expertise entry', () {
      const master = MasterCommodity(
        id: 'comm-wheat-01',
        name: 'Wheat Sharbati',
        code: 'WHT-SHR',
        categoryName: 'Grains & Cereals',
      );

      final exp = SellerCommodityExpertise.fromMaster(master);
      expect(exp.id, 'comm-wheat-01');
      expect(exp.commodityName, 'Wheat Sharbati');
      expect(exp.commodityCode, 'WHT-SHR');
      expect(exp.categoryName, 'Grains & Cereals');
      expect(exp.isApproved, isTrue);
      expect(exp.addedAt, isNotNull);
    });

    test('pending creates seller-added custom commodity marked pending approval', () {
      final custom = SellerCommodityExpertise.pending(
        commodityName: 'Desi Organic Chana',
        categoryName: 'Pulses',
      );

      expect(custom.id, startsWith('custom-'));
      expect(custom.commodityName, 'Desi Organic Chana');
      expect(custom.categoryName, 'Pulses');
      expect(custom.isApproved, isFalse);
      expect(custom.addedAt, isNotNull);
    });

    test('toMap and fromMap serialize and deserialize cleanly', () {
      final original = SellerCommodityExpertise(
        id: 'comm-101',
        commodityName: 'Mustard Seed',
        commodityCode: 'MST-01',
        categoryName: 'Oilseeds',
        isApproved: true,
        addedAt: DateTime(2026, 10, 28, 5, 0),
      );

      final map = original.toMap();
      final restored = SellerCommodityExpertise.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.commodityName, original.commodityName);
      expect(restored.commodityCode, original.commodityCode);
      expect(restored.categoryName, original.categoryName);
      expect(restored.isApproved, isTrue);
      expect(restored.addedAt, original.addedAt);
    });
  });

  group('Invoice OCR Commodity Extraction Tests', () {
    const ocrService = InvoiceOcrService();

    test('extracts commodities from trade line items and agricultural terms', () {
      const invoiceText = '''
TAX INVOICE
Seller: Bikaner Agro Processing Ltd
GSTIN: 08AAAAA0000A1Z5
Mandi: Bikaner Krishi Upaj Mandi
------------------------------------------------------
Item Description              Qty        Rate    Amount
1. Wheat Sharbati Grade-A     100 Qtls   2450    245000
2. Mustard Seed Bold FAQ       50 Qtls   5200    260000
3. Chana Desi                  80 Bags   4900    392000
------------------------------------------------------
Total Amount: INR 8,97,000
Bank: State Bank of India
A/C: 123456789012
IFSC: SBIN0001234
''';

      final data = ocrService.extractFromText(invoiceText);
      expect(data.extractedCommodities, isNotEmpty);
      expect(
        data.extractedCommodities.any((c) => c.toLowerCase().contains('wheat')),
        isTrue,
      );
      expect(
        data.extractedCommodities.any((c) => c.toLowerCase().contains('mustard')),
        isTrue,
      );
      expect(
        data.extractedCommodities.any((c) => c.toLowerCase().contains('chana')),
        isTrue,
      );
    });

    test('returns empty commodity list when invoice has no commodity mentions', () {
      const nonTradeText = '''
RECEIPT / SERVICE INVOICE
Vendor: Office Supplies Pvt Ltd
GSTIN: 08BBBBB1111B1Z2
Service: Warehouse Equipment Repair & IT Support
Total: INR 15,000
''';

      final data = ocrService.extractFromText(nonTradeText);
      expect(data.extractedCommodities, isEmpty);
    });
  });

  group('SellerProfileRepository Commodity Expertise Persistence', () {
    test('persists and loads commodity expertise in profile and cache', () async {
      final initialProfile = await repository.getProfile();
      expect(initialProfile.commodityExpertise, isEmpty);

      const wheat = SellerCommodityExpertise(
        id: 'comm-wheat',
        commodityName: 'Wheat',
        commodityCode: 'WHT-01',
        categoryName: 'Grains',
        isApproved: true,
      );
      final custom = SellerCommodityExpertise.pending(
        commodityName: 'Custom Guar Seed Super',
        categoryName: 'Speciality Crops',
      );

      final updatedProfile = initialProfile.copyWith(
        commodityExpertise: [wheat, custom],
      );

      final saved = await repository.updateProfile(
        updatedProfile,
        operationType: 'MANUAL_EDIT',
      );

      expect(saved.commodityExpertise.length, 2);
      expect(saved.commodityExpertise[0].commodityName, 'Wheat');
      expect(saved.commodityExpertise[0].isApproved, isTrue);
      expect(saved.commodityExpertise[1].commodityName, 'Custom Guar Seed Super');
      expect(saved.commodityExpertise[1].isApproved, isFalse);

      // Verify getSavedCommodityExpertise retrieves them
      final savedExpertise = await repository.getSavedCommodityExpertise();
      expect(savedExpertise.length, 2);
      expect(savedExpertise.any((e) => e.commodityName == 'Wheat'), isTrue);
      expect(savedExpertise.any((e) => e.commodityName == 'Custom Guar Seed Super'), isTrue);
    });

    test('audit history records commodity_expertise field change', () async {
      final profile = await repository.getProfile();
      const exp = SellerCommodityExpertise(
        id: 'c-1',
        commodityName: 'Mustard',
        isApproved: true,
      );

      await repository.updateProfile(
        profile.copyWith(commodityExpertise: [exp]),
        operationType: 'INVOICE_ASSISTED_EDIT',
      );

      final logs = await repository.getProfileAuditHistory(
        sellerId: profile.id,
        checkAdminRole: false,
      );
      expect(logs, isNotEmpty);
      final latest = logs.first;
      expect(latest.changedFields, contains('Commodity Expertise'));
      expect(latest.changeSummary, contains('Mustard'));
    });
  });
}
