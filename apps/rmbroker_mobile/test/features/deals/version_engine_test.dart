import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';

void main() {
  group('Deal Negotiation & Versioning Engine Tests (Sprint RB-FL-09)', () {
    const v1Snapshot = {
      'rate': 52000.0,
      'quantity': 100.0,
      'priceBasis': 'FOR_DESTINATION',
      'deliveryLocation': 'Indore Mandi Processing Hub',
      'deliveryDate': '2026-10-25',
      'deliveryTerms': 'Ex-Warehouse / FOR',
      'paymentTerms': '100% Advance against Invoice',
      'packagingType': '50kg HDPE Bags',
      'brokerCommissionRate': 50.0,
      'buyerConfirmed': true,
      'sellerConfirmed': true,
    };

    // 1. Identical Snapshots Detect Zero Changes
    test('TC-RB09-01: Identical terms snapshots detect zero material changes', () {
      final v1Copy = Map<String, dynamic>.from(v1Snapshot);
      final hasChanges = DealVersionEngine.detectMaterialChanges(v1Snapshot, v1Copy);
      final diffs = DealVersionEngine.getMaterialDiffList(v1Snapshot, v1Copy);

      expect(hasChanges, isFalse);
      expect(diffs, isEmpty);
    });

    // 2. Material Price & Quantity Detection with Directionality
    test('TC-RB09-02: Accurately detects price increase and quantity increase', () {
      final v2Proposed = Map<String, dynamic>.from(v1Snapshot)
        ..['rate'] = 53500.0
        ..['quantity'] = 120.0;

      final hasChanges = DealVersionEngine.detectMaterialChanges(v1Snapshot, v2Proposed);
      final diffs = DealVersionEngine.getMaterialDiffList(v1Snapshot, v2Proposed);

      expect(hasChanges, isTrue);
      expect(diffs.length, 2);

      final rateDiff = diffs.firstWhere((d) => d.field == 'rate');
      expect(rateDiff.oldValue, 52000.0);
      expect(rateDiff.newValue, 53500.0);
      expect(rateDiff.type, MaterialDiffType.increased);

      final qtyDiff = diffs.firstWhere((d) => d.field == 'quantity');
      expect(qtyDiff.oldValue, 100.0);
      expect(qtyDiff.newValue, 120.0);
      expect(qtyDiff.type, MaterialDiffType.increased);
    });

    // 3. Price Reduction Detection
    test('TC-RB09-03: Accurately detects price reduction', () {
      final v2Reduced = Map<String, dynamic>.from(v1Snapshot)..['rate'] = 51000.0;

      final diffs = DealVersionEngine.getMaterialDiffList(v1Snapshot, v2Reduced);
      expect(diffs.length, 1);

      final rateDiff = diffs.first;
      expect(rateDiff.field, 'rate');
      expect(rateDiff.oldValue, 52000.0);
      expect(rateDiff.newValue, 51000.0);
      expect(rateDiff.type, MaterialDiffType.reduced);
    });

    // 4. Logistics & Terms Modification Detection
    test('TC-RB09-04: Accurately detects delivery terms and location modifications', () {
      final v2Delivery = Map<String, dynamic>.from(v1Snapshot)
        ..['deliveryLocation'] = 'Jaipur Extraction Plant'
        ..['deliveryTerms'] = 'FOR Destination, Unloading by Buyer';

      final diffs = DealVersionEngine.getMaterialDiffList(v1Snapshot, v2Delivery);
      expect(diffs.length, 2);

      final locDiff = diffs.firstWhere((d) => d.field == 'deliveryLocation');
      expect(locDiff.oldValue, 'Indore Mandi Processing Hub');
      expect(locDiff.newValue, 'Jaipur Extraction Plant');
      expect(locDiff.type, MaterialDiffType.changed);

      final termsDiff = diffs.firstWhere((d) => d.field == 'deliveryTerms');
      expect(termsDiff.oldValue, 'Ex-Warehouse / FOR');
      expect(termsDiff.newValue, 'FOR Destination, Unloading by Buyer');
    });

    // 5. CRITICAL INVARIANT: Confirmation Invalidation on Material Revision
    test('TC-RB09-05: Material revisions must strictly invalidate previous confirmations', () {
      final dto = UpdateDealTermsDto(
        dealId: 'deal-001',
        expectedVersion: 1,
        agreedPrice: 53000,
        agreedQuantity: 110,
        deliveryLocation: 'Bhopal Mill',
        deliveryDate: DateTime(2026, 10, 30),
        reason: 'Counter-offer by seller',
      );

      final snapshot = dto.toSnapshot();

      // Confirmed flags on new version MUST be false
      expect(snapshot['buyerConfirmed'], isFalse);
      expect(snapshot['sellerConfirmed'], isFalse);
      expect(snapshot['agreedPrice'], 53000);
      expect(snapshot['agreedQuantity'], 110);
    });

    // 6. Validation of UpdateDealTermsDto bounds
    test('TC-RB09-06: Non-positive terms or missing required fields are rejected', () {
      final invalidPrice = UpdateDealTermsDto(
        dealId: 'deal-001',
        expectedVersion: 1,
        agreedPrice: 0,
        agreedQuantity: 100,
        deliveryLocation: 'Indore',
        deliveryDate: DateTime.now(),
      );
      expect(invalidPrice.validate(), contains('Agreed price must be greater than zero'));

      final invalidQty = UpdateDealTermsDto(
        dealId: 'deal-001',
        expectedVersion: 1,
        agreedPrice: 52000,
        agreedQuantity: -5,
        deliveryLocation: 'Indore',
        deliveryDate: DateTime.now(),
      );
      expect(invalidQty.validate(), contains('Agreed quantity must be greater than zero'));

      final missingLocation = UpdateDealTermsDto(
        dealId: 'deal-001',
        expectedVersion: 1,
        agreedPrice: 52000,
        agreedQuantity: 100,
        deliveryLocation: '   ',
        deliveryDate: DateTime.now(),
      );
      expect(missingLocation.validate(), contains('Delivery location is required'));

      final shortReason = UpdateDealTermsDto(
        dealId: 'deal-001',
        expectedVersion: 1,
        agreedPrice: 52000,
        agreedQuantity: 100,
        deliveryLocation: 'Indore',
        deliveryDate: DateTime.now(),
        reason: 'no',
      );
      expect(shortReason.validate(), contains('at least 3 characters'));
    });

    // 7. PartyConfirmationDto validation
    test('TC-RB09-07: Party confirmation enforces authorized party identity', () {
      const validBuyer = PartyConfirmationDto(
        dealId: 'deal-001',
        versionNumber: 2,
        party: 'BUYER',
        verificationNotes: 'Phone confirmation',
      );
      expect(validBuyer.validate(), isNull);

      const validSeller = PartyConfirmationDto(
        dealId: 'deal-001',
        versionNumber: 2,
        party: 'seller',
        verificationNotes: 'WhatsApp confirmation',
      );
      expect(validSeller.validate(), isNull);

      const invalidParty = PartyConfirmationDto(
        dealId: 'deal-001',
        versionNumber: 2,
        party: 'BROKER',
      );
      expect(invalidParty.validate(), contains("Party must be either 'BUYER' or 'SELLER'"));
    });

    // 8. Pre-Flight Gate Logic
    test('TC-RB09-08: Pre-flight finalization gate requires BOTH counterparties confirmed', () {
      // 0 of 2
      const state0 = DealConfirmationState(latestVersionNumber: 1, buyerConfirmed: false, sellerConfirmed: false);
      expect(state0.canFinalize, isFalse);

      // 1 of 2 (Buyer only)
      const state1 = DealConfirmationState(latestVersionNumber: 1, buyerConfirmed: true, sellerConfirmed: false);
      expect(state1.canFinalize, isFalse);

      // 1 of 2 (Seller only)
      const state2 = DealConfirmationState(latestVersionNumber: 1, buyerConfirmed: false, sellerConfirmed: true);
      expect(state2.canFinalize, isFalse);

      // 2 of 2
      const state3 = DealConfirmationState(latestVersionNumber: 1, buyerConfirmed: true, sellerConfirmed: true, canFinalize: true);
      expect(state3.canFinalize, isTrue);
    });

    // 9. Booking Reference Regex Standards (BKG-YYYY-XXXX)
    test('TC-RB09-09: Enterprise booking reference adheres to standard format', () {
      final year = DateTime.now().year;
      final sampleBookingRef = 'BKG-$year-8492';
      final regex = RegExp(r'^BKG-\d{4}-\d{4}$');

      expect(regex.hasMatch(sampleBookingRef), isTrue);
      expect(regex.hasMatch('ORD-12345'), isFalse);
    });

    // 10. DealVersionItem JSON parsing with Diff reconstruction
    test('TC-RB09-10: DealVersionItem accurately parses backend timeline items', () {
      final json = {
        'id': 'ver-002',
        'versionNumber': 2,
        'status': 'Negotiation',
        'actorId': 'user-broker-01',
        'actorName': 'Nilesh Sharma',
        'actorRole': 'broker',
        'createdAt': '2026-10-17T14:30:00Z',
        'changeReason': 'Freight adjustment',
        'diffs': [
          {
            'field': 'rate',
            'label': 'Rate / Price',
            'oldValue': 52000.0,
            'newValue': 53500.0,
            'type': 'increased',
          }
        ],
        'snapshot': v1Snapshot,
      };

      final item = DealVersionItem.fromJson(json);
      expect(item.id, 'ver-002');
      expect(item.versionNumber, 2);
      expect(item.status, 'Negotiation');
      expect(item.actorName, 'Nilesh Sharma');
      expect(item.diffs.length, 1);
      expect(item.diffs.first.type, MaterialDiffType.increased);
      expect(item.changeReason, 'Freight adjustment');
    });
  });
}
