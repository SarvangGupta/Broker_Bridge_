import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_model.dart';

void main() {
  group('Commission Domain Models & Status Tests (Sprint RB-FL-11)', () {
    test('CommissionStatus parsing and display labels', () {
      expect(CommissionStatus.fromString('not_eligible'), CommissionStatus.notEligible);
      expect(CommissionStatus.fromString('Draft'), CommissionStatus.notEligible);
      expect(CommissionStatus.fromString('accruing'), CommissionStatus.accruing);
      expect(CommissionStatus.fromString('in_progress'), CommissionStatus.accruing);
      expect(CommissionStatus.fromString('eligible'), CommissionStatus.eligible);
      expect(CommissionStatus.fromString('delivered'), CommissionStatus.eligible);
      expect(CommissionStatus.fromString('invoiced'), CommissionStatus.invoiced);
      expect(CommissionStatus.fromString('partially_paid'), CommissionStatus.partiallyPaid);
      expect(CommissionStatus.fromString('part_paid'), CommissionStatus.partiallyPaid);
      expect(CommissionStatus.fromString('paid'), CommissionStatus.paid);
      expect(CommissionStatus.fromString('settled'), CommissionStatus.paid);
      expect(CommissionStatus.fromString('disputed'), CommissionStatus.disputed);
      expect(CommissionStatus.fromString('adjusted'), CommissionStatus.adjusted);
      expect(CommissionStatus.fromString('cancelled'), CommissionStatus.adjusted);
      expect(CommissionStatus.fromString(null), CommissionStatus.notEligible);
    });

    test('CommissionStatus lifecycle capabilities (receivable and canLogPayment)', () {
      expect(CommissionStatus.eligible.isReceivable, isTrue);
      expect(CommissionStatus.invoiced.isReceivable, isTrue);
      expect(CommissionStatus.partiallyPaid.isReceivable, isTrue);
      expect(CommissionStatus.paid.isReceivable, isFalse);
      expect(CommissionStatus.notEligible.isReceivable, isFalse);

      expect(CommissionStatus.invoiced.canLogPayment, isTrue);
      expect(CommissionStatus.partiallyPaid.canLogPayment, isTrue);
      expect(CommissionStatus.eligible.canLogPayment, isTrue);
      expect(CommissionStatus.paid.canLogPayment, isFalse);
    });

    test('CommissionQuantityBreakdown keeps 6 physical quantity tiers distinct', () {
      const breakdown = CommissionQuantityBreakdown(
        contractedQuantity: 100.0,
        dispatchedQuantity: 80.0,
        deliveredQuantity: 70.0,
        acceptedQuantity: 60.0,
        rejectedQuantity: 5.0,
        disputedQuantity: 5.0,
        unitSymbol: 'MT',
      );

      expect(breakdown.contractedQuantity, 100.0);
      expect(breakdown.dispatchedQuantity, 80.0);
      expect(breakdown.deliveredQuantity, 70.0);
      expect(breakdown.acceptedQuantity, 60.0);
      expect(breakdown.rejectedQuantity, 5.0);
      expect(breakdown.disputedQuantity, 5.0);
      expect(breakdown.eligibleDeliveredQuantity, 60.0);
    });

    test('Disputed and rejected quantities are strictly excluded from eligible delivered quantity', () {
      const breakdown = CommissionQuantityBreakdown(
        contractedQuantity: 200.0,
        dispatchedQuantity: 150.0,
        deliveredQuantity: 150.0,
        acceptedQuantity: 0.0, // not pre-set, derived
        rejectedQuantity: 20.0,
        disputedQuantity: 30.0,
        unitSymbol: 'MT',
      );

      // delivered (150) - rejected (20) - disputed (30) = 100 MT eligible
      expect(breakdown.eligibleDeliveredQuantity, 100.0);
      expect(breakdown.eligibleDeliveredQuantityMT, 100.0);
    });

    test('Unit conversion factors normalize Quintals and Kg accurately to MT', () {
      // 500 Quintals = 50 MT
      const qtlBreakdown = CommissionQuantityBreakdown(
        contractedQuantity: 500.0,
        deliveredQuantity: 500.0,
        acceptedQuantity: 500.0,
        unitSymbol: 'Quintals',
      );
      expect(qtlBreakdown.conversionFactorToMT, 0.1);
      expect(qtlBreakdown.eligibleDeliveredQuantityMT, 50.0);

      // 25,000 Kg = 25 MT
      const kgBreakdown = CommissionQuantityBreakdown(
        contractedQuantity: 25000.0,
        deliveredQuantity: 25000.0,
        acceptedQuantity: 25000.0,
        unitSymbol: 'Kg',
      );
      expect(kgBreakdown.conversionFactorToMT, 0.001);
      expect(kgBreakdown.eligibleDeliveredQuantityMT, 25.0);
    });

    test('CommissionRecord serializes and deserializes accurately with calculation formula', () {
      final now = DateTime.now();
      final record = CommissionRecord(
        dealId: 'deal-999',
        dealReference: 'DL-999',
        bookingReference: 'BK-999',
        commodityName: 'Yellow Mustard',
        gradeName: 'FAQ',
        buyerCompanyName: 'Buyer Mandate',
        sellerCompanyName: 'Seller Lot',
        agreedRatePerMT: 50.0,
        commissionBasis: '₹/MT',
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 100.0,
          deliveredQuantity: 40.0,
          acceptedQuantity: 40.0,
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 2160000.0,
        calculatedCommission: 5000.0,
        eligibleCommission: 2000.0,
        invoicedAmount: 2000.0,
        paidAmount: 1000.0,
        outstandingAmount: 1000.0,
        disputedAmount: 0.0,
        status: CommissionStatus.partiallyPaid,
        createdAt: now,
        updatedAt: now,
      );

      expect(record.calculationFormula, '40 MT × ₹50.00/MT = ₹2000.00');

      final json = record.toJson();
      expect(json['dealId'], 'deal-999');
      expect(json['status'], 'partially_paid');
      expect(json['eligibleCommission'], 2000.0);

      final deserialized = CommissionRecord.fromJson(json);
      expect(deserialized.dealId, 'deal-999');
      expect(deserialized.eligibleCommission, 2000.0);
      expect(deserialized.outstandingAmount, 1000.0);
      expect(deserialized.status, CommissionStatus.partiallyPaid);
    });

    test('CommissionSummary accurately aggregates multi-deal metrics and isolates trade turnover', () {
      final now = DateTime.now();
      final records = [
        CommissionRecord(
          dealId: '1',
          dealReference: 'DL-1',
          commodityName: 'Wheat',
          buyerCompanyName: 'Buyer A',
          sellerCompanyName: 'Seller A',
          agreedRatePerMT: 50.0,
          quantities: const CommissionQuantityBreakdown(
            contractedQuantity: 100.0,
            deliveredQuantity: 100.0,
            acceptedQuantity: 100.0,
          ),
          grossRawMaterialValue: 2650000.0,
          calculatedCommission: 5000.0,
          eligibleCommission: 5000.0,
          invoicedAmount: 5000.0,
          paidAmount: 5000.0,
          outstandingAmount: 0.0,
          disputedAmount: 0.0,
          status: CommissionStatus.paid,
          createdAt: now,
          updatedAt: now,
        ),
        CommissionRecord(
          dealId: '2',
          dealReference: 'DL-2',
          commodityName: 'Mustard',
          buyerCompanyName: 'Buyer B',
          sellerCompanyName: 'Seller B',
          agreedRatePerMT: 60.0,
          quantities: const CommissionQuantityBreakdown(
            contractedQuantity: 100.0,
            deliveredQuantity: 50.0,
            acceptedQuantity: 50.0,
          ),
          grossRawMaterialValue: 2700000.0,
          calculatedCommission: 6000.0,
          eligibleCommission: 3000.0,
          invoicedAmount: 3000.0,
          paidAmount: 1000.0,
          outstandingAmount: 2000.0,
          disputedAmount: 0.0,
          status: CommissionStatus.partiallyPaid,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = CommissionSummary.fromRecords(records, period: 'This Month');

      expect(summary.totalDealsCount, 2);
      expect(summary.totalEligibleCommission, 8000.0); // 5000 + 3000
      expect(summary.totalInvoicedCommission, 8000.0);
      expect(summary.totalReceivedCommission, 6000.0); // 5000 + 1000
      expect(summary.totalOutstandingCommission, 2000.0);
      expect(summary.totalEligibleQuantityMT, 150.0); // 100 + 50
      expect(summary.totalGrossDealValuation, 5350000.0); // 26.5L + 27.0L (Trade turnover)
    });

    test('LogPaymentDto validates deal reference, positive amount, and UTR length', () {
      final validDto = LogPaymentDto(
        dealId: 'deal-001',
        amount: 5000.0,
        referenceNumber: 'UTR-HDFC-100293',
        paymentDate: DateTime.now(),
      );
      expect(validDto.validate(), isNull);

      final zeroAmtDto = LogPaymentDto(
        dealId: 'deal-001',
        amount: 0.0,
        referenceNumber: 'UTR-HDFC-100293',
        paymentDate: DateTime.now(),
      );
      expect(zeroAmtDto.validate(), contains('greater than zero'));

      final shortRefDto = LogPaymentDto(
        dealId: 'deal-001',
        amount: 1000.0,
        referenceNumber: 'UTR',
        paymentDate: DateTime.now(),
      );
      expect(shortRefDto.validate(), contains('at least 4 characters'));

      final emptyDealDto = LogPaymentDto(
        dealId: '',
        amount: 1000.0,
        referenceNumber: 'UTR-1234',
        paymentDate: DateTime.now(),
      );
      expect(emptyDealDto.validate(), contains('Deal ID is required'));
    });
  });
}
