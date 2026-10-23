import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/broadcast/data/market_broadcast_repository.dart';
import 'package:rmbroker_mobile/features/broadcast/domain/market_broadcast_models.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';

OfferItem _createOfferItem({
  required String id,
  required String lotNumber,
  required String sellerCompanyId,
  required String sellerCompanyName,
  required double askingPrice,
  required int version,
  required DateTime createdAt,
  OfferStatus status = OfferStatus.open,
  double availableQuantity = 50,
  String unitSymbol = 'Qtl',
  String commodityName = 'Mustard Seed (Sarson)',
  String gradeName = 'Grade-A Bold',
  String districtName = 'Jaipur',
  String stateName = 'Rajasthan',
}) {
  return OfferItem(
    id: id,
    ref: '#$id',
    lotNumber: lotNumber,
    sellerCompanyId: sellerCompanyId,
    sellerCompanyName: sellerCompanyName,
    isSellerVerified: true,
    sellerTrustScore: 90,
    commodityId: 'comm-1',
    commodityName: commodityName,
    gradeId: 'grd-1',
    gradeName: gradeName,
    offeredQuantity: availableQuantity,
    availableQuantity: availableQuantity,
    reservedQuantity: 0,
    soldQuantity: 0,
    unitId: 'u-1',
    unitName: unitSymbol == 'kg'
        ? 'Kilogram'
        : (unitSymbol == 'MT' ? 'Metric Tonne' : 'Quintal'),
    unitSymbol: unitSymbol,
    askingPrice: askingPrice,
    confidentialMinimumPrice: askingPrice * 0.95,
    stateId: 's-1',
    stateName: stateName,
    districtId: 'd-1',
    districtName: districtName,
    availableFrom: createdAt,
    validUntil: createdAt.add(const Duration(days: 5)),
    validUntilFormatted: '28 Oct 2026',
    isExpired: false,
    loadingStatus: LoadingReadiness.readyToLoad,
    status: status,
    version: version,
    createdAt: createdAt,
  );
}

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
    await storage.saveUserInfo(
      id: 'broker-active-01',
      role: 'broker',
      email: 'broker@rmbroker.in',
      fullName: 'Chief Broker Nilesh',
    );
  });

  group('Feature D: Mandatory Same-Day Price Resolution Tests (Section 7.3A)', () {
    test('A seller changes price from ₹30/kg to ₹32/kg to ₹34/kg on the same day -> resolver picks ₹34/kg', () {
      final baseDate = DateTime(2026, 10, 23, 9, 0); // 9:00 AM

      final rev1 = _createOfferItem(
        id: 'off-seller1-rev1',
        lotNumber: 'LOT-MUSTARD-001',
        sellerCompanyId: 'comp-seller-1',
        sellerCompanyName: 'Kisan Agro Traders',
        askingPrice: 30.0,
        version: 1,
        createdAt: baseDate,
        unitSymbol: 'kg',
      );

      final rev2 = _createOfferItem(
        id: 'off-seller1-rev2',
        lotNumber: 'LOT-MUSTARD-001',
        sellerCompanyId: 'comp-seller-1',
        sellerCompanyName: 'Kisan Agro Traders',
        askingPrice: 32.0,
        version: 2,
        createdAt: baseDate.add(const Duration(hours: 2)),
        unitSymbol: 'kg',
      );

      final rev3 = _createOfferItem(
        id: 'off-seller1-rev3',
        lotNumber: 'LOT-MUSTARD-001',
        sellerCompanyId: 'comp-seller-1',
        sellerCompanyName: 'Kisan Agro Traders',
        askingPrice: 34.0,
        version: 3,
        createdAt: baseDate.add(const Duration(hours: 5)),
        unitSymbol: 'kg',
      );

      final resolved = MarketBroadcastRepository.resolveLatestPriceRevisions([
        rev1,
        rev2,
        rev3,
      ]);

      expect(resolved.length, 1, reason: 'All revisions belong to the same seller listing');
      final latest = resolved.first;
      expect(latest.askingPrice, 34.0, reason: 'Must resolve to the latest valid price of ₹34/kg');
      expect(latest.version, 3);
      expect(latest.offerId, 'off-seller1-rev3');
    });

    test('Two sellers offer same material and independently change prices -> each retains own latest price', () {
      final baseDate = DateTime(2026, 10, 23, 10, 0);

      // Seller A offers Mustard at ₹5,400/Qtl then updates to ₹5,450/Qtl
      final sellerA1 = _createOfferItem(
        id: 'off-sellerA-1',
        lotNumber: 'LOT-SELLER-A',
        sellerCompanyId: 'comp-seller-A',
        sellerCompanyName: 'Agrawal Agro Foods',
        askingPrice: 5400.0,
        version: 1,
        createdAt: baseDate,
      );

      final sellerA2 = _createOfferItem(
        id: 'off-sellerA-2',
        lotNumber: 'LOT-SELLER-A',
        sellerCompanyId: 'comp-seller-A',
        sellerCompanyName: 'Agrawal Agro Foods',
        askingPrice: 5450.0,
        version: 2,
        createdAt: baseDate.add(const Duration(hours: 1)),
      );

      // Seller B offers Mustard at ₹5,380/Qtl then updates to ₹5,390/Qtl
      final sellerB1 = _createOfferItem(
        id: 'off-sellerB-1',
        lotNumber: 'LOT-SELLER-B',
        sellerCompanyId: 'comp-seller-B',
        sellerCompanyName: 'Bharat Seeds & Oils',
        askingPrice: 5380.0,
        version: 1,
        createdAt: baseDate,
        districtName: 'Kota',
      );

      final sellerB2 = _createOfferItem(
        id: 'off-sellerB-2',
        lotNumber: 'LOT-SELLER-B',
        sellerCompanyId: 'comp-seller-B',
        sellerCompanyName: 'Bharat Seeds & Oils',
        askingPrice: 5390.0,
        version: 2,
        createdAt: baseDate.add(const Duration(hours: 3)),
        districtName: 'Kota',
      );

      final resolved = MarketBroadcastRepository.resolveLatestPriceRevisions([
        sellerA1,
        sellerA2,
        sellerB1,
        sellerB2,
      ]);

      expect(resolved.length, 2, reason: 'Both sellers must be listed independently without price mixing');

      final a = resolved.firstWhere((o) => o.sellerCompanyId == 'comp-seller-A');
      expect(a.askingPrice, 5450.0);

      final b = resolved.firstWhere((o) => o.sellerCompanyId == 'comp-seller-B');
      expect(b.askingPrice, 5390.0);
    });

    test('Deterministic tie-breaker: multiple revisions with same timestamp resolve using version desc', () {
      final now = DateTime(2026, 10, 23, 12, 0);

      final rev1 = _createOfferItem(
        id: 'off-tie-v1',
        lotNumber: 'LOT-TIE',
        sellerCompanyId: 'comp-tie',
        sellerCompanyName: 'Tie Seller',
        askingPrice: 42000.0,
        version: 1,
        createdAt: now,
        unitSymbol: 'MT',
      );

      final rev2 = _createOfferItem(
        id: 'off-tie-v2',
        lotNumber: 'LOT-TIE',
        sellerCompanyId: 'comp-tie',
        sellerCompanyName: 'Tie Seller',
        askingPrice: 42500.0,
        version: 2,
        createdAt: now,
        unitSymbol: 'MT',
      );

      final resolved = MarketBroadcastRepository.resolveLatestPriceRevisions([
        rev1,
        rev2,
      ]);

      expect(resolved.length, 1);
      expect(resolved.first.version, 2);
      expect(resolved.first.askingPrice, 42500.0);
    });

    test('Withdrawn or expired latest revision does not accidentally resurrect an obsolete price', () {
      final now = DateTime.now();

      final latestWithdrawn = _createOfferItem(
        id: 'off-latest-withdrawn',
        lotNumber: 'LOT-EXPIRED-TEST',
        sellerCompanyId: 'comp-x',
        sellerCompanyName: 'Seller X',
        askingPrice: 2800.0,
        version: 2,
        status: OfferStatus.cancelled,
        createdAt: now,
      );

      final List<OfferItem> offers = [latestWithdrawn];
      final resolved = MarketBroadcastRepository.resolveLatestPriceRevisions(offers);
      expect(resolved.isEmpty, isTrue, reason: 'Withdrawn lot cannot be resurrected with an obsolete price');
    });

    test('Confidential floor price NEVER leaks into standardized broadcast message', () {
      final revision = SellerOfferPriceRevision(
        offerId: 'off-secret-1',
        lotNumber: 'LOT-SECRET',
        sellerCompanyId: 'comp-secret',
        sellerCompanyName: 'Secret Agro Mills',
        commodityId: 'comm-chana',
        commodityName: 'Desi Chana (Chickpeas)',
        gradeId: 'grade-bold',
        gradeName: 'Bold',
        askingPrice: 6200.0,
        unitSymbol: 'Qtl',
        availableQuantity: 120.0,
        location: 'Bikaner Mandi, Rajasthan',
        version: 1,
        priceUpdatedAt: DateTime.now(),
      );

      final msg = BroadcastDraft.buildStandardMessage(
        brokerageName: 'RMBroker Jaipur Mandi Desk',
        brokerName: 'Broker Nilesh Sharma',
        offers: [revision],
      );

      // Verify asking price is visible
      expect(msg, contains('6,200'));
      expect(msg, contains('Desi Chana (Chickpeas)'));
      expect(msg, contains('Secret Agro Mills'));

      // Verify confidential terms do NOT appear
      expect(msg.toLowerCase(), isNot(contains('confidential')));
      expect(msg.toLowerCase(), isNot(contains('floor price')));
      expect(msg.toLowerCase(), isNot(contains('commission')));
      expect(msg.toLowerCase(), isNot(contains('margin')));
    });
  });

  group('Feature D: Pre-Commit Price Validation & Snapshot Verification', () {
    test('validatePriceSnapshot detects price drift and flags stale preview', () async {
      final now = DateTime.now();

      final initialSnapshot = [
        SellerOfferPriceRevision(
          offerId: 'off-1',
          lotNumber: 'LOT-1',
          sellerCompanyId: 'comp-1',
          sellerCompanyName: 'Company 1',
          commodityId: 'comm-1',
          commodityName: 'Mustard',
          gradeId: 'grd-1',
          gradeName: 'Bold',
          askingPrice: 5000.0, // Stale confirmed price
          unitSymbol: 'Qtl',
          availableQuantity: 50,
          location: 'Jaipur',
          version: 1, // Stale version
          priceUpdatedAt: now,
        ),
      ];

      final freshOffers = [
        _createOfferItem(
          id: 'off-1',
          lotNumber: 'LOT-1',
          sellerCompanyId: 'comp-1',
          sellerCompanyName: 'Company 1',
          askingPrice: 5100.0, // Price updated to ₹5,100!
          version: 2, // Version incremented!
          createdAt: now.add(const Duration(hours: 1)),
        ),
      ];

      final workRepo = _MockWorkRepository(freshOffers);
      final repo = MarketBroadcastRepository(
        storage: storage,
        workRepo: workRepo,
      );

      final valResult = await repo.validatePriceSnapshot(initialSnapshot);

      expect(valResult.isValid, isFalse, reason: 'Snapshot must be rejected as stale');
      expect(valResult.hasPriceDrift, isTrue);
      expect(valResult.changedOfferIds, contains('off-1'));
      expect(valResult.staleDescriptions.first, contains('Price updated from ₹5000.0 to ₹5100.0'));
    });

    test('sendMarketPriceBroadcast throws PriceDriftException if price changed before commit', () async {
      final now = DateTime.now();

      final initialOffers = [
        SellerOfferPriceRevision(
          offerId: 'off-drift',
          lotNumber: 'LOT-DRIFT',
          sellerCompanyId: 'comp-d',
          sellerCompanyName: 'Drift Seller',
          commodityId: 'comm-d',
          commodityName: 'Soybean',
          gradeId: 'grd-d',
          gradeName: 'Grade-1',
          askingPrice: 4000.0,
          unitSymbol: 'MT',
          availableQuantity: 100,
          location: 'Kota',
          version: 1,
          priceUpdatedAt: now,
        ),
      ];

      final buyer = BuyerRecipient(
        userId: 'buyer-user-1',
        companyId: 'buyer-comp-1',
        name: 'Sharma Agro Mill',
        companyName: 'Sharma Foods Pvt Ltd',
        mobile: '+91 98290 55555',
        isVerified: true,
      );

      final draft = BroadcastDraft(
        broadcastId: 'bc-test-drift-01',
        brokerId: 'broker-active-01',
        brokerName: 'Nilesh Broker',
        brokerageName: 'Jaipur Commodity Desk',
        recipients: [buyer],
        offers: initialOffers,
        generatedMessage: 'Test Market Update Message',
        createdAt: now,
      );

      // Backend seller offer has drifted to ₹4,200 v2
      final driftedOffers = [
        _createOfferItem(
          id: 'off-drift',
          lotNumber: 'LOT-DRIFT',
          sellerCompanyId: 'comp-d',
          sellerCompanyName: 'Drift Seller',
          commodityName: 'Soybean',
          gradeName: 'Grade-1',
          askingPrice: 4200.0,
          unitSymbol: 'MT',
          version: 2,
          createdAt: now.add(const Duration(minutes: 30)),
        ),
      ];

      final dirRepo = _MockDirectoryRepository([
        DirectoryContact(
          id: 'crm-1',
          userId: 'buyer-user-1',
          companyId: 'buyer-comp-1',
          name: 'Sharma Agro Mill',
          companyName: 'Sharma Foods Pvt Ltd',
          mobile: '9829055555',
          role: ContactRole.buyer,
          status: true,
          createdAt: now,
        ),
      ]);

      final repo = MarketBroadcastRepository(
        storage: storage,
        workRepo: _MockWorkRepository(driftedOffers),
        dirRepo: dirRepo,
      );

      expect(
        () async => await repo.sendMarketPriceBroadcast(draft),
        throwsA(isA<PriceDriftException>()),
      );
    });

    test('sendMarketPriceBroadcast successfully delivers in-app notifications when prices are valid', () async {
      final now = DateTime.now();

      final validOffer = SellerOfferPriceRevision(
        offerId: 'off-valid-1',
        lotNumber: 'LOT-VALID',
        sellerCompanyId: 'comp-v',
        sellerCompanyName: 'Verified Traders',
        commodityId: 'comm-v',
        commodityName: 'Mustard',
        gradeId: 'grd-v',
        gradeName: 'Bold',
        askingPrice: 5200.0,
        unitSymbol: 'Qtl',
        availableQuantity: 75,
        location: 'Jaipur',
        version: 1,
        priceUpdatedAt: now,
      );

      final buyer = BuyerRecipient(
        userId: 'buyer-user-2',
        companyId: 'buyer-comp-2',
        name: 'Gupta Flour & Oil Mills',
        companyName: 'Gupta Agro Ltd',
        mobile: '+91 94140 11111',
        isVerified: true,
      );

      final draft = BroadcastDraft(
        broadcastId: 'bc-success-01',
        brokerId: 'broker-active-01',
        brokerName: 'Chief Broker Nilesh',
        brokerageName: 'Jaipur Commodity Desk',
        recipients: [buyer],
        offers: [validOffer],
        generatedMessage: 'MARKET PRICE UPDATE\nMustard: ₹5,200/Qtl',
        createdAt: now,
      );

      final matchingServerOffers = [
        _createOfferItem(
          id: 'off-valid-1',
          lotNumber: 'LOT-VALID',
          sellerCompanyId: 'comp-v',
          sellerCompanyName: 'Verified Traders',
          commodityName: 'Mustard',
          gradeName: 'Bold',
          askingPrice: 5200.0,
          version: 1,
          createdAt: now,
        ),
      ];

      final dirRepo = _MockDirectoryRepository([
        DirectoryContact(
          id: 'crm-2',
          userId: 'buyer-user-2',
          companyId: 'buyer-comp-2',
          name: 'Gupta Flour & Oil Mills',
          companyName: 'Gupta Agro Ltd',
          mobile: '9414011111',
          role: ContactRole.buyer,
          status: true,
          createdAt: now,
        ),
      ]);

      final repo = MarketBroadcastRepository(
        storage: storage,
        workRepo: _MockWorkRepository(matchingServerOffers),
        dirRepo: dirRepo,
      );

      final outcome = await repo.sendMarketPriceBroadcast(draft);

      expect(outcome.isFullSuccess, isTrue);
      expect(outcome.successfulDeliveryCount, 1);
      expect(outcome.failedDeliveryCount, 0);
      expect(outcome.successfulRecipientNames.first, contains('Gupta Flour & Oil Mills'));
      expect(outcome.sentPriceSnapshot.first.askingPrice, 5200.0);
    });
  });
}

class _MockWorkRepository extends WorkRepository {
  final List<OfferItem> _offers;
  _MockWorkRepository(this._offers);

  @override
  Future<WorkDataResult<List<OfferItem>>> getOffers() async {
    return WorkSuccess(_offers);
  }
}

class _MockDirectoryRepository extends DirectoryRepository {
  final List<DirectoryContact> _contacts;
  _MockDirectoryRepository(this._contacts);

  @override
  Future<DirectoryDataResult<DirectoryListPayload>> getContacts({
    String? role,
    String? search,
    String? status,
  }) async {
    return DirectorySuccess(
      DirectoryListPayload(
        contacts: _contacts,
        stats: DirectorySummaryStats.fromContacts(_contacts),
      ),
    );
  }
}
