/// Domain model representing a Seller's bank account details for settlement.
/// Follows strict banking privacy rules:
/// - Masked account number for ordinary view modes.
/// - Strict IFSC format validation (11-character Indian Financial System Code).
/// - No secrets, card PINs, passwords, or OTPs.
/// - Strictly unverified by default unless backed by verified banking settlement webhook.
class SellerBankDetails {
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String branchName;
  final String micrCode;
  final bool isVerified;
  final String verificationStatus; // 'unverified', 'pending_review', 'verified'

  const SellerBankDetails({
    this.accountHolderName = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.branchName = '',
    this.micrCode = '',
    this.isVerified = false,
    this.verificationStatus = 'unverified',
  });

  /// Check whether bank details are entered.
  bool get isConfigured =>
      accountNumber.trim().isNotEmpty && ifscCode.trim().isNotEmpty;

  /// Returns the account number masked for privacy (e.g. •••• •••• •••• 1234).
  String get maskedAccountNumber {
    final clean = accountNumber.replaceAll(RegExp(r'\s+'), '');
    if (clean.length < 4) return clean;
    final last4 = clean.substring(clean.length - 4);
    final maskedPrefix = '•••• ' * ((clean.length - 4) ~/ 4 + 1);
    return '$maskedPrefix$last4'.trim();
  }

  /// Safe display representation that can never leak sensitive digits.
  String get safeAuditDisplay {
    if (accountNumber.trim().isEmpty) return 'None';
    final clean = accountNumber.replaceAll(RegExp(r'\s+'), '');
    final last4 = clean.length >= 4 ? clean.substring(clean.length - 4) : clean;
    final bank = bankName.isNotEmpty ? '$bankName ' : '';
    return '${bank}A/C ending in ...$last4 (IFSC: $ifscCode)';
  }

  SellerBankDetails copyWith({
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? branchName,
    String? micrCode,
    bool? isVerified,
    String? verificationStatus,
  }) {
    return SellerBankDetails(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      branchName: branchName ?? this.branchName,
      micrCode: micrCode ?? this.micrCode,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  factory SellerBankDetails.fromMap(Map<String, dynamic> map) {
    return SellerBankDetails(
      accountHolderName:
          map['account_holder_name']?.toString() ??
          map['accountHolderName']?.toString() ??
          '',
      bankName:
          map['bank_name']?.toString() ?? map['bankName']?.toString() ?? '',
      accountNumber:
          map['account_number']?.toString() ??
          map['accountNumber']?.toString() ??
          '',
      ifscCode:
          map['ifsc_code']?.toString() ??
          map['ifsc']?.toString() ??
          map['ifscCode']?.toString() ??
          '',
      branchName:
          map['branch_name']?.toString() ??
          map['branchName']?.toString() ??
          '',
      micrCode:
          map['micr_code']?.toString() ??
          map['micrCode']?.toString() ??
          map['micr']?.toString() ??
          '',
      isVerified: map['is_verified'] == true,
      verificationStatus:
          map['verification_status']?.toString() ??
          (map['is_verified'] == true ? 'verified' : 'unverified'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'account_holder_name': accountHolderName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'branch_name': branchName,
      'micr_code': micrCode,
      'is_verified': isVerified,
      'verification_status': verificationStatus,
    };
  }

  /// Validation: IFSC code format (4 uppercase letters, '0', 6 alphanumeric)
  static String? validateIfsc(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final clean = val.trim().toUpperCase();
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(clean)) {
      return 'Enter a valid 11-digit IFSC code (e.g. SBIN0001234)';
    }
    return null;
  }

  /// Validation: Bank Account Number (typically 9 to 18 digits in India)
  static String? validateAccountNumber(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final clean = val.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{9,18}$').hasMatch(clean)) {
      return 'Account number must be 9 to 18 digits';
    }
    return null;
  }

  /// Validation: MICR Code (9 digits in India)
  static String? validateMicr(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final clean = val.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{9}$').hasMatch(clean)) {
      return 'MICR code must be 9 digits (e.g. 110002001)';
    }
    return null;
  }
}
