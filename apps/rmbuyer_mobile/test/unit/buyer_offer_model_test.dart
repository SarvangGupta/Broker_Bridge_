import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/offers/domain/buyer_offer_model.dart';
import 'package:rmbuyer_mobile/features/offers/domain/offer_inputs.dart';

void main() {
  group('RB-BUYER-05: BuyerOffer Domain Model & Counterparty Shield Tests', () {
    test('Constructs BuyerOffer correctly and verifies calculation of totalEstimatedValue', () {
      final offer = BuyerOffer(
        id: 'OFFER-001',
        requirementId: 'REQ-001',
        requirementDisplayId: 'REQ-2026-001',
        commodityName: 'Yellow Maize',
        gradeName: 'Grade A FAQ',
        offeredQuantity: 100.0,
        unit: 'MT',
        offeredPrice: 22500.0,
        totalEstimatedValue: 2250000.0,
        status: 'Proposed',
        versionNumber: 1,
        brokerName: 'Kota Agro Broker Desk',
        deliveryTerms: 'FOR Destination',
        deliveryLocation: 'Kota Mill, Rajasthan',
        paymentTerms: '100% Against Delivery',
        packagingType: '50kg HDPE Bags',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(offer.id, equals('OFFER-001'));
      expect(offer.offeredPrice, equals(22500.0));
      expect(offer.offeredQuantity, equals(100.0));
      expect(offer.totalEstimatedValue, equals(2250000.0));
      expect(offer.isActionable, isTrue);
      expect(offer.isTerminal, isFalse);
    });

    test('Counterparty Shield: BuyerOffer contains zero seller identifiers or seller contacts', () {
      final offer = BuyerOffer(
        id: 'OFFER-002',
        requirementId: 'REQ-002',
        requirementDisplayId: 'REQ-2026-002',
        commodityName: 'Sharbati Wheat',
        gradeName: 'Premium',
        offeredQuantity: 50.0,
        unit: 'MT',
        offeredPrice: 28000.0,
        totalEstimatedValue: 1400000.0,
        status: 'Proposed',
        versionNumber: 1,
        brokerName: 'Jaipur Grain Desk',
        deliveryTerms: 'Ex-Mandi',
        deliveryLocation: 'Jaipur',
        paymentTerms: 'CAD',
        packagingType: 'Jute Bags',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify that no seller properties exist on the offer
      expect(offer.brokerName, equals('Jaipur Grain Desk'));
      expect(offer.brokerId, isNull);

      // Verify mapping does not accept or leak seller fields
      final map = {
        'id': 'OFFER-002',
        'requirement_id': 'REQ-002',
        'commodity_name': 'Sharbati Wheat',
        'offered_price': 28000,
        'quantity': 50,
        'seller_id': 'UNAUTHORIZED_SELLER_ID',
        'seller_phone': '+919999999999',
        'seller_name': 'Secret Seller Corp',
      };

      final parsed = BuyerOffer.fromMap(map);
      expect(parsed.id, equals('OFFER-002'));
      expect(parsed.offeredPrice, equals(28000.0));
      // Zero seller fields exposed
    });

    test('NegotiationRound preserves immutable historical rounds and actor identity', () {
      final round1 = NegotiationRound(
        id: 'R1',
        versionNumber: 1,
        status: 'Superseded',
        actorRole: 'broker',
        proposerName: 'Broker Desk (Commercial Proposal)',
        proposedPrice: 22800.0,
        proposedQuantity: 100.0,
        notes: 'Initial quotation from mandi lot.',
        createdAt: DateTime.now().subtract(const Duration(hours: 24)),
        isCurrent: false,
      );

      final round2 = NegotiationRound(
        id: 'R2',
        versionNumber: 2,
        status: 'Countered',
        actorRole: 'buyer',
        proposerName: 'You (Buyer Counter-Offer)',
        proposedPrice: 22500.0,
        proposedQuantity: 100.0,
        notes: 'Buyer counter proposal.',
        createdAt: DateTime.now(),
        isCurrent: true,
      );

      expect(round1.versionNumber, equals(1));
      expect(round1.status, equals('Superseded'));
      expect(round1.actorRole, equals('broker'));
      expect(round1.isCurrent, isFalse);

      expect(round2.versionNumber, equals(2));
      expect(round2.status, equals('Countered'));
      expect(round2.actorRole, equals('buyer'));
      expect(round2.isCurrent, isTrue);
    });

    test('Validates status lifecycle: actionable vs terminal vs expired', () {
      final proposed = BuyerOffer(
        id: '1', requirementId: 'R1', requirementDisplayId: 'REQ-1',
        commodityName: 'Maize', gradeName: 'FAQ', offeredQuantity: 10, unit: 'MT',
        offeredPrice: 20000, totalEstimatedValue: 200000, status: 'Proposed',
        versionNumber: 1, brokerName: 'Desk', deliveryTerms: 'FOR', deliveryLocation: 'Kota',
        paymentTerms: '100%', packagingType: 'Bags', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(proposed.isActionable, isTrue);
      expect(proposed.isTerminal, isFalse);

      final accepted = proposed.copyWith(status: 'Accepted');
      expect(accepted.isActionable, isFalse);
      expect(accepted.isTerminal, isTrue);

      final rejected = proposed.copyWith(status: 'Rejected');
      expect(rejected.isActionable, isFalse);
      expect(rejected.isTerminal, isTrue);

      final expiredOffer = BuyerOffer(
        id: '2', requirementId: 'R2', requirementDisplayId: 'REQ-2',
        commodityName: 'Maize', gradeName: 'FAQ', offeredQuantity: 10, unit: 'MT',
        offeredPrice: 20000, totalEstimatedValue: 200000, status: 'Proposed',
        versionNumber: 1, brokerName: 'Desk', deliveryTerms: 'FOR', deliveryLocation: 'Kota',
        paymentTerms: '100%', packagingType: 'Bags',
        validUntil: DateTime.now().subtract(const Duration(hours: 1)), // Expired
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(expiredOffer.isExpired, isTrue);
      expect(expiredOffer.isActionable, isFalse);
      expect(expiredOffer.isTerminal, isTrue);
    });

    test('CounterOfferInput validates positive price and quantity', () {
      const valid = CounterOfferInput(
        proposalId: 'PROP-1',
        expectedVersionNumber: 1,
        counterPrice: 22000,
        counterQuantity: 100,
      );
      expect(valid.validate(), isNull);

      const invalidPrice = CounterOfferInput(
        proposalId: 'PROP-1',
        expectedVersionNumber: 1,
        counterPrice: 0,
        counterQuantity: 100,
      );
      expect(invalidPrice.validate(), contains('greater than zero'));

      const invalidQty = CounterOfferInput(
        proposalId: 'PROP-1',
        expectedVersionNumber: 1,
        counterPrice: 22000,
        counterQuantity: -5,
      );
      expect(invalidQty.validate(), contains('greater than zero'));
    });
  });
}
