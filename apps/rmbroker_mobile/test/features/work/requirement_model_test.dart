import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';

void main() {
  group('Requirement Domain Models & Lifecycle Tests (Sprint RB-FL-07)', () {
    test('RequirementStatus parsing and display labels', () {
      expect(RequirementStatus.fromString('new'), RequirementStatus.open);
      expect(RequirementStatus.fromString('open'), RequirementStatus.open);
      expect(RequirementStatus.fromString('matching'), RequirementStatus.matching);
      expect(RequirementStatus.fromString('partially allocated'), RequirementStatus.partiallyAllocated);
      expect(RequirementStatus.fromString('fully allocated'), RequirementStatus.fullyAllocated);
      expect(RequirementStatus.fromString('fulfilled'), RequirementStatus.fulfilled);
      expect(RequirementStatus.fromString('expired'), RequirementStatus.expired);
      expect(RequirementStatus.fromString('cancelled'), RequirementStatus.cancelled);
      expect(RequirementStatus.fromString('unknown_status'), RequirementStatus.open);
    });

    test('Expired and Cancelled requirements are explicitly blocked from matching', () {
      // Active statuses
      expect(RequirementStatus.open.isEligibleForMatching, isTrue);
      expect(RequirementStatus.matching.isEligibleForMatching, isTrue);
      expect(RequirementStatus.partiallyAllocated.isEligibleForMatching, isTrue);

      // Terminal or non-matchable statuses
      expect(RequirementStatus.fullyAllocated.isEligibleForMatching, isFalse);
      expect(RequirementStatus.fulfilled.isEligibleForMatching, isFalse);
      expect(RequirementStatus.expired.isEligibleForMatching, isFalse);
      expect(RequirementStatus.cancelled.isEligibleForMatching, isFalse);
    });

    test('Separated 7-tier quantities parsing from backend JSON', () {
      final json = {
        'id': 'req-101',
        'requirement_ref': 'REQ-2026-0042',
        'company_id': 'buyer-1',
        'buyer_company_name': 'AgrInnovate Flour Mills',
        'buyer_company_verified': true,
        'buyer_trust_score': 95,
        'commodity_id': 'comm-wheat',
        'commodity_name': 'Sharbati Wheat',
        'grade_id': 'grade-a',
        'grade_name': 'Grade A Milling',
        'quantity': 100.0,
        'fulfilled_quantity': 25.0,
        'contracted_quantity': 20.0,
        'delivered_quantity': 15.0,
        'accepted_quantity': 15.0,
        'disputed_quantity': 2.0,
        'remaining_quantity': 75.0,
        'unit_symbol': 'MT',
        'unit_name': 'Metric Tonne',
        'target_price': 2850.0,
        'delivery_terms': 'FOR Jaipur Warehouse',
        'target_date': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        'status': 'Partially Allocated',
        'notes': 'Moisture strictly under 11.5%',
        'created_at': '2026-10-15T10:00:00.000Z',
      };

      final req = RequirementItem.fromJson(json);

      expect(req.id, 'req-101');
      expect(req.ref, 'REQ-2026-0042');
      expect(req.buyerCompanyName, 'AgrInnovate Flour Mills');
      expect(req.commodityName, 'Sharbati Wheat');
      expect(req.gradeName, 'Grade A Milling');

      // Verify all 7 quantities remain completely distinct
      expect(req.requestedQuantity, 100.0);
      expect(req.allocatedQuantity, 25.0);
      expect(req.contractedQuantity, 20.0);
      expect(req.deliveredQuantity, 15.0);
      expect(req.acceptedQuantity, 15.0);
      expect(req.disputedQuantity, 2.0);
      expect(req.remainingQuantity, 75.0);

      expect(req.unitSymbol, 'MT');
      expect(req.targetPrice, 2850.0);
      expect(req.deliveryTerms, 'FOR Jaipur Warehouse');
      expect(req.status, RequirementStatus.partiallyAllocated);
      expect(req.canBeMatched, isTrue);
      expect(req.fulfillmentPercentage, 25);
    });

    test('CreateRequirementDto validation ensures quantity, price, and required fields', () {
      final validDto = CreateRequirementDto(
        companyId: 'buyer-001',
        commodityId: 'comm-001',
        gradeId: 'grade-001',
        quantity: 50.0,
        unitId: 'unit-mt',
        targetPrice: 2400.0,
        deliveryTerms: 'Ex-Mandi',
        targetDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(validDto.validate(), isNull);

      final zeroQtyDto = CreateRequirementDto(
        companyId: 'buyer-001',
        commodityId: 'comm-001',
        gradeId: 'grade-001',
        quantity: 0.0,
        unitId: 'unit-mt',
        targetPrice: 2400.0,
        deliveryTerms: 'Ex-Mandi',
        targetDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(zeroQtyDto.validate(), contains('greater than zero'));

      final zeroPriceDto = CreateRequirementDto(
        companyId: 'buyer-001',
        commodityId: 'comm-001',
        gradeId: 'grade-001',
        quantity: 50.0,
        unitId: 'unit-mt',
        targetPrice: 0.0,
        deliveryTerms: 'Ex-Mandi',
        targetDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(zeroPriceDto.validate(), contains('Target price'));

      final emptyTermsDto = CreateRequirementDto(
        companyId: 'buyer-001',
        commodityId: 'comm-001',
        gradeId: 'grade-001',
        quantity: 50.0,
        unitId: 'unit-mt',
        targetPrice: 2500.0,
        deliveryTerms: '   ',
        targetDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(emptyTermsDto.validate(), contains('Delivery terms'));
    });
  });
}
