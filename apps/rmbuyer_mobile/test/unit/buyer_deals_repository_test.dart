import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/deals/data/buyer_deals_repository.dart';
import 'package:rmbuyer_mobile/features/deals/domain/final_deal_review_model.dart';

void main() {
  group('RB-BUYER-06: BuyerDealsRepository Deal Confirmation & Concurrency Tests', () {
    late BuyerDealsRepository repository;

    setUp(() {
      BuyerDealsRepository.resetStore();
      repository = BuyerDealsRepository();
    });

    test('Scenario 6: getDeals returns authorized deal list with baseline fallback', () async {
      final deals = await repository.getDeals();
      expect(deals.isNotEmpty, isTrue);
      expect(deals.any((d) => d.id == 'DEAL-2026-042'), isTrue);

      final filtered = await repository.getDeals(statusFilter: 'In Transit');
      expect(filtered.every((d) => d.status.toLowerCase() == 'in transit'), isTrue);
    });

    test('Scenario 7: getFinalDealReview returns authoritative snapshot with charges & quality specs', () async {
      final review = await repository.getFinalDealReview('DEAL-2026-TEST-100');

      expect(review.dealId, 'DEAL-2026-TEST-100');
      expect(review.versionNumber, 2);
      expect(review.hasPreviousVersion, isTrue);
      expect(review.currentTerms.commodityName, 'Yellow Maize / Corn');
      expect(review.currentTerms.quantity, 250.0);
      expect(review.currentTerms.basePricePerUnit, 24200.0);
      expect(review.currentTerms.applicableCharges.length, 3);
      expect(review.currentTerms.qualityParameters.length, 4);
      expect(review.isConfirmable, isTrue);
      expect(review.isConfirmed, isFalse);
    });

    test('Scenario 8: confirmFinalDeal successfully confirms deal and mutates status to Buyer Confirmed', () async {
      const dealId = 'DEAL-2026-TEST-101';
      final initial = await repository.getFinalDealReview(dealId);
      expect(initial.isConfirmable, isTrue);

      final input = ConfirmDealInput(
        dealId: dealId,
        expectedVersion: initial.versionNumber,
        buyerConfirmed: true,
      );

      final confirmed = await repository.confirmFinalDeal(input);

      expect(confirmed.status, DealConfirmationStatus.buyerConfirmed);
      expect(confirmed.isConfirmed, isTrue);
      expect(confirmed.isConfirmable, isFalse);

      // Verify persistent cache holds confirmed status
      final refetched = await repository.getFinalDealReview(dealId);
      expect(refetched.status, DealConfirmationStatus.buyerConfirmed);
    });

    test('Scenario 9: confirmFinalDeal throws StaleVersionException when expectedVersion is outdated', () async {
      const dealId = 'DEAL-2026-TEST-102';
      final initial = await repository.getFinalDealReview(dealId);

      // Simulate concurrent broker revision advancing version number
      repository.simulateBrokerVersionIncrement(dealId);

      final staleInput = ConfirmDealInput(
        dealId: dealId,
        expectedVersion: initial.versionNumber, // Stale version 2 vs updated 3
        buyerConfirmed: true,
      );

      expect(
        () => repository.confirmFinalDeal(staleInput),
        throwsA(isA<StaleVersionException>()),
      );
    });

    test('Scenario 10: confirmFinalDeal throws DealAlreadyConfirmedException on duplicate confirmation', () async {
      const dealId = 'DEAL-2026-TEST-103';
      final initial = await repository.getFinalDealReview(dealId);

      final input = ConfirmDealInput(
        dealId: dealId,
        expectedVersion: initial.versionNumber,
        buyerConfirmed: true,
      );

      // First confirmation succeeds
      await repository.confirmFinalDeal(input);

      // Repeated confirmation attempt fails idempotently
      expect(
        () => repository.confirmFinalDeal(input),
        throwsA(isA<DealAlreadyConfirmedException>()),
      );
    });

    test('Scenario 11: requestDealAmendment mutates deal status to Amendment Required', () async {
      const dealId = 'DEAL-2026-TEST-104';
      final initial = await repository.getFinalDealReview(dealId);

      final input = RequestAmendmentInput(
        dealId: dealId,
        expectedVersion: initial.versionNumber,
        reason: 'Please reduce price to ₹24,000/MT for immediate loading.',
      );

      final amended = await repository.requestDealAmendment(input);

      expect(amended.status, DealConfirmationStatus.amendmentRequired);
      expect(amended.isAmendmentRequired, isTrue);
      expect(amended.isConfirmable, isFalse);
      expect(amended.brokerNotes, contains('Amendment requested:'));
    });

    test('Scenario 12: requestDealAmendment throws StaleVersionException on version mismatch', () async {
      const dealId = 'DEAL-2026-TEST-105';
      final initial = await repository.getFinalDealReview(dealId);

      // Broker updates version in background
      repository.simulateBrokerVersionIncrement(dealId);

      final input = RequestAmendmentInput(
        dealId: dealId,
        expectedVersion: initial.versionNumber,
        reason: 'Change packaging to Jute bags',
      );

      expect(
        () => repository.requestDealAmendment(input),
        throwsA(isA<StaleVersionException>()),
      );
    });
  });
}
