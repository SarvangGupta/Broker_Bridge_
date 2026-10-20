import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/deals/domain/final_deal_review_model.dart';

void main() {
  group('RB-BUYER-06: FinalDealReview Domain Models & Privacy Unit Tests', () {
    test('Scenario 1: FinalDealReviewData serialization & deserialization preserves commercial precision', () {
      final map = {
        'dealId': 'DEAL-2026-TEST-001',
        'requestId': 'REQ-2026-TEST-001',
        'requirementDisplayId': 'REQ-2026-062',
        'status': 'Awaiting Buyer Confirmation',
        'rawStatus': 'Awaiting Buyer Confirmation',
        'versionNumber': 2,
        'hasPreviousVersion': true,
        'previousVersionNumber': 1,
        'currentTerms': {
          'commodityName': 'Yellow Maize / Corn',
          'gradeName': 'Grade-A Poultry Feed',
          'quantity': 250.0,
          'unitSymbol': 'MT',
          'basePricePerUnit': 24200.0,
          'netLandedPricePerUnit': 24260.0,
          'totalEstimatedValue': 6065000.0,
          'applicableCharges': [
            {
              'name': 'Brokerage & Facilitation Fee',
              'rate': 35.0,
              'amount': 8750.0,
              'type': 'per_unit',
              'description': 'Broker desk mediation fee',
              'includedInLandedPrice': true,
            },
          ],
          'totalChargesPerUnit': 60.0,
          'deliveryLocation': 'Khanna Industrial Area, Ludhiana, Punjab',
          'paymentTerms': '100% Against Delivery via Escrow',
          'packagingType': '50kg HDPE Bags',
          'freightTerms': 'FOR Destination',
          'inspectionRequirements': 'NABL Accredited Third-Party Lab Testing',
          'qualityParameters': [
            {
              'parameterName': 'Moisture Content',
              'targetValue': '12.0',
              'tolerance': 'Max 12.5%',
              'unit': '%',
              'isMandatory': true,
            },
          ],
        },
        'brokerName': 'Rajesh Sharma',
        'brokerAgency': 'BrokerBridge Desk',
        'brokerNotes': 'Final negotiated terms aligned.',
        'snapshotTimestamp': '2026-10-20T10:00:00.000Z',
        'createdAt': '2026-10-19T10:00:00.000Z',
        'updatedAt': '2026-10-20T10:00:00.000Z',
      };

      final data = FinalDealReviewData.fromMap(map);

      expect(data.dealId, 'DEAL-2026-TEST-001');
      expect(data.versionNumber, 2);
      expect(data.hasPreviousVersion, isTrue);
      expect(data.previousVersionNumber, 1);
      expect(data.status, DealConfirmationStatus.awaitingBuyerConfirmation);
      expect(data.isConfirmable, isTrue);
      expect(data.isConfirmed, isFalse);

      expect(data.currentTerms.commodityName, 'Yellow Maize / Corn');
      expect(data.currentTerms.quantity, 250.0);
      expect(data.currentTerms.basePricePerUnit, 24200.0);
      expect(data.currentTerms.netLandedPricePerUnit, 24260.0);
      expect(data.currentTerms.totalEstimatedValue, 6065000.0);
      expect(data.currentTerms.applicableCharges.length, 1);
      expect(data.currentTerms.qualityParameters.length, 1);
      expect(data.currentTerms.qualityParameters.first.isMandatory, isTrue);

      final serialized = data.toMap();
      expect(serialized['dealId'], 'DEAL-2026-TEST-001');
      expect(serialized['versionNumber'], 2);
    });

    test('Scenario 2: Strict Counterparty Shield confirms zero seller exposure', () {
      final mapWithAttemptedLeakage = {
        'dealId': 'DEAL-2026-TEST-002',
        'requestId': 'REQ-2026-TEST-002',
        'requirementDisplayId': 'REQ-2026-063',
        'status': 'Awaiting Buyer Confirmation',
        'versionNumber': 1,
        'currentTerms': {
          'commodityName': 'Mustard Seeds',
          'gradeName': '42% Oil',
          'quantity': 50.0,
          'unitSymbol': 'MT',
          'basePricePerUnit': 5600.0,
          'netLandedPricePerUnit': 5660.0,
          'totalEstimatedValue': 283000.0,
          'applicableCharges': [],
          'totalChargesPerUnit': 60.0,
          'deliveryLocation': 'Kota Mandi',
          'paymentTerms': 'Cash on Delivery',
          'packagingType': 'Bags',
          'freightTerms': 'Ex-Mill',
          'inspectionRequirements': 'Lab QA',
          'qualityParameters': [],
        },
        'brokerName': 'Kota Desk',
        'brokerAgency': 'Kota Brokerage',
        // Injected unauthorized seller fields
        'seller_id': 'seller-secret-999',
        'seller_name': 'Private Producer Ltd',
        'seller_phone': '+91-9876543210',
        'seller_whatsapp': '+91-9876543210',
        'seller_location': 'Private Farm, Mandi Yard 4',
      };

      final data = FinalDealReviewData.fromMap(mapWithAttemptedLeakage);
      final serialized = data.toMap();

      // Serialized buyer map must NEVER contain seller identifiers or contact info
      expect(serialized.containsKey('seller_id'), isFalse);
      expect(serialized.containsKey('seller_name'), isFalse);
      expect(serialized.containsKey('seller_phone'), isFalse);
      expect(serialized.containsKey('seller_whatsapp'), isFalse);
      expect(serialized.containsKey('seller_location'), isFalse);
      expect(serialized['brokerName'], 'Kota Desk');
    });

    test('Scenario 3: ConfirmDealInput validation enforces dealId, version, and explicit confirmation', () {
      // Missing dealId
      expect(
        () => const ConfirmDealInput(
          dealId: '',
          expectedVersion: 1,
          buyerConfirmed: true,
        ).validate(),
        throwsArgumentError,
      );

      // Invalid version sequence
      expect(
        () => const ConfirmDealInput(
          dealId: 'DEAL-001',
          expectedVersion: 0,
          buyerConfirmed: true,
        ).validate(),
        throwsArgumentError,
      );

      // Unchecked agreement
      expect(
        () => const ConfirmDealInput(
          dealId: 'DEAL-001',
          expectedVersion: 1,
          buyerConfirmed: false,
        ).validate(),
        throwsArgumentError,
      );

      // Valid input passes
      expect(
        () => const ConfirmDealInput(
          dealId: 'DEAL-001',
          expectedVersion: 2,
          buyerConfirmed: true,
        ).validate(),
        returnsNormally,
      );
    });

    test('Scenario 4: RequestAmendmentInput validation requires non-empty dealId and min 5 chars reason', () {
      // Reason too short
      expect(
        () => const RequestAmendmentInput(
          dealId: 'DEAL-001',
          expectedVersion: 1,
          reason: 'No',
        ).validate(),
        throwsArgumentError,
      );

      // Empty dealId
      expect(
        () => const RequestAmendmentInput(
          dealId: '',
          expectedVersion: 1,
          reason: 'Please revise rate to 24000',
        ).validate(),
        throwsArgumentError,
      );

      // Valid input
      expect(
        () => const RequestAmendmentInput(
          dealId: 'DEAL-001',
          expectedVersion: 2,
          reason: 'Please change delivery schedule to next week.',
        ).validate(),
        returnsNormally,
      );
    });

    test('Scenario 5: DealConfirmationStatus enum handles all authoritative status variations', () {
      expect(DealConfirmationStatus.fromString('Awaiting Buyer Confirmation'),
          DealConfirmationStatus.awaitingBuyerConfirmation);
      expect(DealConfirmationStatus.fromString('Buyer Confirmed'),
          DealConfirmationStatus.buyerConfirmed);
      expect(DealConfirmationStatus.fromString('Confirmed'),
          DealConfirmationStatus.confirmed);
      expect(DealConfirmationStatus.fromString('Accepted (Booked)'),
          DealConfirmationStatus.confirmed);
      expect(DealConfirmationStatus.fromString('Amendment Required'),
          DealConfirmationStatus.amendmentRequired);
      expect(DealConfirmationStatus.fromString('Expired'),
          DealConfirmationStatus.expired);
      expect(DealConfirmationStatus.fromString(null),
          DealConfirmationStatus.awaitingBuyerConfirmation);
    });
  });
}
