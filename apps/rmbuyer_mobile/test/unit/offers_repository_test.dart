import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/offers/data/offers_repository.dart';
import 'package:rmbuyer_mobile/features/offers/domain/offer_inputs.dart';

void main() {
  group('RB-BUYER-05: OffersRepository Unit Tests', () {
    late OffersRepository repository;

    setUp(() {
      OffersRepository.resetForTesting();
      repository = OffersRepository();
    });

    test('Retrieves baseline offers with correct status and commercial fields', () async {
      final offers = await repository.getOffers();
      expect(offers, isNotEmpty);
      expect(offers.any((o) => o.commodityName.contains('Maize')), isTrue);
      expect(offers.any((o) => o.status == 'Proposed'), isTrue);
    });

    test('Filters offers by requirement ID correctly', () async {
      final offers = await repository.getOffers(requirementId: '60000000-0000-0000-0000-000000000101');
      expect(offers, isNotEmpty);
      for (final o in offers) {
        expect(o.requirementId, equals('60000000-0000-0000-0000-000000000101'));
      }
    });

    test('Filters offers by status correctly', () async {
      final proposed = await repository.getOffers(statusFilter: 'Proposed');
      for (final o in proposed) {
        expect(o.status.toLowerCase(), equals('proposed'));
      }

      final accepted = await repository.getOffers(statusFilter: 'Accepted');
      for (final o in accepted) {
        expect(o.status.toLowerCase(), equals('accepted'));
      }
    });

    test('Submitting counter-offer appends immutable round and updates status to Countered', () async {
      final initialOffer = await repository.getOfferById('OFFER-2026-081');
      expect(initialOffer, isNotNull);
      final initialVersion = initialOffer!.versionNumber;
      final initialRoundCount = initialOffer.negotiationRounds.length;

      final updated = await repository.submitCounterOffer(
        CounterOfferInput(
          proposalId: 'OFFER-2026-081',
          expectedVersionNumber: initialVersion,
          counterPrice: 22100.0,
          counterQuantity: 100.0,
          buyerNotes: 'Target ₹22,100 based on spot mandi arrivals.',
        ),
      );

      expect(updated.status, equals('Countered'));
      expect(updated.offeredPrice, equals(22100.0));
      expect(updated.versionNumber, equals(initialVersion + 1));
      expect(updated.negotiationRounds.length, equals(initialRoundCount + 1));

      final latestRound = updated.negotiationRounds.last;
      expect(latestRound.actorRole, equals('buyer'));
      expect(latestRound.proposedPrice, equals(22100.0));
      expect(latestRound.isCurrent, isTrue);
      expect(latestRound.notes, contains('Target ₹22,100'));
    });

    test('Optimistic locking: Throws StateError when submitting counter against stale version', () async {
      expect(
        () async => await repository.submitCounterOffer(
          const CounterOfferInput(
            proposalId: 'OFFER-2026-081',
            expectedVersionNumber: 1, // Current is 2 in baseline!
            counterPrice: 22000.0,
            counterQuantity: 100.0,
          ),
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('STALE_VERSION_DETECTED'))),
      );
    });

    test('Counter-offer input validation rejects non-positive rates and quantities', () async {
      expect(
        () async => await repository.submitCounterOffer(
          const CounterOfferInput(
            proposalId: 'OFFER-2026-081',
            expectedVersionNumber: 2,
            counterPrice: -100.0,
            counterQuantity: 100.0,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () async => await repository.submitCounterOffer(
          const CounterOfferInput(
            proposalId: 'OFFER-2026-081',
            expectedVersionNumber: 2,
            counterPrice: 22000.0,
            counterQuantity: 0.0,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Accepting an offer updates status to Accepted and blocks further negotiation', () async {
      final accepted = await repository.acceptOffer(
        const AcceptOfferInput(
          proposalId: 'OFFER-2026-081',
          expectedVersionNumber: 2,
        ),
      );

      expect(accepted.status, equals('Accepted'));
      expect(accepted.isActionable, isFalse);
      expect(accepted.isTerminal, isTrue);

      // Attempting to counter an accepted offer must fail
      expect(
        () async => await repository.submitCounterOffer(
          const CounterOfferInput(
            proposalId: 'OFFER-2026-081',
            expectedVersionNumber: 2,
            counterPrice: 21900.0,
            counterQuantity: 100.0,
          ),
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('cannot be countered'))),
      );
    });

    test('Rejecting an offer requires commercial reason and updates status to Rejected', () async {
      // Empty reason throws ArgumentError
      expect(
        () async => await repository.rejectOffer(
          const RejectOfferInput(
            proposalId: 'OFFER-2026-081',
            expectedVersionNumber: 2,
            reason: '   ',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      final rejected = await repository.rejectOffer(
        const RejectOfferInput(
          proposalId: 'OFFER-2026-081',
          expectedVersionNumber: 2,
          reason: 'Rate above budget / unacceptable',
          notes: 'Max allocation budget is ₹21,500/MT.',
        ),
      );

      expect(rejected.status, equals('Rejected'));
      expect(rejected.isActionable, isFalse);
      expect(rejected.isTerminal, isTrue);

      // Rejection updates round notes with reason
      final latestRound = rejected.negotiationRounds.last;
      expect(latestRound.status, equals('Rejected'));
      expect(latestRound.notes, contains('Rate above budget'));
    });

    test('Expired offers cannot be accepted or countered', () async {
      final expired = await repository.getOfferById('OFFER-2026-084');
      expect(expired, isNotNull);
      expect(expired!.isExpired, isTrue);
      expect(expired.isActionable, isFalse);

      expect(
        () async => await repository.acceptOffer(
          AcceptOfferInput(
            proposalId: expired.id,
            expectedVersionNumber: expired.versionNumber,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
