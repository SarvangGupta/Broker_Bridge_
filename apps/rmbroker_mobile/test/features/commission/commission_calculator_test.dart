import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_calculator.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_model.dart';

void main() {
  group('CommissionCalculator Pure Mathematics & Conversion Tests (Sprint RB-FL-11)', () {
    test('Formula: Commission = eligible delivered quantity (MT) × agreed rate per MT', () {
      final commission = CommissionCalculator.calculateCommission(
        eligibleDeliveredQuantityMT: 100.0,
        agreedRatePerMT: 50.0,
      );
      expect(commission, 5000.0);

      // Decimal quantities (e.g. 42.75 MT @ ₹55.50/MT)
      final decimalComm = CommissionCalculator.calculateCommission(
        eligibleDeliveredQuantityMT: 42.75,
        agreedRatePerMT: 55.50,
      );
      // 42.75 * 55.50 = 2372.625 -> 2372.63
      expect(decimalComm, 2372.63);
    });

    test('Zero or negative quantity yields exactly 0.0 commission', () {
      expect(
        CommissionCalculator.calculateCommission(
          eligibleDeliveredQuantityMT: 0.0,
          agreedRatePerMT: 50.0,
        ),
        0.0,
      );
      expect(
        CommissionCalculator.calculateCommission(
          eligibleDeliveredQuantityMT: -10.0,
          agreedRatePerMT: 50.0,
        ),
        0.0,
      );
    });

    test('Partial fulfillment: calculates eligible delivered quantity correctly after deductions', () {
      // Contracted 200 MT, Dispatched 120 MT, Delivered 120 MT, 5 MT rejected, 15 MT disputed
      final eligibleQty = CommissionCalculator.calculateEligibleQuantity(
        deliveredQuantity: 120.0,
        rejectedQuantity: 5.0,
        disputedQuantity: 15.0,
      );
      expect(eligibleQty, 100.0);

      final commission = CommissionCalculator.calculateCommission(
        eligibleDeliveredQuantityMT: eligibleQty,
        agreedRatePerMT: 60.0,
      );
      // 100 MT * ₹60 = ₹6,000 (NOT 200 MT * ₹60 = ₹12,000, and NOT 120 MT * ₹60 = ₹7,200)
      expect(commission, 6000.0);
    });

    test('Accepted quantity explicitly overrides default delivered deductions if provided', () {
      final eligibleQty = CommissionCalculator.calculateEligibleQuantity(
        deliveredQuantity: 100.0,
        acceptedQuantity: 92.5,
        rejectedQuantity: 5.0,
        disputedQuantity: 2.5,
      );
      expect(eligibleQty, 92.5);
    });

    test('Quintal-based agreed rate conversion (1 MT = 10 Quintals)', () {
      // If agreement specifies ₹5 per quintal, rate per MT is ₹50/MT
      final commission = CommissionCalculator.calculateCommissionFromQuintalRate(
        eligibleDeliveredQuantityMT: 20.0,
        ratePerQuintal: 5.0,
      );
      // 20 MT * (5 * 10) = 20 * 50 = ₹1,000
      expect(commission, 1000.0);
    });

    test('Unit normalization converts Quintals and Kg accurately to MT', () {
      expect(CommissionCalculator.normalizeToMT(100.0, 'MT'), 100.0);
      expect(CommissionCalculator.normalizeToMT(250.0, 'Quintal'), 25.0);
      expect(CommissionCalculator.normalizeToMT(250.0, 'Qtl'), 25.0);
      expect(CommissionCalculator.normalizeToMT(50000.0, 'Kg'), 50.0);
      expect(CommissionCalculator.normalizeToMT(0.0, 'MT'), 0.0);
    });

    test('Outstanding commission calculation preserves floor at 0.0', () {
      expect(
        CommissionCalculator.calculateOutstanding(
          totalReceivable: 5000.0,
          totalPaid: 2000.0,
        ),
        3000.0,
      );
      // Overpaid / rounded payments never produce negative outstanding balance
      expect(
        CommissionCalculator.calculateOutstanding(
          totalReceivable: 5000.0,
          totalPaid: 5000.50,
        ),
        0.0,
      );
    });

    test('Commission status determination rules follow strict approved business flow', () {
      // 1. Cancelled
      expect(
        CommissionCalculator.determineCommissionStatus(
          eligibleDeliveredQuantityMT: 100.0,
          invoicedAmount: 5000.0,
          paidAmount: 0.0,
          disputedQuantityMT: 0.0,
          isCancelled: true,
        ),
        CommissionStatus.adjusted,
      );

      // 2. Disputed: Disputed > 0 and 0 eligible delivered
      expect(
        CommissionCalculator.determineCommissionStatus(
          eligibleDeliveredQuantityMT: 0.0,
          invoicedAmount: 0.0,
          paidAmount: 0.0,
          disputedQuantityMT: 50.0,
        ),
        CommissionStatus.disputed,
      );

      // 3. Paid: Fully paid
      expect(
        CommissionCalculator.determineCommissionStatus(
          eligibleDeliveredQuantityMT: 100.0,
          invoicedAmount: 5000.0,
          paidAmount: 5000.0,
          disputedQuantityMT: 0.0,
        ),
        CommissionStatus.paid,
      );

      // 4. Partially Paid: Partial payment received
      expect(
        CommissionCalculator.determineCommissionStatus(
          eligibleDeliveredQuantityMT: 100.0,
          invoicedAmount: 5000.0,
          paidAmount: 2500.0,
          disputedQuantityMT: 0.0,
        ),
        CommissionStatus.partiallyPaid,
      );

      // 5. Invoiced: Invoiced but no payment yet
      expect(
        CommissionCalculator.determineCommissionStatus(
          eligibleDeliveredQuantityMT: 100.0,
          invoicedAmount: 5000.0,
          paidAmount: 0.0,
          disputedQuantityMT: 0.0,
        ),
        CommissionStatus.invoiced,
      );

      // 6. Eligible: Delivered & accepted but not yet invoiced
      expect(
        CommissionCalculator.determineCommissionStatus(
          eligibleDeliveredQuantityMT: 100.0,
          invoicedAmount: 0.0,
          paidAmount: 0.0,
          disputedQuantityMT: 0.0,
        ),
        CommissionStatus.eligible,
      );

      // 7. Not Eligible: 0 delivered
      expect(
        CommissionCalculator.determineCommissionStatus(
          eligibleDeliveredQuantityMT: 0.0,
          invoicedAmount: 0.0,
          paidAmount: 0.0,
          disputedQuantityMT: 0.0,
        ),
        CommissionStatus.notEligible,
      );
    });

    test('Indian currency format uses Rupee symbol and Indian numerical comma grouping', () {
      expect(CommissionCalculator.formatCurrency(500.0), '₹500.00');
      expect(CommissionCalculator.formatCurrency(5000.0), '₹5,000.00');
      expect(CommissionCalculator.formatCurrency(50000.0), '₹50,000.00');
      expect(CommissionCalculator.formatCurrency(2650000.0), '₹26,50,000.00');
      expect(CommissionCalculator.formatCurrency(0.0), '₹0.00');
    });

    test('Fiduciary Rule: Broker commission is strictly isolated from gross raw-material turnover', () {
      const contractedQty = 100.0; // MT
      const commodityPricePerMT = 54000.0; // ₹54,000 / MT
      final grossDealTurnover = contractedQty * commodityPricePerMT; // ₹54,00,000 (Gross Trade)

      const agreedBrokerCommissionRate = 50.0; // ₹50 / MT
      final brokerCommission = CommissionCalculator.calculateCommission(
        eligibleDeliveredQuantityMT: contractedQty,
        agreedRatePerMT: agreedBrokerCommissionRate,
      ); // ₹5,000 (Brokerage)

      // Guarantee trade value != broker income
      expect(grossDealTurnover, 5400000.0);
      expect(brokerCommission, 5000.0);
      expect(brokerCommission, isNot(equals(grossDealTurnover)));
      expect(brokerCommission / grossDealTurnover, closeTo(0.000925, 0.00001));
    });
  });
}
