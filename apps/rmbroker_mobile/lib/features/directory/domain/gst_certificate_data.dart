import 'package:flutter/foundation.dart';

/// GSTIN structure rules. A valid GSTIN only proves the number is well formed;
/// it never proves the registration is genuine or that the counterparty is verified by government.
class GstinRules {
  const GstinRules._();

  static final RegExp _format = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
  );
  static const String _chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// Upper-cased, with spaces removed.
  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'\s'), '').toUpperCase();

  static bool hasValidFormat(String gstin) => _format.hasMatch(gstin);

  /// Check character for the first 14 characters (mod-36 algorithm used by GSTN).
  static String checkCharacter(String first14) {
    var sum = 0;
    for (var i = 0; i < 14; i++) {
      final p = _chars.indexOf(first14[i]) * (i.isEven ? 1 : 2);
      sum += p ~/ 36 + p % 36;
    }
    return _chars[(36 - sum % 36) % 36];
  }

  /// Format and check character.
  static bool isValid(String gstin) =>
      hasValidFormat(gstin) && checkCharacter(gstin) == gstin[14];

  /// PAN embedded in a well-formed GSTIN (characters 3–12); null otherwise.
  static String? panOf(String gstin) =>
      hasValidFormat(gstin) ? gstin.substring(2, 12) : null;

  /// State/UT name for the GSTIN's first two digits; null when unknown.
  static String? stateOf(String gstin) =>
      gstin.length >= 2 ? gstStateCodes[gstin.substring(0, 2)] : null;
}

/// GST state codes (first two digits of a GSTIN).
const Map<String, String> gstStateCodes = {
  '01': 'Jammu and Kashmir',
  '02': 'Himachal Pradesh',
  '03': 'Punjab',
  '04': 'Chandigarh',
  '05': 'Uttarakhand',
  '06': 'Haryana',
  '07': 'Delhi',
  '08': 'Rajasthan',
  '09': 'Uttar Pradesh',
  '10': 'Bihar',
  '11': 'Sikkim',
  '12': 'Arunachal Pradesh',
  '13': 'Nagaland',
  '14': 'Manipur',
  '15': 'Mizoram',
  '16': 'Tripura',
  '17': 'Meghalaya',
  '18': 'Assam',
  '19': 'West Bengal',
  '20': 'Jharkhand',
  '21': 'Odisha',
  '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh',
  '24': 'Gujarat',
  '25': 'Daman and Diu',
  '26': 'Dadra and Nagar Haveli and Daman and Diu',
  '27': 'Maharashtra',
  '29': 'Karnataka',
  '30': 'Goa',
  '31': 'Lakshadweep',
  '32': 'Kerala',
  '33': 'Tamil Nadu',
  '34': 'Puducherry',
  '35': 'Andaman and Nicobar Islands',
  '36': 'Telangana',
  '37': 'Andhra Pradesh',
  '38': 'Ladakh',
  '97': 'Other Territory',
};

/// Verified states for counterparty GST review.
class CounterpartyGstStatus {
  static const String missing = 'missing';
  static const String unverified = 'unverified';
  static const String gstPending = 'gst_pending';
  static const String brokerVerified = 'broker_verified';
  static const String portalMatched = 'portal_matched';
  static const String registrationInactive = 'registration_inactive';
  static const String gstVerified = 'gst_verified';
  static const String rejected = 'rejected';

  static String displayLabel(String? status) {
    switch (status?.toLowerCase().trim()) {
      case missing:
        return 'GST Details Missing';
      case brokerVerified:
        return 'Broker Verified — Certificate Reviewed';
      case portalMatched:
        return 'GST Details Matched with Official Portal';
      case registrationInactive:
        return 'GST Registration Inactive';
      case gstPending:
        return 'Pending Verification';
      case gstVerified:
        return 'GST Verified by Government';
      case rejected:
        return 'Verification Failed';
      case unverified:
      default:
        return 'Unverified';
    }
  }
}

/// Fields read from a Form GST REG-06 certificate. Every value is an unverified
/// OCR suggestion; null means the field could not be identified.
@immutable
class GstCertificateData {
  final String? gstin;
  final bool gstinCorrected;
  final String? legalName;
  final String? tradeName;
  final String? constitution;
  final String? principalAddress;
  final String? pinCode;
  final String? registrationDate;
  final String? registrationType;
  final String? validityFrom;
  final String? validityTo;
  final String? issueDate;
  final String? gstStatus;
  final String? jurisdiction;
  final List<String> reviewNotes;
  final String? rawText;

  const GstCertificateData({
    this.gstin,
    this.gstinCorrected = false,
    this.legalName,
    this.tradeName,
    this.constitution,
    this.principalAddress,
    this.pinCode,
    this.registrationDate,
    this.registrationType,
    this.validityFrom,
    this.validityTo,
    this.issueDate,
    this.gstStatus = 'Active',
    this.jurisdiction,
    this.reviewNotes = const [],
    this.rawText,
  });

  bool get isEmpty =>
      (gstin == null || gstin!.trim().isEmpty) &&
      (legalName == null || legalName!.trim().isEmpty) &&
      (tradeName == null || tradeName!.trim().isEmpty) &&
      (principalAddress == null || principalAddress!.trim().isEmpty);

  bool get isNotEmpty => !isEmpty;

  /// State derived from the GSTIN's state code (not read from the address).
  String? get state => gstin == null ? null : GstinRules.stateOf(gstin!);

  GstCertificateData copyWith({
    String? gstin,
    bool? gstinCorrected,
    String? legalName,
    String? tradeName,
    String? constitution,
    String? principalAddress,
    String? pinCode,
    String? registrationDate,
    String? registrationType,
    String? validityFrom,
    String? validityTo,
    String? issueDate,
    String? gstStatus,
    String? jurisdiction,
    List<String>? reviewNotes,
    String? rawText,
  }) {
    return GstCertificateData(
      gstin: gstin ?? this.gstin,
      gstinCorrected: gstinCorrected ?? this.gstinCorrected,
      legalName: legalName ?? this.legalName,
      tradeName: tradeName ?? this.tradeName,
      constitution: constitution ?? this.constitution,
      principalAddress: principalAddress ?? this.principalAddress,
      pinCode: pinCode ?? this.pinCode,
      registrationDate: registrationDate ?? this.registrationDate,
      registrationType: registrationType ?? this.registrationType,
      validityFrom: validityFrom ?? this.validityFrom,
      validityTo: validityTo ?? this.validityTo,
      issueDate: issueDate ?? this.issueDate,
      gstStatus: gstStatus ?? this.gstStatus,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      rawText: rawText ?? this.rawText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gstin': gstin,
      'gstinCorrected': gstinCorrected,
      'legalName': legalName,
      'tradeName': tradeName,
      'constitution': constitution,
      'principalAddress': principalAddress,
      'pinCode': pinCode,
      'registrationDate': registrationDate,
      'registrationType': registrationType,
      'validityFrom': validityFrom,
      'validityTo': validityTo,
      'issueDate': issueDate,
      'gstStatus': gstStatus,
      'jurisdiction': jurisdiction,
      'reviewNotes': reviewNotes,
      'state': state,
    };
  }

  factory GstCertificateData.fromJson(Map<String, dynamic> json) {
    return GstCertificateData(
      gstin: json['gstin']?.toString(),
      gstinCorrected: json['gstinCorrected'] as bool? ?? false,
      legalName: json['legalName']?.toString(),
      tradeName: json['tradeName']?.toString(),
      constitution: json['constitution']?.toString(),
      principalAddress: json['principalAddress']?.toString(),
      pinCode: json['pinCode']?.toString(),
      registrationDate: json['registrationDate']?.toString(),
      registrationType: json['registrationType']?.toString(),
      validityFrom: json['validityFrom']?.toString(),
      validityTo: json['validityTo']?.toString(),
      issueDate: json['issueDate']?.toString(),
      gstStatus: json['gstStatus']?.toString() ?? 'Active',
      jurisdiction: json['jurisdiction']?.toString(),
      reviewNotes: (json['reviewNotes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

