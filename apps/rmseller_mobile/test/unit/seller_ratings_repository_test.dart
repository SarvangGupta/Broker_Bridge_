import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/ratings/data/seller_ratings_repository.dart';
import 'package:rmseller_mobile/features/ratings/domain/broker_rating_model.dart';

void main() {
  group('Sprint RB-SELLER-05: SellerRatingsRepository Unit Tests', () {
    late SellerRatingsRepository repository;

    setUp(() {
      SellerRatingsRepository.resetCacheForTesting();
      repository = SellerRatingsRepository();
    });

    test('Test 1: Evaluates rating eligibility for broker with completed deals', () async {
      const bikanerBrokerId = 'b354958e-779a-41f2-b7a3-5899eca32e32';
      final eligibility = await repository.checkRatingEligibility(
        brokerId: bikanerBrokerId,
        dealId: 'd354958e-779a-41f2-b7a3-5899eca32e01',
      );

      expect(eligibility.isEligible, isTrue);
      expect(eligibility.eligibleDealId, equals('d354958e-779a-41f2-b7a3-5899eca32e01'));
      expect(eligibility.eligibleDealReference, contains('BKG'));
    });

    test('Test 2: Rejects rating eligibility for broker without completed trades', () async {
      const unknownBrokerId = 'unknown-broker-id-without-deals';
      final eligibility = await repository.checkRatingEligibility(
        brokerId: unknownBrokerId,
      );

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.reason, contains('Rating Unavailable'));
      expect(eligibility.reason, contains('completed at least one verified trade'));
    });

    test('Test 3: Validates star rating bounds (must be between 1 and 5)', () async {
      final invalidLowRating = BrokerRating(
        id: 'RAT-INVALID-0',
        brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        brokerName: 'Bikaner Mandi Desk',
        sellerId: 'test-seller',
        rating: 0, // Invalid: below 1
        createdAt: DateTime.now(),
      );

      expect(
        () => repository.submitBrokerRating(invalidLowRating),
        throwsA(isA<ArgumentError>()),
      );

      final invalidHighRating = BrokerRating(
        id: 'RAT-INVALID-6',
        brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        brokerName: 'Bikaner Mandi Desk',
        sellerId: 'test-seller',
        rating: 6, // Invalid: above 5
        createdAt: DateTime.now(),
      );

      expect(
        () => repository.submitBrokerRating(invalidHighRating),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Test 4: Validates feedback length constraint (maximum 500 characters)', () async {
      final overlongFeedback = 'A' * 501; // 501 characters
      final overlongRating = BrokerRating(
        id: 'RAT-OVERLONG',
        brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        brokerName: 'Bikaner Mandi Desk',
        sellerId: 'test-seller',
        rating: 5,
        feedback: overlongFeedback,
        createdAt: DateTime.now(),
      );

      expect(
        () => repository.submitBrokerRating(overlongRating),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Test 5: Rating Permission Matrix: Rejects attempts to rate a Buyer (Counterparty Shield)', () async {
      final buyerTargetRating = BrokerRating(
        id: 'RAT-ATTEMPT-BUYER',
        brokerId: 'target-buyer-id-forbidden',
        brokerName: 'Prohibited Buyer Target',
        sellerId: 'test-seller',
        rating: 5,
        createdAt: DateTime.now(),
      );

      expect(
        () => repository.submitBrokerRating(buyerTargetRating),
        throwsA(isA<StateError>()),
      );
    });

    test('Test 6: Calculates accurate rating summary, distribution, and averages', () async {
      const bikanerBrokerId = 'b354958e-779a-41f2-b7a3-5899eca32e32';
      final summary = await repository.getBrokerRatingSummary(bikanerBrokerId);

      expect(summary.totalReviews, greaterThanOrEqualTo(3));
      expect(summary.averageRating, inInclusiveRange(4.0, 5.0));
      expect(summary.isUnrated, isFalse);
      expect(summary.starDistribution[5], greaterThan(0));
      expect(summary.criteriaAverages.containsKey('Mandi Knowledge'), isTrue);
      expect(summary.criteriaAverages.containsKey('Settlement Timeliness'), isTrue);
    });

    test('Test 7: Clearly distinguishes unrated broker from a low-rated broker', () async {
      const unratedBrokerId = 'b354958e-779a-41f2-b7a3-5899eca32e35'; // Jaipur desk
      final summary = await repository.getBrokerRatingSummary(unratedBrokerId);

      expect(summary.isUnrated, isTrue);
      expect(summary.totalReviews, equals(0));
      expect(summary.averageRating, equals(0.0));
      expect(summary.getPercentage(5), equals(0.0));
    });

    test('Test 8: Updates existing review instead of creating duplicate on re-submission', () async {
      const bikanerBrokerId = 'b354958e-779a-41f2-b7a3-5899eca32e32';
      const dealId = 'd354958e-779a-41f2-b7a3-5899eca32e01';

      final initialSummary = await repository.getBrokerRatingSummary(bikanerBrokerId);
      final initialCount = initialSummary.totalReviews;

      // Submit an updated rating for the same deal
      final updatedRating = BrokerRating(
        id: 'RAT-UPDATED',
        brokerId: bikanerBrokerId,
        brokerName: 'Bikaner Mandi Desk',
        sellerId: 'e9a4f61b-3c2d-4e8f-9a1b-7c5d3e2f1a0b',
        dealId: dealId,
        dealReference: 'BKG-2026-0881',
        rating: 5,
        feedback: 'Updated review: Payment settled even faster than previous lot.',
        createdAt: DateTime.now(),
      );

      final saved = await repository.submitBrokerRating(updatedRating);
      expect(saved.feedback, contains('Updated review'));

      // Check review count did not double count
      final updatedSummary = await repository.getBrokerRatingSummary(bikanerBrokerId);
      expect(updatedSummary.totalReviews, equals(initialCount));
    });

    test('Test 9: Strict Counterparty Shield: Rating model payload omits all Buyer identifiers', () {
      final rating = BrokerRating(
        id: 'RAT-SHIELD-TEST',
        brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        brokerName: 'Bikaner Mandi Desk',
        sellerId: 'test-seller',
        dealId: 'deal-001',
        dealReference: 'BKG-001',
        rating: 5,
        feedback: 'Clean trade feedback without buyer PII.',
        createdAt: DateTime.now(),
      );

      final map = rating.toMap();
      expect(map.containsKey('buyer_id'), isFalse);
      expect(map.containsKey('buyer_name'), isFalse);
      expect(map.containsKey('buyer_phone'), isFalse);
      expect(map.containsKey('buyer_email'), isFalse);
      expect(map['broker_id'], equals('b354958e-779a-41f2-b7a3-5899eca32e32'));
    });
  });
}
