import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';
import '../domain/invoice_extracted_data.dart';
import '../domain/cheque_extracted_data.dart';
import '../domain/gst_certificate_extracted_data.dart';
import 'gst_certificate_parser.dart';
import 'india_pincode_directory.dart';

/// Result envelope for GST certificate extraction.
class GstCertificateExtractionResult {
  final bool isSuccess;
  final GstCertificateExtractedData data;
  final String? errorMessage;

  const GstCertificateExtractionResult.success(this.data)
      : isSuccess = true,
        errorMessage = null;

  const GstCertificateExtractionResult.failure(this.errorMessage)
      : isSuccess = false,
        data = const GstCertificateExtractedData();
}

/// Result envelope for invoice extraction operations.
class InvoiceExtractionResult {
  final bool isSuccess;
  final InvoiceExtractedData data;
  final String? errorMessage;
  final bool isEngineBlocked;

  const InvoiceExtractionResult.success(this.data)
      : isSuccess = true,
        errorMessage = null,
        isEngineBlocked = false;

  const InvoiceExtractionResult.blocked(String message, [InvoiceExtractedData? partial])
      : isSuccess = false,
        data = partial ?? const InvoiceExtractedData(),
        errorMessage = message,
        isEngineBlocked = true;

  const InvoiceExtractionResult.failure(this.errorMessage)
      : isSuccess = false,
        data = const InvoiceExtractedData(),
        isEngineBlocked = false;
}

typedef FileTextRecognizer = Future<String> Function(File file);

/// Service providing real invoice data extraction, document parsing, and validation.
/// STRICT PRINCIPLES:
/// - Genuine multilingual OCR supporting Devanagari (Hindi) and Latin (English) scripts.
/// - OCR language is strictly independent of the app's selected display language.
/// - Never fabricates or guesses missing values. Missing fields remain null/empty.
/// - Never translates or transliterates business names or addresses automatically.
/// - Never marks bank details or profile verified based only on invoice text.
/// - Discloses engine availability honestly.
/// - Uses offline India PIN Code directory for postal circle, state, and district resolution.
/// - Separates supplier details from buyer details.
/// - Performs arithmetic reconciliation without silently overwriting source numbers.
class InvoiceOcrService {
  final bool _nativeEngineAvailable;
  final FileTextRecognizer? _customRecognizer;

  const InvoiceOcrService({
    bool? nativeEngineAvailable,
    FileTextRecognizer? customRecognizer,
  })  : _nativeEngineAvailable = nativeEngineAvailable ?? true,
        // ignore: prefer_initializing_formals
        _customRecognizer = customRecognizer;

  bool get isOcrEngineAvailable => _nativeEngineAvailable;

  /// Runs raw multilingual text recognition on an image or PDF using ML Kit or custom recognizer.
  /// Configured with Devanagari script model which natively recognizes both Devanagari (Hindi)
  /// and Latin (English) characters and digits.
  Future<String> recognizeRawTextFromFile(File file) async {
    final recognizer = _customRecognizer;
    if (recognizer != null) {
      return await recognizer(file);
    }

    final pathLower = file.path.toLowerCase();
    final isPdf = pathLower.endsWith('.pdf');
    final isImage = pathLower.endsWith('.jpg') ||
        pathLower.endsWith('.jpeg') ||
        pathLower.endsWith('.png') ||
        pathLower.endsWith('.webp') ||
        pathLower.endsWith('.bmp');

    if (!isPdf && !isImage) {
      throw Exception('Unsupported file format. Please upload a JPG, PNG, or PDF file.');
    }

    TextRecognizer textRecognizer;
    try {
      textRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
    } catch (_) {
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    }

    final StringBuffer rawBuffer = StringBuffer();

    try {
      if (isPdf) {
        final document = await PdfDocument.openFile(file.path);
        final pageCount = document.pagesCount;
        final pagesToProcess = pageCount > 2 ? 2 : pageCount;

        for (int i = 1; i <= pagesToProcess; i++) {
          final page = await document.getPage(i);
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );
          await page.close();

          if (pageImage != null && pageImage.bytes.isNotEmpty) {
            final tempDir = await Directory.systemTemp.createTemp('rmseller_ocr_pdf_');
            final tempImg = File('${tempDir.path}/pdf_page_$i.png');
            await tempImg.writeAsBytes(pageImage.bytes);

            try {
              final inputImage = InputImage.fromFile(tempImg);
              final recognized = await textRecognizer.processImage(inputImage);
              if (recognized.text.isNotEmpty) {
                rawBuffer.writeln(recognized.text);
              }
            } finally {
              if (tempImg.existsSync()) await tempImg.delete();
              if (tempDir.existsSync()) await tempDir.delete(recursive: true);
            }
          }
        }
        await document.close();
      } else {
        final inputImage = InputImage.fromFile(file);
        final recognized = await textRecognizer.processImage(inputImage);
        rawBuffer.write(recognized.text);
      }
    } finally {
      await textRecognizer.close();
    }

    return rawBuffer.toString().trim();
  }

  /// Extract structured profile suggestions from an image or PDF file on disk.
  Future<InvoiceExtractionResult> extractFromFile(File file) async {
    if (!file.existsSync()) {
      return const InvoiceExtractionResult.failure('The selected invoice image file does not exist.');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      return const InvoiceExtractionResult.failure('The selected invoice file is empty or corrupted.');
    }

    if (!_nativeEngineAvailable) {
      return const InvoiceExtractionResult.blocked(
        'On-device native OCR engine is not bundled in this build. '
        'You can inspect your genuine document preview, and review or enter details manually.',
      );
    }

    try {
      final rawText = await recognizeRawTextFromFile(file);
      if (rawText.isEmpty) {
        return const InvoiceExtractionResult.failure(
          'Text extraction failed: No readable text detected in the document. Please ensure good lighting and clear alignment.',
        );
      }

      final extractedData = extractFromText(rawText);
      return InvoiceExtractionResult.success(extractedData);
    } catch (e, stack) {
      debugPrint('OCR execution error: $e\n$stack');
      return InvoiceExtractionResult.failure(
        'Text extraction failed: ${e.toString().replaceAll('Exception:', '').trim()}',
      );
    }
  }

  /// Extract seller details from a GST REG-06 Registration Certificate (image or PDF).
  Future<GstCertificateExtractionResult> extractGstCertificateFromFile(File file) async {
    if (!file.existsSync() || await file.length() == 0) {
      return const GstCertificateExtractionResult.failure('The selected certificate file is missing or empty.');
    }
    if (!_nativeEngineAvailable) {
      return const GstCertificateExtractionResult.failure(
        'On-device OCR engine is not available in this build. Please enter the details manually.',
      );
    }
    try {
      final rawText = await recognizeRawTextFromFile(file);
      if (rawText.isEmpty) {
        return const GstCertificateExtractionResult.failure(
          'No readable text was found on the certificate. Please retake it in good light or enter the details manually.',
        );
      }
      final data = extractGstCertificateFromText(rawText);
      if (data.isEmpty) {
        return const GstCertificateExtractionResult.failure(
          'This does not look like a GST Registration Certificate (Form GST REG-06). Please check the document.',
        );
      }
      return GstCertificateExtractionResult.success(data);
    } catch (e) {
      debugPrint('GST certificate OCR error: ${e.runtimeType}');
      return GstCertificateExtractionResult.failure(
        'Certificate text extraction failed: ${e.toString().replaceAll('Exception:', '').trim()}',
      );
    }
  }

  GstCertificateExtractedData extractGstCertificateFromText(String rawText) =>
      const GstCertificateParser().parse(rawText);

  /// Extract bank details from a cheque photo or gallery image.
  Future<ChequeExtractionResult> extractChequeFromFile(File file) async {
    if (!file.existsSync()) {
      return const ChequeExtractionResult.failure('The selected cheque image file does not exist.');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      return const ChequeExtractionResult.failure('The selected cheque file is empty or corrupted.');
    }

    if (!_nativeEngineAvailable) {
      return const ChequeExtractionResult.blocked(
        'On-device native OCR engine is not bundled in this build. '
        'You can inspect your genuine document preview, and review or enter details manually.',
      );
    }

    try {
      final rawText = await recognizeRawTextFromFile(file);
      if (rawText.isEmpty) {
        return const ChequeExtractionResult.failure(
          'Text extraction failed: No readable text detected on the cheque. Please ensure the cheque is well-lit and placed on a dark background.',
        );
      }

      final extractedData = extractChequeFromText(rawText);
      return ChequeExtractionResult.success(extractedData);
    } catch (e, stack) {
      debugPrint('Cheque OCR execution error: $e\n$stack');
      return ChequeExtractionResult.failure(
        'Cheque extraction failed: ${e.toString().replaceAll('Exception:', '').trim()}',
      );
    }
  }

  /// Normalizes Devanagari numerals (०, १, २, ३, ४, ५, ६, ७, ८, ९) to standard ASCII digits (0-9)
  /// for accurate numeric parsing of GSTINs, PIN codes, phone numbers, and bank accounts,
  /// while preserving original text script in business names and addresses.
  static String normalizeDevanagariNumerals(String text) {
    const devanagariDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    String result = text;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(devanagariDigits[i], '$i');
    }
    return result;
  }

  /// Extracts structured fields from raw OCR text using authoritative Indian invoice formats.
  /// Works across English, Hindi, and mixed-language business invoices.
  InvoiceExtractedData extractFromText(String rawText) {
    if (rawText.trim().isEmpty) {
      return const InvoiceExtractedData();
    }

    final bool isHindi = RegExp(r'[\u0900-\u097F]').hasMatch(rawText);
    final String normalizedText = normalizeDevanagariNumerals(rawText);

    final cleanLines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Real OCR output is not in reading order (ML Kit may emit the buyer block before the
    // supplier header), so the buyer block is identified by its header + form lines wherever
    // it appears, and supplier-only fields (name, address, PIN, email) skip those lines.
    final String? signatureName = _extractSignatureFirmName(cleanLines);
    final Set<int> buyerLineIdx = _findBuyerLineIndexes(cleanLines, signatureName);
    final supplierLines = [
      for (int i = 0; i < cleanLines.length; i++)
        if (!buyerLineIdx.contains(i)) cleanLines[i],
    ];
    final String supplierNormalizedText = normalizeDevanagariNumerals(supplierLines.join('\n'));

    // 1. Structured Core Business Identifiers (Supplier / Seller)
    final String? gstin = _extractGstin(normalizedText);
    final String? pin = _extractPinCode(supplierNormalizedText, supplierLines);
    final String? firmName = signatureName ?? _extractFirmName(supplierLines, gstin);
    final String? email = _extractEmail(supplierLines);

    // 2. India PIN Code Intelligence & Lookup
    // 3. Address Extraction & Multiple Address Candidate Detection
    final addressExtraction = _extractAddressDetails(supplierLines, pin, firmName);
    final String? officeAddress = addressExtraction.primaryAddress;
    final Map<String, String> addressCandidates = addressExtraction.candidates;

    String? state;
    String? district;
    String? pinReviewNotice;
    if (pin != null) {
      final pinResult = IndiaPinCodeDirectory.lookup(pin);
      if (pinResult == null) {
        pinReviewNotice = 'PIN code $pin was not found in the India Post directory. Please verify it.';
      } else if (pinResult.isStateAmbiguous) {
        pinReviewNotice =
            'PIN code $pin is listed under more than one state (${pinResult.stateCandidates.join(', ')}). Please select the state and district.';
      } else {
        state = pinResult.stateName;
        if (pinResult.districtName.isNotEmpty) {
          district = pinResult.districtName;
        } else if (pinResult.isAmbiguous) {
          // Use the written address to pick among the PIN's districts; otherwise ask the seller.
          final addr = (officeAddress ?? '').toLowerCase();
          final mentioned = pinResult.districtCandidates.where((d) => addr.contains(d.toLowerCase())).toList();
          if (mentioned.length == 1) {
            district = mentioned.first;
          } else {
            pinReviewNotice =
                'PIN code $pin covers more than one district (${pinResult.districtCandidates.join(', ')}). Please select the district.';
          }
        }
      }
    }

    // 4. PIN Code & Address Conflict Detection
    final String? pinConflictNotice = IndiaPinCodeDirectory.detectAddressConflict(
          pin,
          officeAddress ?? rawText,
        ) ??
        pinReviewNotice;
    final bool hasPinAddressConflict = pinConflictNotice != null;

    // 5. Contact Mobile Number Extraction & Disambiguation
    final mobileExtraction = _extractMobileNumbers(normalizedText, cleanLines, buyerLineIdx);
    final String? contactMobile = mobileExtraction.primarySellerMobile;
    final List<PhoneCandidate> phoneCandidates = mobileExtraction.candidates;

    // 6. Invoice Metadata
    final String? invoiceNo = _extractInvoiceNumber(normalizedText);
    final String? invoiceDate = _extractInvoiceDate(normalizedText);
    final String? documentType = _extractDocumentType(rawText);
    final String? vehicleNo = _extractVehicleNumber(rawText, cleanLines);
    final String? transportType = _extractTransportType(rawText, cleanLines);

    // 7. Buyer Details (Separated from Supplier)
    final BuyerDetails? buyerDetails = _extractBuyerDetails(rawText, normalizedText, cleanLines, gstin, firmName);

    // 8. Line Items & Tabular Commodities Extraction
    final List<InvoiceLineItem> lineItems = _extractLineItems(rawText, normalizedText, cleanLines);

    // 9. Financials & Totals
    final InvoiceFinancials? financials = _extractFinancials(rawText, normalizedText, cleanLines, lineItems);

    // 10. Agricultural Commodity Extraction (Keywords + Line Items)
    final List<String> commodities = _extractCommodities(rawText, cleanLines, lineItems);

    // 11. Bank Details (when printed on the invoice)
    final String? ifsc = _extractIfsc(normalizedText);
    final String? accountNo = _extractAccountNumber(normalizedText);
    final String? bankName = _extractBankName(rawText);
    final String? accountHolder = _extractAccountHolder(rawText, firmName);
    final String? branchName = _extractBankBranch(rawText, cleanLines);

    // 12. Arithmetic Reconciliation & Conflict Detection
    final reconciliation = _performArithmeticReconciliation(lineItems, financials);

    // 13. Handwriting Presence Detection
    final bool hasHandwritten = rawText.toLowerCase().contains('handwritten') ||
        rawText.contains('हस्तलिखित') ||
        (buyerDetails?.isHandwritten ?? false) ||
        lineItems.any((i) => i.isHandwritten);

    // 14. Confidence Calculation
    double score = 0.0;
    if (gstin != null) score += 0.25;
    if (firmName != null) score += 0.2;
    if (officeAddress != null) score += 0.15;
    if (pin != null) score += 0.1;
    if (contactMobile != null) score += 0.05;
    if (accountNo != null) score += 0.05;
    if (ifsc != null) score += 0.05;
    if (branchName != null) score += 0.05;
    if (commodities.isNotEmpty || lineItems.isNotEmpty) score += 0.1;
    if (buyerDetails != null) score += 0.05;

    return InvoiceExtractedData(
      firmName: firmName,
      gstin: gstin,
      email: email,
      officeAddress: officeAddress,
      state: state,
      district: district,
      pinCode: pin,
      contactMobile: contactMobile,
      phoneCandidates: phoneCandidates,
      hasPinAddressConflict: hasPinAddressConflict,
      pinConflictNotice: pinConflictNotice,
      isHindiDocument: isHindi,
      addressCandidates: addressCandidates,
      invoiceNumber: invoiceNo,
      invoiceDate: invoiceDate,
      vehicleNumber: vehicleNo,
      transportType: transportType,
      documentType: documentType,
      buyerDetails: buyerDetails,
      lineItems: lineItems,
      financials: financials,
      hasArithmeticMismatch: reconciliation.hasMismatch,
      arithmeticMismatchNotice: reconciliation.notice,
      uncertainFields: reconciliation.uncertainFields,
      hasHandwrittenContent: hasHandwritten,
      accountHolderName: accountHolder,
      bankName: bankName,
      accountNumber: accountNo,
      ifscCode: ifsc,
      branchName: branchName,
      extractedCommodities: commodities,
      confidenceScore: score.clamp(0.0, 1.0),
      rawTextPreview: rawText.length > 200 ? '${rawText.substring(0, 200)}...' : rawText,
    );
  }

  // --- GSTIN EXTRACTION (PRESERVED & PROTECTED) ---

  String? _extractGstin(String normalizedText) {
    // 1. Contextual matching following standard GST / GSTIN / जीएसटी labels
    final labeledRegex = RegExp(
      r'(?:gstin|gst|जीएसटी(?:इन)?|जी\.एस\.टी\.)\s*(?:no\.?|number|#|सं\.?|संख्या)?\s*[:\-]?\s*([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1})\b',
      caseSensitive: false,
    );
    final labeledMatch = labeledRegex.firstMatch(normalizedText);
    if (labeledMatch != null && labeledMatch.group(1) != null) {
      return labeledMatch.group(1)!.toUpperCase();
    }

    // 2. Direct boundary match: 2 digits, 5 letters, 4 digits, 1 letter, 1 alphanumeric, 'Z', 1 alphanumeric
    final regex = RegExp(
      r'\b([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1})\b',
      caseSensitive: false,
    );
    final match = regex.firstMatch(normalizedText);
    return match?.group(1)?.toUpperCase();
  }

  // --- INDIAN PIN CODE INTELLIGENCE ---

  String? _extractPinCode(String normalizedText, List<String> lines) {
    // 1. Explicitly labeled PIN / Pincode / पिन / डाक सूचकांक
    final labeledRegex = RegExp(
      r'(?:pin\s*(?:code)?|pincode|postal\s*code|पिन\s*कोड|पिन|डाक\s*सूचकांक)\s*[:\-]?\s*([1-9][0-9]{5})\b',
      caseSensitive: false,
    );
    final labeledMatch = labeledRegex.firstMatch(normalizedText);
    if (labeledMatch != null) {
      final pin = labeledMatch.group(1)!;
      if (IndiaPinCodeDirectory.isValidPin(pin)) return pin;
    }

    // 2. Trailing hyphenated PIN on address lines (e.g., "Rajasthan - 334001" or "जयपुर, राजस्थान - 302003")
    final hyphenPinRegex = RegExp(r'(?:[-–—,\s])\s*([1-9][0-9]{5})\b');
    for (final line in lines) {
      final normLine = normalizeDevanagariNumerals(line);
      // Item rows carry HSN codes / long amounts; their 6-digit totals are not PINs.
      if (RegExp(r'[0-9]{7,}').hasMatch(normLine)) continue;
      final m = hyphenPinRegex.firstMatch(normLine);
      // A bare space before 6 digits ("योग 336600") is only a PIN on an address-like line.
      if (m != null && m.group(0)!.trimLeft() == m.group(1) && !_isAddressLine(line, normLine, null)) continue;
      if (m != null) {
        final pin = m.group(1)!;
        if (IndiaPinCodeDirectory.isValidPin(pin)) return pin;
      }
    }

    // 3. Isolated 6-digit candidate verified by India Post Directory — only on address-like
    // lines, so amounts / HSN rows (e.g. "... 1800 336600") are never taken as a PIN.
    final isolatedRegex = RegExp(r'\b([1-9][0-9]{5})\b');
    for (final line in lines) {
      final normLine = normalizeDevanagariNumerals(line);
      if (RegExp(r'[0-9]{7,}').hasMatch(normLine)) continue;
      if (!_isAddressLine(line, normLine, null) && !line.contains(',')) continue;
      for (final match in isolatedRegex.allMatches(normLine)) {
        final candidate = match.group(1)!;
        if (candidate.startsWith('202') || candidate.startsWith('199')) continue;
        // Unlabelled numbers must exist in the India Post directory to count as a PIN.
        if (IndiaPinCodeDirectory.isKnownPin(candidate)) return candidate;
      }
    }

    return null;
  }

  // --- MULTI-LINE ADDRESS EXTRACTION (ENGLISH & HINDI) ---

  static final RegExp _buyerSectionPattern = RegExp(
    r'^(?:(?:consignee|क्रेता)\s*(?:\/|&)\s*)?(?:billed\s*to|bill\s*to|buyer|consignee|customer|क्रेता|खरीदार|ग्राहक|प्रति|मेसर्स(?:\s*क्रेता)?|m\/s\.?)(?:\s|$|[:\-])',
    caseSensitive: false,
  );

  static final RegExp _gstinTokenPattern = RegExp(
    r'\b[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b',
    caseSensitive: false,
  );

  /// Supplier firm name from the signature line ("For BINA ENTERPRISES", "वास्ते-मे० <फर्म>").
  /// This line is printed by the supplier, so it is independent of OCR block order.
  String? _extractSignatureFirmName(List<String> lines) {
    final sigRegex = RegExp(r'^(?:for|वास्ते)\s*[-–:]?\s*(.+)$', caseSensitive: false);
    final businessKeywords = RegExp(
      r'(?:agro|industries|mills?|traders|enterprises|ltd|limited|pvt|private|foods|trading|company|co\.|corporation|ट्रेडर्स|उद्योग|एग्रो|मिल्स|मिल|इंटरप्राइजेज|लिमिटेड|फर्म|कंपनी|कम्पनी|इंडस्ट्रीज|फूड्स|व्यापार)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = sigRegex.firstMatch(line.trim());
      if (m == null) continue;
      final name = m
          .group(1)!
          .replaceAll(RegExp(r'(?:authori[sz]ed\s*signatory|अधिकृत\s*हस्ताक्षर).*$', caseSensitive: false), '')
          .trim();
      if (name.length >= 3 && name.length <= 80 && businessKeywords.hasMatch(name)) return name;
    }
    return null;
  }

  /// Indexes of buyer-section lines: each buyer header plus the form lines that follow it,
  /// up to the item table / next section. Works regardless of where OCR places the block.
  Set<int> _findBuyerLineIndexes(List<String> lines, String? signatureName) {
    final sectionEnd = RegExp(
      r'^(?:item|s\.?\s*no|particulars|description|क्र\.?\s*सं?|विवरण|hsn|invoice|इनवाइस|bank|बैंक|total|कुल|truck|गाड़ी)',
      caseSensitive: false,
    );
    final sigNorm = signatureName == null ? null : normalizeDevanagariNumerals(signatureName);
    final result = <int>{};
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!_buyerSectionPattern.hasMatch(line)) continue;
      // A leading "M/s <name>" on the first lines is the supplier header unless the signature
      // line proves the supplier is someone else.
      if (sigNorm != null && normalizeDevanagariNumerals(line).contains(sigNorm.replaceAll(RegExp(r'^(?:m\/s\.?|मे[0\.])\s*', caseSensitive: false), ''))) {
        continue;
      }
      if (i < 2 && sigNorm == null) continue;
      result.add(i);
      for (int j = i + 1; j < lines.length && j <= i + 6; j++) {
        if (sectionEnd.hasMatch(lines[j].trim())) break;
        result.add(j);
      }
    }
    return result;
  }

  /// Compares Devanagari ignoring vowel signs/independent vowels, so OCR slips such as
  /// "बैंक अफ बड़ौदा" still match "बैंक ऑफ बड़ौदा".
  static String _devanagariSkeleton(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[ऀ-ःऄ-औऺ-ॏॕ-ॗॢॣ]'), '').replaceAll(RegExp(r'\s+'), ' ');

  String? _extractEmail(List<String> supplierLines) {
    final regex = RegExp(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b');
    for (final line in supplierLines) {
      final m = regex.firstMatch(line);
      if (m != null) return m.group(0)!.toLowerCase();
    }
    return null;
  }

  /// [lines] must be supplier lines only (buyer section already removed).
  _AddressExtractionResult _extractAddressDetails(
    List<String> lines,
    String? pin,
    String? firmName,
  ) {
    final buyerIndex = lines.length;
    final candidates = <String, String>{};
    String? primaryAddress;

    final headerPattern = RegExp(
      r'^(?:address|addr|office\s*address|registered\s*office|regd(?:\.|\s+office)|corporate\s*office|billing\s*address|consignor\s*address|works\s*address|godown\s*address|पता|कार्यालय\s*पता|मुख्य\s*कार्यालय|पंजीकृत\s*कार्यालय|प्रतिष्ठान\s*का\s*पता|दुकान\s*का\s*पता|स्थान|फर्म\s*का\s*पता)\s*[:\-]?\s*(.*)$',
      caseSensitive: false,
    );

    final stopHeaderPattern = RegExp(
      r'^(?:(?:gstin|gst|pan|invoice\s*no|bill\s*no|date|dated|bank\s*details|a\/c|account|total|mobile|phone|ph|contact|for|authori[sz]ed|s\.?\s*no|particulars|hsn)\b|जीएसटी|पैन|बिल\s*संख्या|दिनांक|बैंक|खाता|कुल|मोबाइल|फोन|संपर्क|वास्ते|अधिकृत|क्र\.?\s*सं)',
      caseSensitive: false,
    );

    // 1. Prioritize Supplier header block (lines 0 to buyerIndex)
    for (int i = 0; i < buyerIndex; i++) {
      final line = lines[i];
      final match = headerPattern.firstMatch(line);
      if (match != null) {
        final addressLines = <String>[];
        final firstRemainder = match.group(1)?.trim() ?? '';
        if (firstRemainder.isNotEmpty) addressLines.add(firstRemainder);

        int j = i + 1;
        while (j < buyerIndex && addressLines.length < 4) {
          final nextLine = lines[j];
          final normNext = normalizeDevanagariNumerals(nextLine);
          if (stopHeaderPattern.hasMatch(normNext) || headerPattern.hasMatch(nextLine)) break;
          if (nextLine.trim().isNotEmpty && nextLine.trim().length <= 120) {
            addressLines.add(nextLine);
            j++;
          } else {
            break;
          }
        }

        if (addressLines.isNotEmpty) {
          final joined = addressLines.map((l) => _cleanAddressLine(l)).where((l) => l.isNotEmpty).join(', ');
          if (joined.length >= 8) {
            final lowerLine = line.toLowerCase();
            String label = 'Business Address';
            if (lowerLine.contains('registered') || lowerLine.contains('पंजीकृत')) {
              label = 'Registered Office';
            } else if (lowerLine.contains('corporate') || lowerLine.contains('मुख्य')) {
              label = 'Corporate Office';
            } else if (lowerLine.contains('billing')) {
              label = 'Billing Address';
            } else if (lowerLine.contains('consignor') || lowerLine.contains('works')) {
              label = 'Works / Shipment Origin';
            }

            candidates[label] = joined;
            primaryAddress ??= joined;
          }
        }
      }
    }

    // 2. Check address keywords in supplier block if no labeled address found
    if (primaryAddress == null) {
      for (int i = 0; i < buyerIndex; i++) {
        final line = lines[i];
        final normLine = normalizeDevanagariNumerals(line);
        if ((pin != null && normLine.contains(pin)) || _isAddressLine(line, normLine, pin)) {
          final collected = <String>[];
          if (i > 0 && i - 1 < buyerIndex && _isAddressLine(lines[i - 1], normalizeDevanagariNumerals(lines[i - 1]), pin)) {
            collected.add(_cleanAddressLine(lines[i - 1]));
          }
          collected.add(_cleanAddressLine(line));
          if (i + 1 < buyerIndex && _isAddressLine(lines[i + 1], normalizeDevanagariNumerals(lines[i + 1]), pin)) {
            collected.add(_cleanAddressLine(lines[i + 1]));
          }

          final joined = collected.where((l) => l.isNotEmpty).join(', ');
          if (joined.length >= 10) {
            primaryAddress = joined;
            candidates['Business Address'] = joined;
            break;
          }
        }
      }
    }

    // 3. Unlabeled printed address directly under the supplier firm name
    // (common on Hindi mandi invoices: "मे० <फर्म>" followed by "<गाँव>, <कस्बा>, <जिला> मो० : ...").
    if (primaryAddress == null && firmName != null) {
      // Match on the core name (honorific dropped, Devanagari digits normalised: "मे0" == "मे०").
      final core = normalizeDevanagariNumerals(firmName)
          .replaceAll(RegExp(r'^(?:m\/s\.?|मे[0\.]|मेसर्स|मैसर्स)\s*', caseSensitive: false), '');
      final firmIdx = lines.indexWhere((l) => normalizeDevanagariNumerals(l).contains(core));
      if (firmIdx != -1 && firmIdx + 1 < buyerIndex) {
        final next = lines[firmIdx + 1];
        final cleaned = _cleanAddressLine(next);
        if (!_isNonAddressLabelLine(next) && cleaned.contains(',') && cleaned.length >= 8) {
          primaryAddress = cleaned;
          candidates['Business Address'] = cleaned;
        }
      }
    }

    return _AddressExtractionResult(primaryAddress, candidates);
  }

  bool _isNonAddressLabelLine(String line) {
    final t = line.trim();
    if (_gstinTokenPattern.hasMatch(t) && _cleanAddressLine(t).length < 8) return true;
    return RegExp(
      r'^(?:state\s*[:|]|gstin|gst\b|pan\b|code\s*:|invoice|inv\s*no|bill\s*of\s*supply|tax\s*invoice|original|duplicate|hsn|s\.?\s*no|कैटिल|क्रम\s*संख्या|इनवाइस|बीजक|कर\s*चालान)',
      caseSensitive: false,
    ).hasMatch(t);
  }

  bool _isAddressLine(String line, String normLine, String? pin) {
    if (_isNonAddressLabelLine(line)) return false;
    if (pin != null && normLine.contains(pin)) return true;
    final addressKw = RegExp(
      r'(?:plot|road|street|mandi|hub|sector|area|phase|industrial|complex|nagar|colony|gate|bazar|market|lane|village|tehsil|district|मार्ग|रोड|मंडी|बाजार|नगर|कॉलोनी|गली|रास्ता|ग्राम|तहसील|जिला|परिसर)',
      caseSensitive: false,
    );
    return addressKw.hasMatch(line) && line.length >= 4 && line.length <= 120;
  }

  String _cleanAddressLine(String line) {
    var clean = line.replaceAll(RegExp(r'^(?:address|addr|office\s*address|पता|कार्यालय\s*पता)\s*[:\-]?\s*', caseSensitive: false), '').trim();
    // Remove GSTINs (supplier or buyer) wherever OCR merged them into the address line.
    clean = clean.replaceAll(RegExp(r'(?:gstin|gst)\s*(?:no\.?)?\s*[:\-]?\s*', caseSensitive: false), ' ');
    clean = clean.replaceAll(_gstinTokenPattern, ' ');
    // Remove trailing contact fragments: "Mob. : 98290 12345", "मो० : 9696700510, 9919808347".
    clean = clean.replaceAll(
      RegExp(
        r'(?:\b(?:mob(?:ile)?|phone|ph|tel|contact|cell)\b\.?|मो[०\.]|मोबाइल(?:\s*नं[०\.]?)?|फोन|संपर्क|दूरभाष)\s*[:\-]?\s*\+?[0-9][0-9\-,\s\(\)]*$',
        caseSensitive: false,
      ),
      '',
    );
    clean = clean.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    clean = clean.replaceAll(RegExp(r'^[,;\s\-]+|[,;\s\-]+$'), '').trim();
    return clean;
  }

  // --- MOBILE NUMBER EXTRACTION & DISAMBIGUATION ---

  _MobileExtractionResult _extractMobileNumbers(String normalizedText, List<String> lines, Set<int> buyerLineIdx) {
    final candidates = <PhoneCandidate>[];
    final seenNumbers = <String>{};

    final mobileRegex = RegExp(
      r'(?:(?:\+91|91|0)?[ -]?)?([6-9][0-9]{4}[ -]?[0-9]{5})\b',
    );

    final phoneHeaderRegex = RegExp(
      r'(?:mob(?:ile)?|phone|ph\.?|cell|contact|tel|m:|mo:|मोबाइल|मो[.\u09700]?|मोबा\.|संपर्क|दूरभाष|फोन|सम्पर्क\s*सूत्र)\s*[:\-]?\s*',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final normLine = normalizeDevanagariNumerals(line);

      for (final match in mobileRegex.allMatches(normLine)) {
        final rawCandidate = match.group(0)!.trim();
        final digitsOnly = rawCandidate.replaceAll(RegExp(r'[^0-9]'), '');
        final String tenDigit = digitsOnly.length > 10
            ? digitsOnly.substring(digitsOnly.length - 10)
            : digitsOnly;

        if (tenDigit.length == 10 && RegExp(r'^[6-9]').hasMatch(tenDigit)) {
          if (seenNumbers.contains(tenDigit)) continue;
          seenNumbers.add(tenDigit);

          final bool isSellerLine = i < 8 ||
              normLine.toLowerCase().contains('seller') ||
              normLine.contains('विक्रेता') ||
              phoneHeaderRegex.hasMatch(normLine);

          final bool isTransportLine = normLine.toLowerCase().contains('transporter') ||
              normLine.toLowerCase().contains('driver') ||
              normLine.toLowerCase().contains('vehicle') ||
              normLine.contains('ट्रांसपोर्ट');

          final bool isBuyerLine = normLine.toLowerCase().contains('buyer') ||
              normLine.toLowerCase().contains('bill to') ||
              normLine.toLowerCase().contains('consignee') ||
              normLine.contains('क्रेता') ||
              normLine.contains('खरीदार') ||
              normLine.contains('ग्राहक') ||
              (buyerLineIdx.contains(i) && !isTransportLine);

          String label = 'Seller Contact';
          bool isSeller = true;

          if (isBuyerLine) {
            label = 'Buyer Contact';
            isSeller = false;
          } else if (isTransportLine) {
            label = 'Transport Contact';
            isSeller = false;
          } else if (!isSellerLine && i >= 10) {
            label = 'Document Contact';
            isSeller = false;
          }

          candidates.add(
            PhoneCandidate(
              number: tenDigit,
              rawMatch: rawCandidate,
              contextLabel: label,
              isSellerCandidate: isSeller,
            ),
          );
        }
      }
    }

    String? primarySellerMobile;
    for (final c in candidates) {
      if (c.isSellerCandidate) {
        primarySellerMobile = c.number;
        break;
      }
    }
    // Never fall back to a buyer/transport number for the supplier's contact.
    return _MobileExtractionResult(primarySellerMobile, candidates);
  }

  // --- FIRM NAME EXTRACTION (ENGLISH & HINDI) ---

  /// [lines] must be the supplier header block only (buyer section excluded).
  String? _extractFirmName(List<String> lines, String? gstin) {
    final labelLine = RegExp(
      r'^(?:(?:gstin|gst|state|code|mob(?:ile)?|ph(?:one)?|tel|e-?mail|invoice|inv|bill\s*no|date|dated|original|duplicate|pan|fssai|hsn)\b|मो[०\.]|मोबाइल|फोन|जीएसटी|दिनांक|क्रम\s*संख्या|इनवाइस)',
      caseSensitive: false,
    );

    // Strips identifiers OCR may merge onto the name line; returns null if nothing name-like remains.
    String? sanitize(String line) {
      var c = line.replaceAll(_gstinTokenPattern, ' ');
      c = c.replaceAll(RegExp(r'(?:gstin|gst)\s*(?:no\.?)?\s*[:\-]?', caseSensitive: false), ' ').trim();
      if (labelLine.hasMatch(c)) return null;
      c = c.replaceAll(RegExp(r'\+?[0-9][0-9\-\s]{8,}[0-9]'), ' ');
      c = c.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      c = c.replaceAll(RegExp(r'^[,;:\|\s\-]+|[,;:\|\s\-]+$'), '').trim();
      return c.isEmpty ? null : c;
    }

    final businessKeywords = RegExp(
      r'(?:agro|industries|mills|mill|processing|traders|enterprises|ltd|limited|corp|pvt|private|foods|trading|company|co\b|ट्रेडर्स|उद्योग|एग्रो|मिल्स|मिल|इंटरप्राइजेज|प्राइवेट|लिमिटेड|फर्म|कंपनी|कम्पनी|इंडस्ट्रीज|फूड्स|ट्रेडिंग|दाल\s*मिल|ऑयल\s*मिल|कृषि\s*फर्म|व्यापार)',
      caseSensitive: false,
    );

    // Honorifics (M/s, मे०, मेसर्स) are part of the printed firm name and are kept.
    final prefixPattern = RegExp(
      r'^(?:to|from|tax\s*invoice|bill\s*of\s*supply|कर\s*चालान|बीजक|प्रति|प्रेषक)\s*[:\-]?\s*',
      caseSensitive: false,
    );

    // Skip OCR noise (row numbers, stray digits) so the 10-line window covers real text.
    final textLines = lines.where((l) => RegExp(r'[A-Za-zऀ-ॿ]{3,}').hasMatch(l)).toList();

    for (final line in textLines.take(10)) {
      final clean = sanitize(line)?.replaceAll(prefixPattern, '').trim() ?? '';
      if (clean.length >= 3 && clean.length <= 80) {
        final hasValidChars = RegExp(r'[A-Za-z\u0900-\u097F]').hasMatch(clean);
        if (hasValidChars && businessKeywords.hasMatch(clean)) {
          return clean;
        }
      }
    }

    for (final line in lines.take(4)) {
      final clean = sanitize(line)?.replaceAll(prefixPattern, '').trim() ?? '';
      if (clean.length >= 4 && clean.length <= 60) {
        if (!clean.toLowerCase().contains('invoice') &&
            !clean.toLowerCase().contains('supply') &&
            !clean.contains('चालान') &&
            !clean.contains('बीजक')) {
          if (RegExp(r'[A-Za-z\u0900-\u097F]{3,}').hasMatch(clean)) {
            return clean;
          }
        }
      }
    }

    return null;
  }

  // --- DOCUMENT TYPE, VEHICLE & TRANSPORT TYPE ---

  String? _extractDocumentType(String text) {
    final patterns = [
      RegExp(r'(?:कर\s*चालान|tax\s*invoice)', caseSensitive: false),
      RegExp(r'(?:आपूर्ति\s*बीजक|bill\s*of\s*supply)', caseSensitive: false),
      RegExp(r'(?:delivery\s*challan|चालान)', caseSensitive: false),
      RegExp(r'(?:मंडी\s*(?:समिति\s*)?रसीद|मंडी\s*पर्चा|mandi\s*(?:samiti\s*)?(?:receipt|parcha))', caseSensitive: false),
      RegExp(r'(?:proforma\s*invoice)', caseSensitive: false),
      RegExp(r'(?:बीजक|invoice)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(0)!.trim();
    }
    return null;
  }

  String? _extractVehicleNumber(String text, List<String> lines) {
    final vehRegex = RegExp(
      r'\b([A-Z]{2}[ -]?[0-9]{1,2}[ -]?[A-Z]{1,3}[ -]?[0-9]{4})\b',
      caseSensitive: false,
    );

    final contextPrefix = RegExp(
      r'(?:vehicle\s*(?:no\.?|number|#)?|truck\s*(?:no\.?|number|#)?|lorry\s*(?:no\.?|number|#)?|गाड़ी\s*(?:सं\.?|संख्या|नं\.?)?|वाहन\s*(?:सं\.?|संख्या|क्रमांक)?|ट्रक\s*(?:नं\.?|संख्या)?)\s*[:\-]?\s*',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (contextPrefix.hasMatch(line)) {
        final normLine = normalizeDevanagariNumerals(line);
        final m = vehRegex.firstMatch(normLine.toUpperCase());
        if (m != null) {
          final matched = m.group(1)!.replaceAll('-', '').replaceAll(' ', '');
          final fmtMatch = RegExp(r'^([A-Z]{2})([0-9]{1,2})([A-Z]{1,3})([0-9]{4})$').firstMatch(matched);
          if (fmtMatch != null) {
            return '${fmtMatch.group(1)} ${fmtMatch.group(2)} ${fmtMatch.group(3)} ${fmtMatch.group(4)}';
          }
          return m.group(1)!.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        }
      }
    }

    for (final match in vehRegex.allMatches(normalizeDevanagariNumerals(text).toUpperCase())) {
      final candidate = match.group(1)!.trim();
      if (candidate.length >= 8 && candidate.length <= 14) {
        return candidate.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ');
      }
    }
    return null;
  }

  String? _extractTransportType(String text, List<String> lines) {
    final labeledPattern = RegExp(
      r'(?:transport(?:ation)?|mode\s*of\s*transport|परिवहन(?:\s*का\s*प्रकार)?|ट्रांसपोर्ट(?:\s*प्रकार|\s*का\s*प्रकार)?)\s*[:\-]?\s*([A-Za-z\u0900-\u097F\s\(\)]+)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = labeledPattern.firstMatch(line);
      if (m != null) {
        final val = m.group(1)?.trim();
        if (val != null && val.isNotEmpty && val.length < 40) return val;
      }
    }

    final modePattern = RegExp(r'\b(by\s*road|road\s*transport|सड़क\s*परिवहन|सड़क\s*मार्ग)\b', caseSensitive: false);
    for (final line in lines) {
      if (RegExp(r'(?:truck|vehicle|lorry)\s*(?:no|number|#|संख्या|नं)', caseSensitive: false).hasMatch(line)) continue;
      final m = modePattern.firstMatch(line);
      if (m != null) return m.group(0)?.trim();
    }
    return null;
  }

  // --- BUYER DETAILS EXTRACTION ---

  BuyerDetails? _extractBuyerDetails(
    String rawText,
    String normalizedText,
    List<String> lines,
    String? supplierGstin,
    String? supplierFirm,
  ) {
    final buyerHeaderRegex = RegExp(
      r'^(?:(?:consignee|क्रेता)\s*(?:\/|&)\s*)?(?:billed\s*to|bill\s*to|buyer|consignee|customer|क्रेता|खरीदार|ग्राहक|प्रति|मेसर्स(?:\s*क्रेता)?|m\/s\.?)\s*(?:details|name|का\s*नाम)?\s*[:\-]?\s*(.*)$',
      caseSensitive: false,
    );

    String? buyerName;
    String? buyerGstin;
    String? buyerAddress;
    String? buyerMobile;
    String? buyerPin;
    String? buyerState;
    String? buyerDistrict;
    bool isHandwritten = false;

    int buyerHeaderIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = buyerHeaderRegex.firstMatch(line);
      if (match != null) {
        buyerHeaderIndex = i;
        var remainder = match.group(1)?.trim() ?? '';
        if (remainder.startsWith('[') && remainder.endsWith(']')) {
          if (remainder.toLowerCase().contains('handwritten') || remainder.contains('हस्तलिखित')) {
            isHandwritten = true;
          }
          remainder = '';
        }
        if (remainder.isNotEmpty && remainder != supplierFirm) {
          buyerName = remainder;
        }
        break;
      }
    }

    if (buyerHeaderIndex != -1) {
      if (buyerName == null && buyerHeaderIndex + 1 < lines.length) {
        var next = lines[buyerHeaderIndex + 1].trim();
        if (next.startsWith('[') && next.endsWith(']')) {
          if (next.toLowerCase().contains('handwritten') || next.contains('हस्तलिखित')) {
            isHandwritten = true;
          }
          if (buyerHeaderIndex + 2 < lines.length) {
            next = lines[buyerHeaderIndex + 2].trim();
          }
        }

        if (!next.toLowerCase().startsWith('gstin') &&
            !next.startsWith('जीएसटी') &&
            !next.toLowerCase().startsWith('address') &&
            !next.startsWith('पता') &&
            next.length < 80) {
          buyerName = next.replaceAll(RegExp(r'^(?:m\/s\.?|मैसर्स|मेसर्स)\s*', caseSensitive: false), '').trim();
        }
      }

      final buyerBlockLines = <String>[];
      for (int j = buyerHeaderIndex + 1; j < lines.length && j < buyerHeaderIndex + 8; j++) {
        final l = lines[j];
        final norm = normalizeDevanagariNumerals(l);
        if (RegExp(r'^(?:item|s\.?no|particulars|description|माल|विवरण|बैंक|bank|total|कुल)\b', caseSensitive: false).hasMatch(norm)) {
          break;
        }

        final gstinMatch = RegExp(r'\b([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1})\b', caseSensitive: false).firstMatch(norm);
        if (gstinMatch != null) {
          final g = gstinMatch.group(1)!.toUpperCase();
          if (g != supplierGstin) {
            buyerGstin = g;
          }
        }

        final mobMatch = RegExp(r'(?:(?:\+91|91|0)?[ -]?)?([6-9][0-9]{4}[ -]?[0-9]{5})\b').firstMatch(norm);
        if (mobMatch != null && buyerMobile == null) {
          final digits = mobMatch.group(1)!.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.length == 10) {
            buyerMobile = digits;
          }
        }

        if (!norm.toLowerCase().contains('gstin') &&
            !norm.contains('जीएसटी') &&
            !norm.toLowerCase().contains('phone') &&
            !norm.toLowerCase().contains('mobile') &&
            !norm.contains('मोबाइल') &&
            !norm.contains('क्रेता संपर्क') &&
            !l.startsWith('[') &&
            l.trim() != buyerName) {
          buyerBlockLines.add(_cleanAddressLine(l));
        }
      }

      if (buyerBlockLines.isNotEmpty) {
        buyerAddress = buyerBlockLines.where((l) => l.isNotEmpty).join(', ');
        final pinMatch = RegExp(r'\b([1-9][0-9]{5})\b').firstMatch(normalizeDevanagariNumerals(buyerAddress));
        if (pinMatch != null) {
          buyerPin = pinMatch.group(1);
          final loc = IndiaPinCodeDirectory.lookup(buyerPin!);
          if (loc != null) {
            buyerState = loc.stateName;
            buyerDistrict = loc.districtName.isNotEmpty ? loc.districtName : null;
          }
        }
      }
    }

    if (buyerGstin == null && supplierGstin != null) {
      final allGstins = RegExp(r'\b([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1})\b', caseSensitive: false)
          .allMatches(normalizedText)
          .map((m) => m.group(1)!.toUpperCase())
          .toSet();
      allGstins.remove(supplierGstin);
      if (allGstins.isNotEmpty) {
        buyerGstin = allGstins.first;
      }
    }

    if (rawText.toLowerCase().contains('handwritten') || rawText.contains('हस्तलिखित')) {
      isHandwritten = true;
    }

    if (buyerName == null && buyerGstin == null && buyerAddress == null) {
      return null;
    }

    return BuyerDetails(
      buyerName: buyerName,
      gstin: buyerGstin,
      address: buyerAddress,
      contactMobile: buyerMobile,
      state: buyerState,
      district: buyerDistrict,
      pinCode: buyerPin,
      isHandwritten: isHandwritten,
    );
  }

  // --- LINE ITEMS & COMMODITIES EXTRACTION ---

  List<InvoiceLineItem> _extractLineItems(String rawText, String normalizedText, List<String> lines) {
    final items = <InvoiceLineItem>[];

    final skipLineRegex = RegExp(
      r'(?:address|addr|road|street|mandi|market|nagar|lane|colony|gate|sector|plot|phase|industrial|village|tehsil|district|state|मार्ग|रोड|मंडी|बाजार|नगर|कॉलोनी|ग्राम|तहसील|जिला|राज्य|gstin|pan|mobile|phone|संपर्क|दूरभाष|truck|vehicle|lorry|गाड़ी|वाहन|ट्रक|total|subtotal|कुल|योग|bank|बैंक|a\/c|ifsc|freight|charges|भाड़ा|किराया|हमाली)',
      caseSensitive: false,
    );

    final rowWithHsnRegex = RegExp(
      r'(?:^[0-9]{1,2}[\.\)]\s*)?([A-Za-z\u0900-\u097F\s\(\)\-]+?)\s+([0-9]{4,8})\s+([0-9]+(?:\.[0-9]+)?)\s*(qtl|quintal|bags?|kgs?|tons?|mt|बोरी|क्विंटल|किलो|बैग)?\s*(?:(?:@|दर|rate|rs\.?)[:\s]*)?([0-9]+(?:\.[0-9]+)?)\s*(?:(?:=|राशि|amount|total)[:\s]*)?([0-9]+(?:\.[0-9]+)?)\b',
      caseSensitive: false,
    );

    final rowRegex = RegExp(
      r'(?:^[0-9]{1,2}[\.\)]\s*)?([A-Za-z\u0900-\u097F\s\(\)\-]+?)\s+(?:(?:hsn|HSN)[:\s]*([0-9]{4,8})\s+)?([0-9]+(?:\.[0-9]+)?)\s*(qtl|quintal|bags?|kgs?|tons?|mt|बोरी|क्विंटल|किलो|बैग)?\s*(?:(?:@|दर|rate|rs\.?)[:\s]*)?([0-9]+(?:\.[0-9]+)?)\s*(?:(?:=|राशि|amount|total)[:\s]*)?([0-9]+(?:\.[0-9]+)?)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final clean = line.trim();
      if (clean.isEmpty) continue;
      if (clean.startsWith('[') && clean.endsWith(']')) continue;

      final normLine = normalizeDevanagariNumerals(clean);
      if (skipLineRegex.hasMatch(normLine)) continue;
      if (RegExp(r'(?:pin|pincode|पिन|[-–—]\s*[1-9][0-9]{5}\b)', caseSensitive: false).hasMatch(normLine)) continue;
      if (RegExp(r'(?:invoice\s*no|inv\s*no|bill\s*no|date|दिनांक|तारीख)', caseSensitive: false).hasMatch(normLine)) continue;

      final match = rowWithHsnRegex.firstMatch(normLine) ?? rowRegex.firstMatch(normLine);
      if (match != null) {
        final desc = match.group(1)?.replaceAll(RegExp(r'^[0-9]+[\.\)\s]+'), '').trim() ?? '';
        final hsn = match.group(2);
        final qtyStr = match.group(3);
        final unitStr = match.group(4);
        final rateStr = match.group(5);
        final amtStr = match.group(6);

        // Require description and either unit or rate to distinguish table rows from arbitrary numbers
        if (desc.isNotEmpty && desc.length >= 2 && qtyStr != null && (unitStr != null || rateStr != null || normLine.contains('@') || normLine.contains('दर') || normLine.toLowerCase().contains('rate'))) {
          final qty = double.tryParse(qtyStr);
          final rate = rateStr != null ? double.tryParse(rateStr) : null;
          final amt = amtStr != null ? double.tryParse(amtStr) : null;

          bool uncertain = false;
          String? reason;
          if (qty != null && rate != null && amt != null) {
            final expected = qty * rate;
            final expectedPerQuintal = (qty / 100.0) * rate;
            if ((expected - amt).abs() > 2.0 && (expectedPerQuintal - amt).abs() > 2.0) {
              uncertain = true;
              reason = 'Calculated amount ($expected) does not match invoice stated amount ($amt)';
            }
          }

          final bool isHw = normLine.toLowerCase().contains('handwritten') || rawText.toLowerCase().contains('handwritten');

          items.add(
            InvoiceLineItem(
              description: desc,
              hsnCode: hsn,
              quantity: qty,
              unit: unitStr,
              rate: rate,
              amount: amt,
              isHandwritten: isHw,
              isUncertain: uncertain,
              uncertaintyReason: reason,
            ),
          );
        }
      }
    }

    return items;
  }

  // --- FINANCIALS EXTRACTION ---

  InvoiceFinancials? _extractFinancials(
    String rawText,
    String normalizedText,
    List<String> lines,
    List<InvoiceLineItem> items,
  ) {
    double? subtotal;
    double? freight;
    String? freightAnnotation;
    double? tax;
    double? discount;
    double? grandTotal;
    String? amountInWords;
    String? paymentStatus;

    final freightRegex = RegExp(
      r'(?:freight(?:\s*charges|\s*rate)?|transport(?:\s*charges)?|भाड़ा(?:\s*\(freight\))?|किराया|हमाली)\s*[:\-]?\s*(?:rs\.?|₹)?\s*([0-9]+(?:\.[0-9]+)?)\b',
      caseSensitive: false,
    );

    final subtotalRegex = RegExp(
      r'(?:sub\s*total|subtotal|सकल\s*योग|कुल\s*माल\s*मूल्य)\s*[:\-]?\s*(?:rs\.?|₹)?\s*([0-9]+(?:\.[0-9]+)?)\b',
      caseSensitive: false,
    );

    final grandTotalRegex = RegExp(
      r'(?:grand\s*total|total\s*amount|net\s*amount|invoice\s*total|कुल\s*योग|कुल\s*राशि|देय\s*राशि)\s*[:\-]?\s*(?:rs\.?|₹)?\s*([0-9]+(?:\.[0-9]+)?)\b',
      caseSensitive: false,
    );

    final wordsRegex = RegExp(
      r'(?:amount\s*in\s*words|in\s*words|शब्दों\s*में)\s*[:\-]?\s*([A-Za-z\u0900-\u097F\s]+?(?:only|मात्र|\.|\n|$))',
      caseSensitive: false,
    );

    final paymentAnnotationRegex = RegExp(
      r'\b(freight\s*paid|to\s*pay|advance\s*received|paid|cash\s*payment|उधारी|नकद|भुगतान\s*प्राप्त)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final normLine = normalizeDevanagariNumerals(line);

      if (freight == null) {
        final fm = freightRegex.firstMatch(normLine);
        if (fm != null) {
          freight = double.tryParse(fm.group(1)!);
          freightAnnotation = line.trim();
        }
      }

      if (subtotal == null) {
        final sm = subtotalRegex.firstMatch(normLine);
        if (sm != null) {
          subtotal = double.tryParse(sm.group(1)!);
        }
      }

      if (grandTotal == null) {
        final gm = grandTotalRegex.firstMatch(normLine);
        if (gm != null) {
          grandTotal = double.tryParse(gm.group(1)!);
        }
      }

      if (amountInWords == null) {
        final wm = wordsRegex.firstMatch(line);
        if (wm != null) {
          amountInWords = wm.group(1)?.trim();
        }
      }

      if (paymentStatus == null) {
        final pm = paymentAnnotationRegex.firstMatch(line);
        if (pm != null) {
          paymentStatus = pm.group(0)?.trim();
        }
      }
    }

    if (subtotal == null && items.isNotEmpty) {
      final sumItems = items.where((i) => i.amount != null).fold<double>(0.0, (acc, i) => acc + i.amount!);
      if (sumItems > 0) {
        subtotal = sumItems;
      }
    }

    if (grandTotal == null && subtotal != null) {
      grandTotal = subtotal + (freight ?? 0.0) + (tax ?? 0.0) - (discount ?? 0.0);
    }

    if (subtotal == null && grandTotal == null && freight == null) {
      return null;
    }

    return InvoiceFinancials(
      subtotal: subtotal,
      freightCharges: freight,
      freightAnnotation: freightAnnotation,
      taxAmount: tax,
      discountAmount: discount,
      grandTotal: grandTotal,
      amountInWords: amountInWords,
      paymentStatus: paymentStatus,
    );
  }

  // --- ARITHMETIC RECONCILIATION ---

  _ReconciliationResult _performArithmeticReconciliation(
    List<InvoiceLineItem> items,
    InvoiceFinancials? financials,
  ) {
    bool hasMismatch = false;
    final notices = <String>[];
    final uncertainFields = <String>[];

    for (final item in items) {
      if (item.quantity != null && item.rate != null && item.amount != null) {
        final expected = item.quantity! * item.rate!;
        final expectedPerQuintal = (item.quantity! / 100.0) * item.rate!;
        if ((expected - item.amount!).abs() > 2.0 && (expectedPerQuintal - item.amount!).abs() > 2.0) {
          hasMismatch = true;
          uncertainFields.add('Line Item: ${item.description}');
          notices.add(
            'Arithmetic discrepancy: ${item.description} quantity (${item.quantity}) * rate (${item.rate}) = $expected, but invoice states ${item.amount}.',
          );
        }
      }
    }

    if (financials != null && financials.subtotal != null && financials.grandTotal != null) {
      final expectedTotal = financials.subtotal! +
          (financials.freightCharges ?? 0.0) +
          (financials.taxAmount ?? 0.0) -
          (financials.discountAmount ?? 0.0);
      if ((expectedTotal - financials.grandTotal!).abs() > 2.0) {
        hasMismatch = true;
        uncertainFields.add('Grand Total');
        notices.add(
          'Arithmetic discrepancy: Subtotal (${financials.subtotal}) + Charges does not match Grand Total (${financials.grandTotal}).',
        );
      }
    }

    return _ReconciliationResult(
      hasMismatch: hasMismatch,
      notice: notices.isNotEmpty ? notices.join(' ') : null,
      uncertainFields: uncertainFields,
    );
  }

  // --- BANK DETAILS EXTRACTION ---

  String? _extractIfsc(String normalizedText) {
    final regex = RegExp(
      r'\b([A-Z]{4}0[A-Z0-9]{6})\b',
      caseSensitive: false,
    );
    final match = regex.firstMatch(normalizedText);
    return match?.group(1)?.toUpperCase();
  }

  String? _extractAccountNumber(String normalizedText) {
    final kwRegex = RegExp(
      r'(?:a\/c|account|acc(?:\.|\s+no|no)?|खाता(?:\s*सं[.\u09700]?|संख्या)?)\s*(?:no\.?|number|#)?[:\s\-]*([0-9]{9,18})\b',
      caseSensitive: false,
    );
    final kwMatch = kwRegex.firstMatch(normalizedText);
    if (kwMatch != null && kwMatch.group(1) != null) {
      return kwMatch.group(1);
    }

    final numRegex = RegExp(r'\b([0-9]{11,18})\b');
    for (final match in numRegex.allMatches(normalizedText)) {
      final candidate = match.group(1)!;
      if (!candidate.startsWith('202') && !candidate.startsWith('19')) {
        return candidate;
      }
    }
    return null;
  }

  String? _extractBankName(String text) {
    const knownBanks = [
      'भारतीय स्टेट बैंक',
      'State Bank of India',
      'पंजाब नेशनल बैंक',
      'Punjab National Bank',
      'बैंक ऑफ बड़ौदा',
      'Bank of Baroda',
      'सेंट्रल बैंक ऑफ इंडिया',
      'Central Bank of India',
      'Kotak Mahindra Bank',
      'Union Bank of India',
      'IndusInd Bank',
      'Canara Bank',
      'Axis Bank',
      'ICICI Bank',
      'HDFC Bank',
      'Bank of India',
      'IDBI Bank',
      'Yes Bank',
      'ICICI',
      'HDFC',
      'SBI',
      'PNB',
      'BOB',
    ];

    for (final b in knownBanks) {
      if (text.toLowerCase().contains(b.toLowerCase())) {
        return b;
      }
    }
    // OCR often drops Devanagari vowel signs; retry Hindi bank names on consonant skeletons.
    final skeletonText = _devanagariSkeleton(text);
    for (final b in knownBanks.where((b) => RegExp(r'[ऀ-ॿ]').hasMatch(b))) {
      if (skeletonText.contains(_devanagariSkeleton(b))) return b;
    }
    return null;
  }

  String? _extractAccountHolder(String text, String? firmName) {
    final regex = RegExp(
      r'(?:account\s*holder|beneficiary(?:\s*name)?|name\s*as\s*per\s*bank|खाताधारक(?:\s*का\s*नाम)?)\s*[:\-]?\s*([A-Za-z\u0900-\u097F\s\.]{3,50})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return firmName;
  }

  String? _extractBankBranch(String text, List<String> cleanLines) {
    // 1. Explicit Branch label (English & Hindi) e.g. "Branch :- Nirman Nagar, Jaipur", "शाखा: भरवारी"
    final branchRegex = RegExp(
      r'(?:branch|br\.|शाखा)\s*[:\-]?\s*([A-Za-z0-9\u0900-\u097F ,\-\.]{3,45})',
      caseSensitive: false,
    );
    final branchMatch = branchRegex.firstMatch(text);
    if (branchMatch != null && branchMatch.group(1) != null) {
      final b = branchMatch.group(1)!.trim();
      if (b.isNotEmpty && !b.toLowerCase().startsWith('code')) {
        return b;
      }
    }

    // 2. Bank header line with location separator, e.g.:
    // "बैंक : बैंक ऑफ बड़ौदा, भरवारी - कौशाम्बी"
    for (final line in cleanLines) {
      final lower = line.toLowerCase();
      if ((lower.contains('bank') || lower.contains('बैंक')) && line.contains(',')) {
        final commaIdx = line.indexOf(',');
        final candidate = line.substring(commaIdx + 1).trim();
        if (!candidate.toLowerCase().contains('a/c') &&
            !candidate.toLowerCase().contains('खाता') &&
            !candidate.toLowerCase().contains('ifsc') &&
            !candidate.toLowerCase().contains('code') &&
            candidate.length >= 3) {
          return candidate;
        }
      }
    }

    return null;
  }

  // --- COMMODITIES & METADATA ---

  String? _extractInvoiceNumber(String normalizedText) {
    final regex = RegExp(
      r'(?:invoice\s*(?:no\.?|number|#)|inv\s*no\.?|bill\s*(?:no\.?|number|#)|बिल\s*(?:सं\.?|संख्या)|चालान\s*(?:सं\.?|संख्या))\s*[:\-]?\s*([A-Za-z0-9\/\-_]+)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(normalizedText);
    return match?.group(1)?.trim();
  }

  String? _extractInvoiceDate(String normalizedText) {
    final regex = RegExp(
      r'(?:date|invoice\s*date|dated|दिनांक|तारीख)\s*[:\-]?\s*([0-9]{1,2}[\/\-\.][0-9]{1,2}[\/\-\.][0-9]{2,4})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(normalizedText);
    return match?.group(1)?.trim();
  }

  List<String> _extractCommodities(
    String text,
    List<String> lines, [
    List<InvoiceLineItem> lineItems = const [],
  ]) {
    final found = <String>{};

    for (final item in lineItems) {
      if (item.description.isNotEmpty) {
        // Always preserve original invoice script for commodity descriptions
        found.add(item.description);

        final d = item.description.toLowerCase();
        if (d.contains('mustard') || d.contains('sarson') || d.contains('सरसों')) {
          found.add('Mustard');
        } else if (d.contains('wheat') || d.contains('gehun') || d.contains('गेहूं') || d.contains('गेंहू')) {
          found.add('Wheat');
        } else if (d.contains('chana') || d.contains('चना')) {
          found.add('Chana');
        } else if (d.contains('soybean') || d.contains('soya') || d.contains('सोयाबीन')) {
          found.add('Soybean');
        } else if (d.contains('guar') || d.contains('ग्वार')) {
          found.add('Guar Seed');
        } else if (d.contains('moong') || d.contains('मूंग')) {
          found.add('Moong');
        } else if (d.contains('bajra') || d.contains('बाजरा')) {
          found.add('Bajra');
        } else if (d.contains('maize') || d.contains('मक्का')) {
          found.add('Maize');
        }
      }
    }

    final knownKeywords = {
      'Wheat': RegExp(r'\b(wheat|gehun|lokwan|sharbati)\b|गेहूं|गेंहू', caseSensitive: false),
      'Mustard': RegExp(r'\b(mustard|sarson|rai)\b|सरसों|राई', caseSensitive: false),
      'Chana': RegExp(r'\b(chana|gram|chickpea|kabuli)\b|चना|काबुली', caseSensitive: false),
      'Guar Seed': RegExp(r'\b(guar|guar\s*seed|cluster\s*bean)\b|ग्वार|गुवार', caseSensitive: false),
      'Moong': RegExp(r'\b(moong|mung|green\s*gram)\b|मूंग|मूँग', caseSensitive: false),
      'Bajra': RegExp(r'\b(bajra|pearl\s*millet)\b|बाजरा', caseSensitive: false),
      'Soybean': RegExp(r'\b(soybean|soya\s*bean|soya)\b|सोयाबीन|सोया', caseSensitive: false),
      'Maize': RegExp(r'\b(maize|corn|makka)\b|मक्का', caseSensitive: false),
      'Barley': RegExp(r'\b(barley|jowar|sorghum)\b|जौ|ज्वार', caseSensitive: false),
      'Paddy (Rice)': RegExp(r'\b(paddy|rice|basmati)\b|धान|चावल|बासमती', caseSensitive: false),
      'Cumin (Jeera)': RegExp(r'\b(cumin|jeera)\b|जीरा', caseSensitive: false),
      'Coriander': RegExp(r'\b(coriander|dhania)\b|धनिया', caseSensitive: false),
      'Cotton': RegExp(r'\b(cotton|kapas)\b|कपास|रुई', caseSensitive: false),
      'Groundnut': RegExp(r'\b(groundnut|peanut|mungfali)\b|मूंगफली', caseSensitive: false),
      'Tur (Arhar)': RegExp(r'\b(tur|arhar|pigeon\s*pea)\b|तुअर|अरहर', caseSensitive: false),
      'Urad': RegExp(r'\b(urad|black\s*gram)\b|उड़द', caseSensitive: false),
      'Cattle Feed / Husk': RegExp(r'\b(cattle\s*feed|husk|bran|chaff)\b|कैटिल\s*फीड|भूसी|पशु\s*आहार', caseSensitive: false),
    };

    for (final entry in knownKeywords.entries) {
      if (entry.value.hasMatch(text)) {
        found.add(entry.key);
      }
    }

    return found.toList();
  }

  // --- CHEQUE EXTRACTION (PRESERVED) ---

  ChequeExtractedData extractChequeFromText(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ChequeExtractedData();
    }

    final normalizedText = normalizeDevanagariNumerals(rawText);

    String? micrBand;
    String? chequeNo;
    String? micrCode;

    final micrBandRegex = RegExp(r'"?([0-9]{6})"?\s+([0-9]{9})[:\s]+[0-9]{6,7}"?\s+([0-9]{2})');
    final micrMatch = micrBandRegex.firstMatch(normalizedText);

    if (micrMatch != null) {
      micrBand = micrMatch.group(0);
      chequeNo = micrMatch.group(1);
      micrCode = micrMatch.group(2);
    } else {
      final standaloneMicr = RegExp(r'\b([0-9]{9})\b');
      final smMatch = standaloneMicr.firstMatch(normalizedText);
      if (smMatch != null) {
        micrCode = smMatch.group(1);
      }
    }

    final ifscRegex = RegExp(r'\b([A-Z]{4}0[A-Z0-9]{6})\b', caseSensitive: false);
    final ifscMatch = ifscRegex.firstMatch(normalizedText);
    final String? ifsc = ifscMatch?.group(1)?.toUpperCase();

    String? accountNo;
    final acNearRegex = RegExp(
      r'(?:a\/c\s*(?:no\.?|number)?|account\s*(?:no\.?|number)?|current\s*a\/c|savings\s*a\/c)\s*[:\-]?\s*([0-9]{9,18})\b',
      caseSensitive: false,
    );
    final acNearMatch = acNearRegex.firstMatch(normalizedText);
    if (acNearMatch != null) {
      final candidate = acNearMatch.group(1)!;
      if (candidate != chequeNo && candidate != micrCode) {
        accountNo = candidate;
      }
    }

    if (accountNo == null) {
      final isolatedNumRegex = RegExp(r'\b([0-9]{9,18})\b');
      for (final m in isolatedNumRegex.allMatches(normalizedText)) {
        final candidate = m.group(1)!;
        if (candidate == chequeNo || candidate == micrCode) continue;
        if (candidate.length == 10 && RegExp(r'^[6-9]').hasMatch(candidate)) continue;
        accountNo = candidate;
        break;
      }
    }

    final String? bankName = _extractBankName(rawText);

    String? accountHolder;
    final holderRegex = RegExp(
      r'(?:for\s+([A-Za-z0-9 \.\&]{3,45})|m\/s\.?\s+([A-Za-z0-9 \.\&]{3,45}))',
      caseSensitive: false,
    );
    final holderMatch = holderRegex.firstMatch(rawText);
    if (holderMatch != null) {
      accountHolder = (holderMatch.group(1) ?? holderMatch.group(2))?.trim();
    }

    String? branch;
    final branchRegex = RegExp(
      r'(?:branch|br\.)\s*[:\-]?\s*([A-Za-z0-9 ,\-\.]{3,35})',
      caseSensitive: false,
    );
    final branchMatch = branchRegex.firstMatch(rawText);
    if (branchMatch != null) {
      branch = branchMatch.group(1)?.trim();
    }

    double score = 0.0;
    if (accountNo != null) score += 0.3;
    if (ifsc != null) score += 0.25;
    if (micrCode != null) score += 0.2;
    if (bankName != null) score += 0.15;
    if (accountHolder != null) score += 0.1;

    return ChequeExtractedData(
      accountHolderName: accountHolder,
      bankName: bankName,
      branchName: branch,
      accountNumber: accountNo,
      ifscCode: ifsc,
      micrCode: micrCode,
      chequeNumber: chequeNo,
      confidenceScore: score.clamp(0.0, 1.0),
      rawMicrBand: micrBand,
      rawTextPreview: rawText.length > 200 ? '${rawText.substring(0, 200)}...' : rawText,
    );
  }
}

class _AddressExtractionResult {
  final String? primaryAddress;
  final Map<String, String> candidates;
  const _AddressExtractionResult(this.primaryAddress, this.candidates);
}

class _MobileExtractionResult {
  final String? primarySellerMobile;
  final List<PhoneCandidate> candidates;
  const _MobileExtractionResult(this.primarySellerMobile, this.candidates);
}

class _ReconciliationResult {
  final bool hasMismatch;
  final String? notice;
  final List<String> uncertainFields;
  const _ReconciliationResult({
    required this.hasMismatch,
    this.notice,
    required this.uncertainFields,
  });
}
