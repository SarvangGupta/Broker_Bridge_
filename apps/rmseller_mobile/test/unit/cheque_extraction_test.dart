import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/domain/cheque_extracted_data.dart';
import 'package:rmseller_mobile/features/profile/domain/invoice_extracted_data.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_bank_details.dart';

void main() {
  const service = InvoiceOcrService();

  group('Cheque Leaf OCR Extraction Unit Tests', () {
    test('1. Full Indian Cheque with MICR band, account number, IFSC, bank name, branch, and holder', () {
      const chequeRawText = '''
STATE BANK OF INDIA
BRANCH: JAIPUR MAIN MANDI
RTGS/NEFT IFSC: SBIN0001234
PAY Self or Bearer
RUPEES Fifty Thousand Only
A/C NO: 309812345678
FOR SHARMA AGRO TRADERS
Authorised Signatory
"000123" 302002001: 000123" 10
''';

      final result = service.extractChequeFromText(chequeRawText);

      expect(result.bankName, equals('State Bank of India'));
      expect(result.branchName, equals('JAIPUR MAIN MANDI'));
      expect(result.ifscCode, equals('SBIN0001234'));
      expect(result.accountNumber, equals('309812345678'));
      expect(result.accountHolderName, equals('SHARMA AGRO TRADERS'));
      expect(result.chequeNumber, equals('000123'));
      expect(result.micrCode, equals('302002001'));
      expect(result.rawMicrBand, contains('000123'));
      expect(result.confidenceScore, greaterThan(0.8));
    });

    test('2. Cheque number (6 digits) is NEVER treated as the bank account number', () {
      const chequeWithObviousChequeNumber = '''
HDFC BANK
MANDI BRANCH
A/C No: 50100234567890
"123456" 110240001: 000123" 10
''';

      final result = service.extractChequeFromText(chequeWithObviousChequeNumber);

      expect(result.chequeNumber, equals('123456'));
      expect(result.accountNumber, equals('50100234567890'));
      expect(result.accountNumber, isNot(equals('123456')));
      expect(result.accountNumber, isNot(equals('110240001')));
    });

    test('3. Cheque with MICR code but NO IFSC code leaves IFSC null (no hallucination)', () {
      // Many standard Indian CTS-2010 local cheques do NOT have IFSC printed
      const chequeWithoutIfsc = '''
PUNJAB NATIONAL BANK
BRANCH: KOTA GRAIN MANDI
Current A/C: 1234567890123456
For KOTA GRAIN TRADERS
Authorized Signatory
"654321" 324024002: 123456" 29
''';

      final result = service.extractChequeFromText(chequeWithoutIfsc);

      expect(result.bankName, equals('Punjab National Bank'));
      expect(result.branchName, equals('KOTA GRAIN MANDI'));
      expect(result.accountNumber, equals('1234567890123456'));
      expect(result.chequeNumber, equals('654321'));
      expect(result.micrCode, equals('324024002'));
      // STRICT REQUIREMENT: If IFSC is not present, leave null and never invent
      expect(result.ifscCode, isNull);
    });

    test('4. Cheque with missing account holder leaves holder null/empty', () {
      const chequeBlankHolder = '''
ICICI BANK
Connaught Place Branch
A/C: 000105001234
"456789" 110229001: 000456" 10
''';

      final result = service.extractChequeFromText(chequeBlankHolder);

      expect(result.bankName, equals('ICICI Bank'));
      expect(result.accountNumber, equals('000105001234'));
      expect(result.accountHolderName, isNull);
    });

    test('5. Ambiguous/garbled text returns empty data without crashing', () {
      const garbledText = '''
### ??? *** !!!
~~~ random noise ~~~
''';

      final result = service.extractChequeFromText(garbledText);

      expect(result.isEmpty, isTrue);
      expect(result.accountNumber, isNull);
      expect(result.ifscCode, isNull);
      expect(result.micrCode, isNull);
      expect(result.confidenceScore, equals(0.0));
    });

    test('6. mergeWithCheque merges cheque bank details into existing invoice extracted data', () {
      const invoiceData = InvoiceExtractedData(
        firmName: 'Shree Ram Agro Industries',
        gstin: '08AAAAA0000A1Z5',
        officeAddress: 'Shop 12, Krishi Upaj Mandi, Jaipur',
        pinCode: '302001',
        extractedCommodities: ['Wheat', 'Mustard'],
      );

      const chequeData = ChequeExtractedData(
        accountHolderName: 'Shree Ram Agro Industries',
        bankName: 'State Bank of India',
        branchName: 'Mandi Branch',
        accountNumber: '309812345678',
        ifscCode: 'SBIN0001234',
        micrCode: '302002001',
        chequeNumber: '000123',
      );

      final merged = invoiceData.mergeWithCheque(chequeData);

      // Invoice business information remains intact
      expect(merged.firmName, equals('Shree Ram Agro Industries'));
      expect(merged.gstin, equals('08AAAAA0000A1Z5'));
      expect(merged.officeAddress, equals('Shop 12, Krishi Upaj Mandi, Jaipur'));
      expect(merged.pinCode, equals('302001'));
      expect(merged.extractedCommodities, contains('Wheat'));
      expect(merged.extractedCommodities, contains('Mustard'));

      // Bank details merged from cheque
      expect(merged.accountHolderName, equals('Shree Ram Agro Industries'));
      expect(merged.bankName, equals('State Bank of India'));
      expect(merged.branchName, equals('Mandi Branch'));
      expect(merged.accountNumber, equals('309812345678'));
      expect(merged.ifscCode, equals('SBIN0001234'));
      expect(merged.micrCode, equals('302002001'));
      expect(merged.chequeNumber, equals('000123'));
    });

    test('7. SellerBankDetails.validateMicr validates 9-digit format accurately', () {
      expect(SellerBankDetails.validateMicr('110002001'), isNull);
      expect(SellerBankDetails.validateMicr('302002001'), isNull);
      expect(SellerBankDetails.validateMicr(''), isNull); // Optional field
      expect(SellerBankDetails.validateMicr(null), isNull); // Optional field
      expect(SellerBankDetails.validateMicr('12345'), isNotNull);
      expect(SellerBankDetails.validateMicr('11000200A'), isNotNull);
      expect(SellerBankDetails.validateMicr('1100020019'), isNotNull);
    });
  });
}
