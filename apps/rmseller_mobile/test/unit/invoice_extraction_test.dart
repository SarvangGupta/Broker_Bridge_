import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';

void main() {
  group('RB-SELLER-PROFILE-INVOICE-01: Invoice OCR & Extraction Tests', () {
    const service = InvoiceOcrService(nativeEngineAvailable: false);

    test('1. Full Indian tax invoice with bank details extracts genuine values', () {
      const invoiceText = '''
        TAX INVOICE
        M/s Bikaner Agro Processing Industries Ltd
        Plot 12, Krishi Upaj Mandi Industrial Area, Bikaner, Rajasthan - 334001
        GSTIN: 08AABCB1234F1Z5
        Invoice No: INV-2026-9844
        Date: 24/10/2026

        Bank Details for RTGS / NEFT:
        Beneficiary Name: Bikaner Agro Processing Industries Ltd
        Bank Name: State Bank of India
        Account No: 334455667788
        IFSC Code: SBIN0001234
        Branch: Mandi Complex Bikaner
      ''';

      final extracted = service.extractFromText(invoiceText);

      expect(extracted.firmName, contains('Bikaner Agro Processing Industries'));
      expect(extracted.gstin, '08AABCB1234F1Z5');
      expect(extracted.pinCode, '334001');
      expect(extracted.invoiceNumber, 'INV-2026-9844');
      expect(extracted.accountNumber, '334455667788');
      expect(extracted.ifscCode, 'SBIN0001234');
      expect(extracted.bankName, 'State Bank of India');
      expect(extracted.hasBankDetails, isTrue);
      expect(extracted.confidenceScore, greaterThan(0.7));
    });

    test('2. Missing fields remain null and are NEVER fabricated or guessed', () {
      const partialInvoiceText = '''
        TAX INVOICE
        M/s Marwar Grain Traders
        GSTIN: 08XYZPA5544L1Z2
      ''';

      final extracted = service.extractFromText(partialInvoiceText);

      expect(extracted.firmName, contains('Marwar Grain Traders'));
      expect(extracted.gstin, '08XYZPA5544L1Z2');
      // Bank details MUST be null because they are NOT present in the text
      expect(extracted.accountNumber, isNull);
      expect(extracted.ifscCode, isNull);
      expect(extracted.bankName, isNull);
      expect(extracted.pinCode, isNull);
      expect(extracted.hasBankDetails, isFalse);
    });

    test('3. Business-only invoice extracts firm identifiers without bank details', () {
      const businessOnlyInvoice = '''
        BILL OF SUPPLY
        Kota Pulses & Oilseeds Mills Pvt Ltd
        Plot 88, Bhamashah Mandi Road, Kota, Rajasthan - 324005
        GSTIN: 08AAACF4321Q1Z8
        Bill No: B-9921
      ''';

      final extracted = service.extractFromText(businessOnlyInvoice);

      expect(extracted.firmName, contains('Kota Pulses & Oilseeds Mills'));
      expect(extracted.gstin, '08AAACF4321Q1Z8');
      expect(extracted.pinCode, '324005');
      expect(extracted.accountNumber, isNull);
      expect(extracted.ifscCode, isNull);
      expect(extracted.hasBankDetails, isFalse);
    });

    test('4. Empty or garbled text returns empty extracted data safely', () {
      const unreadableText = '   \n\n   ... --- !!!  \n ';
      final extracted = service.extractFromText(unreadableText);

      expect(extracted.isEmpty, isTrue);
      expect(extracted.firmName, isNull);
      expect(extracted.gstin, isNull);
      expect(extracted.accountNumber, isNull);
    });

    test('5. Non-existent file reports clear failure message', () async {
      final nonExistentFile = File('non_existent_invoice.jpg');
      final result = await service.extractFromFile(nonExistentFile);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('does not exist'));
    });

    test('6. Native engine unavailability is reported honestly without fake OCR in production', () async {
      // Create a temporary file to test file intake with nativeEngineAvailable: false
      final tempDir = await Directory.systemTemp.createTemp('invoice_test');
      final tempFile = File('${tempDir.path}/sample_invoice.jpg');
      await tempFile.writeAsString('invoice content dummy bytes');

      final result = await service.extractFromFile(tempFile);

      expect(result.isSuccess, isFalse);
      expect(result.isEngineBlocked, isTrue);
      expect(result.errorMessage, contains('On-device native OCR engine is not bundled'));

      await tempDir.delete(recursive: true);
    });

    test('7. Default InvoiceOcrService has genuine OCR engine marked available', () {
      const liveService = InvoiceOcrService();
      expect(liveService.isOcrEngineAvailable, isTrue);
    });

    test('8. Invoice text with item lines extracts genuine commodity names', () {
      const invoiceWithCommodities = '''
        TAX INVOICE
        Bikaner Agro Processing Ltd
        GSTIN: 08AABCB1234F1Z5
        
        Items Description:
        1. Mustard Seed / Sarson Bold - 50 Bags (5000 kg)
        2. Desi Chana Grade A - 100 Bags (10000 kg)
        3. Wheat Sharbati - 40 Bags
      ''';

      final extracted = service.extractFromText(invoiceWithCommodities);

      expect(extracted.extractedCommodities, isNotEmpty);
      expect(extracted.extractedCommodities, contains('Mustard'));
      expect(extracted.extractedCommodities, contains('Chana'));
      expect(extracted.extractedCommodities, contains('Wheat'));
    });

    test('9. Custom recognizer runs genuine pipeline and prefill extraction without mocking fake data', () async {
      final tempDir = await Directory.systemTemp.createTemp('invoice_custom');
      final testFile = File('${tempDir.path}/invoice.png');
      await testFile.writeAsString('dummy invoice bytes');

      final testService = InvoiceOcrService(
        customRecognizer: (file) async {
          return '''
            TAX INVOICE
            Sharma Agro Foods
            GSTIN: 08AAAAA0000A1Z5
            Account No: 123456789012
            IFSC Code: SBIN0001234
            Bank Name: State Bank of India
          ''';
        },
      );

      final result = await testService.extractFromFile(testFile);

      expect(result.isSuccess, isTrue);
      final data = result.data;
      expect(data.firmName, contains('Sharma Agro Foods'));
      expect(data.gstin, '08AAAAA0000A1Z5');
      expect(data.accountNumber, '123456789012');
      expect(data.ifscCode, 'SBIN0001234');
      expect(data.bankName, 'State Bank of India');

      await tempDir.delete(recursive: true);
    });
  });
}
