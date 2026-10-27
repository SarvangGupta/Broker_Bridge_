// RB-SELLER-LAB-PAYMENT-SAFETY-01: a UPI reference alone never verifies payment.
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/lab_testing_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/lab_testing_model.dart';

void main() {
  late LabTestingRepository repo;

  Future<LabTestingRequest> newRequest(String availabilityId) =>
      repo.createTestingRequest(
        availabilityId: availabilityId,
        lotNumber: 'LOT-PAY-1',
        commodityName: 'Wheat Bran',
        selectedTests: LabTestRateCard.standardParameters.take(2).toList(),
      );

  setUp(() {
    LabTestingRepository.clearRegistry();
    LabTestingRepository.allowSandboxVerificationForTests = false;
    repo = LabTestingRepository(
      storage: SecureStorageService()..enableMemoryFallbackForTesting(),
    );
  });

  tearDown(() => LabTestingRepository.allowSandboxVerificationForTests = false);

  group('app builds (sandbox not enabled)', () {
    test('arbitrary UPI reference with simulate=true stays pending', () async {
      final req = await newRequest('avail-1');
      final result = await repo.verifyPaymentWithBackend(
        availabilityId: 'avail-1',
        transactionReference: 'ANY-REF-123',
        simulateSandboxVerification: true,
      );
      expect(result.isPaid, isFalse);
      expect(result.paymentStatus, LabPaymentStatus.paymentPending);
      expect(result.paymentStatus, isNot(LabPaymentStatus.paidVerified));
      expect(result.adminNotified, isFalse);
      expect(result.id, req.id);
    });

    test('the request\'s own reference cannot verify itself either', () async {
      final req = await newRequest('avail-2');
      final result = await repo.verifyPaymentWithBackend(
        availabilityId: 'avail-2',
        transactionReference: req.transactionReference,
        simulateSandboxVerification: true,
      );
      expect(result.isPaid, isFalse);
    });

    test('client-side ledger hook is ignored outside the test sandbox', () async {
      final req = await newRequest('avail-3');
      LabTestingRepository.registerTrustedBackendConfirmation(
        transactionReference: req.transactionReference,
        isSuccess: true,
      );
      final result = await repo.verifyPaymentWithBackend(
        availabilityId: 'avail-3',
        transactionReference: req.transactionReference,
      );
      expect(result.isPaid, isFalse);
    });

    test('unverified payment cannot trigger the paid admin notification', () async {
      final req = await newRequest('avail-4');
      expect(await repo.notifyAdministratorAfterPayment(req), isFalse);
      expect(repo.getRequestForAvailability('avail-4')?.adminNotified, isFalse);
    });

    test('repeated checks stay pending (no drift to verified)', () async {
      await newRequest('avail-5');
      for (var i = 0; i < 3; i++) {
        final r = await repo.verifyPaymentWithBackend(
          availabilityId: 'avail-5',
          transactionReference: 'REF-$i',
          simulateSandboxVerification: true,
        );
        expect(r.isPaid, isFalse);
      }
    });
  });

  group('test sandbox (explicit opt-in, never in release builds)', () {
    setUp(() => LabTestingRepository.allowSandboxVerificationForTests = true);

    test('failed confirmation stays pending', () async {
      final req = await newRequest('avail-6');
      LabTestingRepository.registerTrustedBackendConfirmation(
        transactionReference: req.transactionReference,
        isSuccess: false,
      );
      final r = await repo.verifyPaymentWithBackend(
        availabilityId: 'avail-6',
        transactionReference: req.transactionReference,
        simulateSandboxVerification: true, // ledger result wins
      );
      expect(r.isPaid, isFalse);
    });

    test('a confirmed entry verifies and only then notifies (existing path intact)', () async {
      final req = await newRequest('avail-7');
      LabTestingRepository.registerTrustedBackendConfirmation(
        transactionReference: req.transactionReference,
        isSuccess: true,
      );
      final r = await repo.verifyPaymentWithBackend(
        availabilityId: 'avail-7',
        transactionReference: req.transactionReference,
      );
      expect(r.isPaid, isTrue);
      expect(r.paymentStatus, LabPaymentStatus.paidVerified);
      expect(repo.getRequestForAvailability('avail-7')?.adminNotified, isTrue);
    });
  });
}
