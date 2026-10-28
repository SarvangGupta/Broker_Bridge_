import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_bank_details.dart';

void main() {
  group('RB-SELLER-PROFILE-INVOICE-01: SellerBankDetails Unit Tests', () {
    test('1. Default bank details are strictly unverified and unconfigured', () {
      const bank = SellerBankDetails();
      expect(bank.isConfigured, isFalse);
      expect(bank.isVerified, isFalse);
      expect(bank.verificationStatus, 'unverified');
      expect(bank.accountNumber, isEmpty);
      expect(bank.ifscCode, isEmpty);
    });

    test('2. Ordinary view masking correctly masks account numbers', () {
      const bank = SellerBankDetails(
        accountHolderName: 'Ramesh Agro Traders',
        bankName: 'State Bank of India',
        accountNumber: '123456789012',
        ifscCode: 'SBIN0001234',
      );
      expect(bank.maskedAccountNumber, contains('••••'));
      expect(bank.maskedAccountNumber.endsWith('9012'), isTrue);
      expect(bank.maskedAccountNumber.contains('12345678'), isFalse);
    });

    test('3. Safe audit display never leaks full account number', () {
      const bank = SellerBankDetails(
        bankName: 'HDFC Bank',
        accountNumber: '98765432109876',
        ifscCode: 'HDFC0000123',
      );
      final audit = bank.safeAuditDisplay;
      expect(audit, contains('...9876'));
      expect(audit, contains('HDFC Bank'));
      expect(audit, contains('HDFC0000123'));
      expect(audit.contains('9876543210'), isFalse);
    });

    test('4. Strict IFSC validation rejects invalid patterns and accepts valid format', () {
      expect(SellerBankDetails.validateIfsc('SBIN0001234'), isNull);
      expect(SellerBankDetails.validateIfsc('HDFC0004567'), isNull);
      expect(SellerBankDetails.validateIfsc('INVALID123'), isNotNull);
      expect(SellerBankDetails.validateIfsc('SBIN1001234'), isNotNull); // 5th char must be 0
      expect(SellerBankDetails.validateIfsc('12345678901'), isNotNull);
    });

    test('5. Account number validation rejects short/invalid numbers', () {
      expect(SellerBankDetails.validateAccountNumber('123456789'), isNull); // 9 digits
      expect(SellerBankDetails.validateAccountNumber('1234567890123456'), isNull); // 16 digits
      expect(SellerBankDetails.validateAccountNumber('12345'), isNotNull); // Too short
      expect(SellerBankDetails.validateAccountNumber('12345678901234567890'), isNotNull); // Too long
      expect(SellerBankDetails.validateAccountNumber('ABC12345678'), isNotNull); // Non-digit
    });

    test('6. Serialization and deserialization preserves all bank fields', () {
      const original = SellerBankDetails(
        accountHolderName: 'Kailash Chand & Sons',
        bankName: 'Punjab National Bank',
        accountNumber: '55667788990011',
        ifscCode: 'PUNB0024400',
        branchName: 'Mandi Yard Bikaner',
        isVerified: false,
        verificationStatus: 'unverified',
      );

      final map = original.toMap();
      final rehydrated = SellerBankDetails.fromMap(map);

      expect(rehydrated.accountHolderName, original.accountHolderName);
      expect(rehydrated.bankName, original.bankName);
      expect(rehydrated.accountNumber, original.accountNumber);
      expect(rehydrated.ifscCode, original.ifscCode);
      expect(rehydrated.branchName, original.branchName);
      expect(rehydrated.isVerified, isFalse);
      expect(rehydrated.verificationStatus, 'unverified');
    });
  });
}
