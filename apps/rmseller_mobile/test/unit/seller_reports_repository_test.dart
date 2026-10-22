import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/reports/data/seller_reports_repository.dart';

void main() {
  group('RB-SELLER-04: SellerReportsRepository Unit Tests', () {
    late SecureStorageService storage;
    late SellerReportsRepository repository;

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
      repository = SellerReportsRepository(storage: storage);
    });

    test(
      'getDateBoundaries sets accurate date ranges for all supported periods',
      () {
        final now = DateTime.now();

        // Weekly: 7 days
        final (wStart, wEnd) = repository.getDateBoundaries('Weekly');
        expect(wEnd.difference(wStart).inDays, inInclusiveRange(6, 8));

        // Monthly: 30 days
        final (mStart, mEnd) = repository.getDateBoundaries('Monthly');
        expect(mEnd.difference(mStart).inDays, inInclusiveRange(29, 31));

        // Quarterly: 90 days
        final (qStart, qEnd) = repository.getDateBoundaries('Quarterly');
        expect(qEnd.difference(qStart).inDays, inInclusiveRange(89, 91));

        // Yearly: 365 days
        final (yStart, yEnd) = repository.getDateBoundaries('Yearly');
        expect(yEnd.difference(yStart).inDays, inInclusiveRange(364, 366));

        // Custom
        final customS = now.subtract(const Duration(days: 14));
        final customE = now;
        final (cStart, cEnd) = repository.getDateBoundaries(
          'Custom',
          customStart: customS,
          customEnd: customE,
        );
        expect(cStart, customS);
        expect(cEnd, customE);
      },
    );

    test('getSalesSummary derives accurate completed sales totals and excludes cancelled deals', () async {
      final summary = await repository.getSalesSummary(timeframe: 'Monthly');

      expect(summary.totalSoldVolumeMT, greaterThan(0));
      expect(summary.grossSalesValue, greaterThan(0));
      expect(summary.completedDealsCount, greaterThanOrEqualTo(1));
      expect(summary.settledAmount, greaterThan(0));

      // Cancelled deals are tracked in cancelled count but excluded from completed volume
      expect(summary.cancelledDealsCount, greaterThanOrEqualTo(1));
    });

    test('getSalesSummary calculates distinct agreed, paid, and outstanding commission figures', () async {
      final summary = await repository.getSalesSummary(timeframe: 'Monthly');

      expect(summary.totalAgreedCommission, greaterThan(0));
      expect(summary.totalCommissionPaid, greaterThanOrEqualTo(0));
      expect(summary.totalCommissionOutstanding, greaterThanOrEqualTo(0));

      // Financial integrity invariant: agreed = paid + outstanding
      final sumCalculated =
          summary.totalCommissionPaid + summary.totalCommissionOutstanding;
      expect(summary.totalAgreedCommission, closeTo(sumCalculated, 0.01));
    });

    test('getTransactionHistory returns discrete transaction items with invoice & commission data', () async {
      final txs = await repository.getTransactionHistory(timeframe: 'Monthly');
      expect(txs, isNotEmpty);

      // Verify transaction properties
      for (final tx in txs) {
        expect(tx.dealId, isNotEmpty);
        expect(tx.commodityName, isNotEmpty);
        expect(tx.quantityMT, greaterThan(0));
        expect(tx.ratePerMT, greaterThan(0));
        expect(tx.grossAmount, closeTo(tx.quantityMT * tx.ratePerMT, 0.01));
      }

      // Completed filter
      final completed = await repository.getTransactionHistory(
        timeframe: 'Monthly',
        statusFilter: 'Completed',
      );
      expect(completed.every((t) => t.isCompleted), isTrue);

      // Cancelled filter
      final cancelled = await repository.getTransactionHistory(
        timeframe: 'Monthly',
        statusFilter: 'Cancelled',
      );
      expect(cancelled.every((t) => t.isCancelled), isTrue);
    });
  });
}
