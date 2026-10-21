import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/negotiation/data/negotiation_repository.dart';
import 'package:rmseller_mobile/features/negotiation/domain/negotiation_model.dart';

void main() {
  group('RB-SELLER-03: NegotiationRepository Unit Tests', () {
    late SecureStorageService storage;
    late NegotiationRepository repository;

    const testRequestId = 'AVL-TEST-CHANA-01';
    const testBrokerId = 'b354958e-779a-41f2-b7a3-5899eca32e32';
    const testSellerId = '20000000-0000-0000-0000-000000000001';
    const testCompanyId = '20000000-0000-0000-0000-000000000101';

    setUp(() async {
      storage = SecureStorageService();
      storage.enableMemoryFallbackForTesting();
      await storage.saveUserInfo(
        id: testSellerId,
        role: 'seller',
        email: 'seller@agroenterprises.in',
        fullName: 'Bikaner Agro Commercials',
        companyId: testCompanyId,
      );
      repository = NegotiationRepository(storage: storage);
      NegotiationRepository.clearSessionCache();
    });

    test('sendMessage creates and persists message negotiation event', () async {
      final msg = await repository.sendMessage(
        requestId: testRequestId,
        brokerId: testBrokerId,
        message: 'Namaste Ji, what is the current buyer inquiry level for this lot?',
      );

      expect(msg.id, isNotEmpty);
      expect(msg.requestId, testRequestId);
      expect(msg.messageText, 'Namaste Ji, what is the current buyer inquiry level for this lot?');
      expect(msg.senderRole, 'seller');
      expect(msg.isFromSeller, isTrue);

      final messages = await repository.getMessages(testRequestId);
      expect(messages.length, greaterThanOrEqualTo(1));
      expect(messages.any((m) => m.text == msg.messageText), isTrue);
    });

    test('proposeCommission records proposal and updates commission summary', () async {
      final event = await repository.proposeCommission(
        requestId: testRequestId,
        brokerId: testBrokerId,
        proposedRate: 35.0,
        commissionBasis: '₹/MT',
        note: 'Offering ₹35/MT for quick 3-day dispatch commitment',
      );

      expect(event.actionType, NegotiationActionType.commissionProposal);
      expect(event.payload['proposed_rate'], 35.0);
      expect(event.payload['commission_basis'], '₹/MT');
      expect(event.payload['terms_status'], 'PROPOSED');

      final summary = await repository.getCommissionSummary(testRequestId);
      expect(summary.status, 'Negotiating');
      expect(summary.activeProposedRate, 35.0);
      expect(summary.commissionBasis, '₹/MT');
      expect(summary.hasAgreedTerms, isFalse);
    });

    test('proposeCommission validates positive commission rate', () async {
      expect(
        () => repository.proposeCommission(
          requestId: testRequestId,
          brokerId: testBrokerId,
          proposedRate: 0.0,
          commissionBasis: '₹/MT',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => repository.proposeCommission(
          requestId: testRequestId,
          brokerId: testBrokerId,
          proposedRate: -10.0,
          commissionBasis: '₹/MT',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('respondToCommission with ACCEPT confirms agreed terms', () async {
      // First propose terms
      await repository.proposeCommission(
        requestId: testRequestId,
        brokerId: testBrokerId,
        proposedRate: 40.0,
        commissionBasis: '₹/MT',
        note: 'Broker proposal for Rajasthan mandi',
      );

      // Now accept
      final acceptEvent = await repository.respondToCommission(
        requestId: testRequestId,
        brokerId: testBrokerId,
        responseType: NegotiationActionType.commissionAccept,
        rate: 40.0,
        commissionBasis: '₹/MT',
        counterNote: 'Agreed. Terms confirmed for this delivery lot.',
      );

      expect(acceptEvent.actionType, NegotiationActionType.commissionAccept);
      expect(acceptEvent.payload['terms_status'], 'AGREED');

      final summary = await repository.getCommissionSummary(testRequestId);
      expect(summary.status, 'Agreed');
      expect(summary.agreedRate, 40.0);
      expect(summary.hasAgreedTerms, isTrue);
      expect(summary.effectiveTimestamp, isNotNull);
    });

    test('respondToCommission with COUNTER submits revised terms distinctly', () async {
      // Initial proposal
      await repository.proposeCommission(
        requestId: testRequestId,
        brokerId: testBrokerId,
        proposedRate: 50.0,
        commissionBasis: '₹/MT',
      );

      // Counter proposal with lower rate
      final counterEvent = await repository.respondToCommission(
        requestId: testRequestId,
        brokerId: testBrokerId,
        responseType: NegotiationActionType.commissionCounter,
        rate: 35.0,
        commissionBasis: '₹/MT',
        counterNote: 'Can only afford ₹35/MT due to freight costs',
      );

      expect(counterEvent.actionType, NegotiationActionType.commissionCounter);
      expect(counterEvent.payload['proposed_rate'], 35.0);
      expect(counterEvent.payload['terms_status'], 'COUNTERED');

      final summary = await repository.getCommissionSummary(testRequestId);
      expect(summary.status, 'Negotiating');
      expect(summary.activeProposedRate, 35.0);
      expect(summary.hasAgreedTerms, isFalse);
    });

    test('respondToCommission with REJECT marks status as rejected without agreed rate', () async {
      await repository.proposeCommission(
        requestId: testRequestId,
        brokerId: testBrokerId,
        proposedRate: 80.0,
        commissionBasis: '₹/MT',
      );

      final rejectEvent = await repository.respondToCommission(
        requestId: testRequestId,
        brokerId: testBrokerId,
        responseType: NegotiationActionType.commissionReject,
        rate: 80.0,
        commissionBasis: '₹/MT',
        counterNote: 'Rate too high above standard mandi benchmark',
      );

      expect(rejectEvent.actionType, NegotiationActionType.commissionReject);
      expect(rejectEvent.payload['terms_status'], 'REJECTED');

      final summary = await repository.getCommissionSummary(testRequestId);
      expect(summary.status, 'Rejected');
      expect(summary.hasAgreedTerms, isFalse);
      expect(summary.agreedRate, isNull);
    });

    test('Audit trail preserves timeline of all negotiation events', () async {
      await repository.sendMessage(
        requestId: testRequestId,
        brokerId: testBrokerId,
        message: 'Initial query',
      );

      await repository.proposeCommission(
        requestId: testRequestId,
        brokerId: testBrokerId,
        proposedRate: 45.0,
        commissionBasis: '₹/MT',
      );

      await repository.respondToCommission(
        requestId: testRequestId,
        brokerId: testBrokerId,
        responseType: NegotiationActionType.commissionCounter,
        rate: 38.0,
        commissionBasis: '₹/MT',
      );

      final timeline = await repository.getNegotiationTimeline(testRequestId);
      expect(timeline.length, greaterThanOrEqualTo(2));
      expect(timeline.any((e) => e.actionType == NegotiationActionType.commissionProposal), isTrue);
      expect(timeline.any((e) => e.actionType == NegotiationActionType.commissionCounter), isTrue);
    });
  });
}
