import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_negotiation_model.dart';

void main() {
  group('Requirement Negotiation & Proposal Domain Tests (RB-NEG-CRASH-01)', () {
    test('NegotiationRoundItem parses broker and buyer rounds accurately', () {
      final brokerRoundJson = {
        'id': 'ver-101',
        'versionNumber': 1,
        'status': 'Proposed to Buyer',
        'actorRole': 'broker',
        'proposedPrice': 5100.0,
        'proposedQuantity': 100.0,
        'deliveryDate': '2026-11-01',
        'paymentTerms': 'CAD against Invoice',
        'packaging': '50kg PP Bags',
        'notes': 'Offered rate aligned with local mandi spot arrivals.',
        'createdAt': '2026-10-20T08:00:00.000Z',
      };

      final round = NegotiationRoundItem.fromJson(brokerRoundJson, isCurrent: true);

      expect(round.id, 'ver-101');
      expect(round.roundNumber, 1);
      expect(round.isBroker, isTrue);
      expect(round.senderRole, 'broker');
      expect(round.proposedPrice, 5100.0);
      expect(round.proposedQuantity, 100.0);
      expect(round.deliveryDate, '2026-11-01');
      expect(round.paymentTerms, 'CAD against Invoice');
      expect(round.packaging, '50kg PP Bags');
      expect(round.notes, contains('local mandi spot arrivals'));
      expect(round.isCurrent, isTrue);
    });

    test('RequirementNegotiationData correctly tracks active proposal and prior rounds', () {
      final json = {
        'details': {
          'requirementId': 'req-abc-123',
          'requestId': 'req-abc-123',
          'currentVersionNumber': 2,
          'currentStatus': 'Proposed to Buyer',
          'offeredPrice': 5200.0,
          'proposedQuantity': 75.0,
          'unitSymbol': 'MT',
          'deliveryTerms': 'FOR Mill Gate',
        },
        'timeline': [
          {
            'versionNumber': 1,
            'actorRole': 'broker',
            'proposedPrice': 5300.0,
            'proposedQuantity': 75.0,
            'status': 'Superseded',
            'createdAt': '2026-10-19T10:00:00.000Z',
          },
          {
            'versionNumber': 2,
            'actorRole': 'broker',
            'proposedPrice': 5200.0,
            'proposedQuantity': 75.0,
            'status': 'Proposed to Buyer',
            'createdAt': '2026-10-20T10:00:00.000Z',
          },
        ],
      };

      final data = RequirementNegotiationData.fromJson(json);

      expect(data.requirementId, 'req-abc-123');
      expect(data.currentVersionNumber, 2);
      expect(data.currentStatus, 'Proposed to Buyer');
      expect(data.rounds.length, 2);
      expect(data.hasPriorProposals, isTrue);
      expect(data.activeProposal, isNotNull);
      expect(data.activeProposal!.proposedPrice, 5200.0);
      expect(data.activeProposal!.roundNumber, 2);
    });

    test('RequirementItem status handles negotiation and proposal state correctly', () {
      final json = {
        'id': 'req-999',
        'requirement_ref': 'REQ-2026-999',
        'company_id': 'comp-1',
        'buyer_company_name': 'Test Buyer',
        'buyer_company_verified': true,
        'buyer_trust_score': 90,
        'commodity_id': 'comm-1',
        'commodity_name': 'Soybean',
        'grade_id': 'grd-1',
        'grade_name': 'Yellow Soybean',
        'quantity': 50.0,
        'remaining_quantity': 50.0,
        'unit_symbol': 'MT',
        'unit_name': 'MT',
        'target_price': 5000.0,
        'delivery_terms': 'FOR Destination',
        'target_date': '2026-11-15T00:00:00.000Z',
        'status': 'Proposed to Buyer',
        'raw_status': 'Proposed to Buyer',
        'broker_id': 'b354958e-779a-41f2-b7a3-5899eca32e32',
        'created_at': '2026-10-20T00:00:00.000Z',
      };

      final req = RequirementItem.fromJson(json);

      expect(req.id, 'req-999');
      expect(req.brokerId, 'b354958e-779a-41f2-b7a3-5899eca32e32');
      expect(req.isProposed, isTrue);
      expect(req.displayStatus, 'Proposed to Buyer');
    });
  });
}
