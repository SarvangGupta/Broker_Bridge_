/// Value object representing structured bank details extracted from a cheque leaf photo.
/// STRICT PRINCIPLES:
/// - Unverified suggestions only; must never automatically overwrite authoritative data without explicit confirmation.
/// - Never fabricate or hallucinate missing data. Missing values remain empty/null.
/// - A cheque may contain a MICR code without displaying an IFSC code; never invent missing IFSC.
/// - Cheque number (6 digits) must NEVER be treated as the bank account number.
/// - Bank details are strictly unverified even when extracted.
class ChequeExtractedData {
  final String? accountHolderName;
  final String? bankName;
  final String? branchName;
  final String? accountNumber;
  final String? ifscCode;
  final String? micrCode;
  final String? chequeNumber;
  final String? rawMicrBand;
  final String rawText;
  final String? rawTextPreview;
  final double confidenceScore;

  const ChequeExtractedData({
    this.accountHolderName,
    this.bankName,
    this.branchName,
    this.accountNumber,
    this.ifscCode,
    this.micrCode,
    this.chequeNumber,
    this.rawMicrBand,
    this.rawText = '',
    this.rawTextPreview,
    this.confidenceScore = 0.0,
  });

  bool get isEmpty =>
      (accountHolderName == null || accountHolderName!.trim().isEmpty) &&
      (bankName == null || bankName!.trim().isEmpty) &&
      (branchName == null || branchName!.trim().isEmpty) &&
      (accountNumber == null || accountNumber!.trim().isEmpty) &&
      (ifscCode == null || ifscCode!.trim().isEmpty) &&
      (micrCode == null || micrCode!.trim().isEmpty);

  bool get hasBankDetails =>
      (accountNumber != null && accountNumber!.trim().isNotEmpty) ||
      (ifscCode != null && ifscCode!.trim().isNotEmpty) ||
      (micrCode != null && micrCode!.trim().isNotEmpty);

  Map<String, dynamic> toMap() {
    return {
      'account_holder_name': accountHolderName,
      'bank_name': bankName,
      'branch_name': branchName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'micr_code': micrCode,
      'cheque_number': chequeNumber,
      'raw_micr_band': rawMicrBand,
      'confidence_score': confidenceScore,
    };
  }

  factory ChequeExtractedData.fromMap(Map<String, dynamic> map) {
    return ChequeExtractedData(
      accountHolderName: map['account_holder_name']?.toString() ?? map['accountHolderName']?.toString(),
      bankName: map['bank_name']?.toString() ?? map['bankName']?.toString(),
      branchName: map['branch_name']?.toString() ?? map['branchName']?.toString(),
      accountNumber: map['account_number']?.toString() ?? map['accountNumber']?.toString(),
      ifscCode: map['ifsc_code']?.toString() ?? map['ifscCode']?.toString(),
      micrCode: map['micr_code']?.toString() ?? map['micrCode']?.toString(),
      chequeNumber: map['cheque_number']?.toString() ?? map['chequeNumber']?.toString(),
      rawMicrBand: map['raw_micr_band']?.toString(),
      rawText: map['raw_text']?.toString() ?? '',
      rawTextPreview: map['raw_text_preview']?.toString(),
      confidenceScore: (map['confidence_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Result of executing cheque OCR on an image file.
class ChequeExtractionResult {
  final bool isSuccess;
  final ChequeExtractedData? data;
  final String? errorMessage;
  final String? rawText;
  final bool isEngineBlocked;

  const ChequeExtractionResult.success(this.data, {this.rawText})
      : isSuccess = true,
        errorMessage = null,
        isEngineBlocked = false;

  const ChequeExtractionResult.blocked(this.errorMessage, [this.data])
      : isSuccess = false,
        rawText = null,
        isEngineBlocked = true;

  const ChequeExtractionResult.failure(this.errorMessage)
      : isSuccess = false,
        data = null,
        rawText = null,
        isEngineBlocked = false;
}
