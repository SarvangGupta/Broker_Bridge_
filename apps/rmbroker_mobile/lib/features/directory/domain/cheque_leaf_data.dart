import 'package:flutter/foundation.dart';

/// Validation rules and bank mapping for Indian Financial System Code (IFSC).
class IfscRules {
  const IfscRules._();

  static final RegExp _format = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

  static bool hasValidFormat(String ifsc) =>
      _format.hasMatch(ifsc.trim().toUpperCase());

  static const Map<String, String> _bankPrefixes = {
    'SBIN': 'State Bank of India',
    'HDFC': 'HDFC Bank',
    'ICIC': 'ICICI Bank',
    'UTIB': 'Axis Bank',
    'PUNB': 'Punjab National Bank',
    'BARB': 'Bank of Baroda',
    'KKBK': 'Kotak Mahindra Bank',
    'CNRB': 'Canara Bank',
    'UBIN': 'Union Bank of India',
    'IDFB': 'IDFC FIRST Bank',
    'YESB': 'Yes Bank',
    'INDB': 'IndusInd Bank',
    'BKID': 'Bank of India',
    'CBIN': 'Central Bank of India',
    'IOBA': 'Indian Overseas Bank',
    'IDIB': 'Indian Bank',
    'MAHB': 'Bank of Maharashtra',
    'PSIB': 'Punjab & Sind Bank',
    'UCOB': 'UCO Bank',
    'FDRL': 'Federal Bank',
  };

  /// Returns bank name if prefix is recognized, otherwise null.
  static String? bankNameFromIfsc(String ifsc) {
    final clean = ifsc.trim().toUpperCase();
    if (clean.length < 4) return null;
    return _bankPrefixes[clean.substring(0, 4)];
  }
}

/// Verification status for bank details.
class CounterpartyBankStatus {
  static const String unverified = 'unverified';
  static const String chequeLeafProvided = 'cheque_leaf_provided';
  static const String verified = 'verified';

  static String displayLabel(String? status) {
    switch (status?.toLowerCase().trim()) {
      case chequeLeafProvided:
        return 'Cheque Leaf Provided — Broker Recorded';
      case verified:
        return 'Bank Account Verified';
      case unverified:
      default:
        return 'Unverified';
    }
  }
}

/// Extracted bank details from cheque leaf image.
@immutable
class ChequeLeafData {
  final String? accountHolderName;
  final String? bankName;
  final String? accountNumber;
  final String? ifsc;
  final String? branch;
  final List<String> reviewNotes;
  final String? rawText;
  final String? documentPath;

  const ChequeLeafData({
    this.accountHolderName,
    this.bankName,
    this.accountNumber,
    this.ifsc,
    this.branch,
    this.reviewNotes = const [],
    this.rawText,
    this.documentPath,
  });

  bool get isEmpty =>
      (accountNumber == null || accountNumber!.trim().isEmpty) &&
      (ifsc == null || ifsc!.trim().isEmpty) &&
      (accountHolderName == null || accountHolderName!.trim().isEmpty);

  bool get isNotEmpty => !isEmpty;

  bool get hasValidIfsc => ifsc != null && IfscRules.hasValidFormat(ifsc!);

  /// Masked account number, e.g. •••• •••• 4321
  String get maskedAccountNumber {
    final num = accountNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (num.length < 4) return '••••';
    final last4 = num.substring(num.length - 4);
    return '•••• •••• $last4';
  }

  ChequeLeafData copyWith({
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifsc,
    String? branch,
    List<String>? reviewNotes,
    String? rawText,
    String? documentPath,
  }) {
    return ChequeLeafData(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
      branch: branch ?? this.branch,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      rawText: rawText ?? this.rawText,
      documentPath: documentPath ?? this.documentPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifsc': ifsc,
      'branch': branch,
      'reviewNotes': reviewNotes,
      'documentPath': documentPath,
    };
  }

  factory ChequeLeafData.fromJson(Map<String, dynamic> json) {
    return ChequeLeafData(
      accountHolderName: json['accountHolderName']?.toString() ??
          json['bank_holder_name']?.toString(),
      bankName:
          json['bankName']?.toString() ?? json['bank_name']?.toString(),
      accountNumber: json['accountNumber']?.toString() ??
          json['bank_account_number']?.toString(),
      ifsc: json['ifsc']?.toString() ?? json['bank_ifsc']?.toString(),
      branch:
          json['branch']?.toString() ?? json['bank_branch']?.toString(),
      reviewNotes: (json['reviewNotes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      documentPath: json['documentPath']?.toString() ??
          json['bank_cheque_url']?.toString(),
    );
  }
}

