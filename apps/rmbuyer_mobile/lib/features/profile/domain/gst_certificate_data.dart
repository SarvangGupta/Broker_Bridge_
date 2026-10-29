/// GSTIN structure rules. A valid GSTIN only proves the number is well formed;
/// it never proves the registration is genuine or that the buyer is verified.
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

/// Fields read from a Form GST REG-06 certificate. Every value is an unverified
/// OCR suggestion; null means the field could not be identified.
class GstCertificateData {
  final String? gstin;

  /// True when OCR confusables (O/0, I/1…) were repaired using the check character.
  final bool gstinCorrected;
  final String? legalName;
  final String? tradeName;
  final String? constitution;
  final String? principalAddress;
  final String? pinCode;
  final String? registrationDate;
  final String? registrationType;
  final String? validityFrom;

  /// "Not Applicable" for regular registrations without an end date.
  final String? validityTo;
  final String? issueDate;

  /// Fields (besides the GSTIN) that the parser corrected from the raw OCR
  /// text; the buyer is asked to compare them with the certificate.
  final Set<GstField> correctedFields;
  final List<String> reviewNotes;

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
    this.correctedFields = const {},
    this.reviewNotes = const [],
  });

  bool get isEmpty =>
      gstin == null &&
      legalName == null &&
      tradeName == null &&
      principalAddress == null;

  /// State derived from the GSTIN's state code (not read from the address).
  String? get state => gstin == null ? null : GstinRules.stateOf(gstin!);

  Map<GstField, String?> toFieldMap() => {
    GstField.gstin: gstin,
    GstField.legalName: legalName,
    GstField.tradeName: tradeName,
    GstField.constitution: constitution,
    GstField.address: principalAddress,
    GstField.pinCode: pinCode,
    GstField.registrationDate: registrationDate,
    GstField.registrationType: registrationType,
    GstField.validityFrom: validityFrom,
    GstField.validityTo: validityTo,
    GstField.issueDate: issueDate,
  };
}

enum GstField {
  gstin,
  legalName,
  tradeName,
  constitution,
  address,
  pinCode,
  registrationDate,
  registrationType,
  validityFrom,
  validityTo,
  issueDate,
}

enum GstFieldError {
  required,
  invalidFormat,
  invalidChecksum,
  invalidPin,
  stateMismatch,
}

/// Client-side checks on the reviewed values before submission. The server
/// must repeat them; passing here never marks the buyer verified.
class GstSubmissionValidation {
  const GstSubmissionValidation._();

  static const Set<GstField> requiredFields = {
    GstField.gstin,
    GstField.legalName,
    GstField.address,
    GstField.pinCode,
  };

  static Map<GstField, GstFieldError> validate(Map<GstField, String> values) {
    final errors = <GstField, GstFieldError>{};
    for (final f in requiredFields) {
      if ((values[f] ?? '').trim().isEmpty) errors[f] = GstFieldError.required;
    }
    final gstin = GstinRules.normalize(values[GstField.gstin] ?? '');
    if (gstin.isNotEmpty) {
      if (!GstinRules.hasValidFormat(gstin)) {
        errors[GstField.gstin] = GstFieldError.invalidFormat;
      } else if (!GstinRules.isValid(gstin)) {
        errors[GstField.gstin] = GstFieldError.invalidChecksum;
      }
    }
    final pin = (values[GstField.pinCode] ?? '').trim();
    if (pin.isNotEmpty && !RegExp(r'^[1-9][0-9]{5}$').hasMatch(pin)) {
      errors[GstField.pinCode] = GstFieldError.invalidPin;
    }
    // The GSTIN state code must match the state named in the principal address.
    final address = values[GstField.address] ?? '';
    final gstinState = GstinRules.isValid(gstin)
        ? GstinRules.stateOf(gstin)
        : null;
    final named = addressStates(address);
    if (gstinState != null &&
        named.isNotEmpty &&
        !named.contains(gstinState) &&
        !errors.containsKey(GstField.address)) {
      errors[GstField.address] = GstFieldError.stateMismatch;
    }
    return errors;
  }

  /// GST state names written in [address] (whole words, case-insensitive).
  static Set<String> addressStates(String address) => {
    for (final s in gstStateCodes.values)
      if (RegExp(
        '\\b${RegExp.escape(s)}\\b',
        caseSensitive: false,
      ).hasMatch(address))
        s,
  };
}

enum GstIdentityIssue {
  /// The profile already has a different GSTIN.
  gstinDiffers,

  /// The profile's company name matches neither the legal nor the trade name.
  nameDiffers,
}

/// Compares certificate values with the saved profile. A mismatch never
/// changes the profile or the company link; it only requires the buyer to
/// confirm the certificate is theirs before submitting.
class GstIdentityCheck {
  const GstIdentityCheck._();

  static Set<GstIdentityIssue> compare({
    required String? savedGstin,
    required String? savedCompanyName,
    required String gstin,
    required String legalName,
    required String tradeName,
  }) {
    final issues = <GstIdentityIssue>{};
    final saved = GstinRules.normalize(savedGstin ?? '');
    final cert = GstinRules.normalize(gstin);
    if (saved.isNotEmpty && cert.isNotEmpty && saved != cert) {
      issues.add(GstIdentityIssue.gstinDiffers);
    }
    final company = _nameKey(savedCompanyName ?? '');
    final names = [
      _nameKey(legalName),
      _nameKey(tradeName),
    ].where((n) => n.isNotEmpty);
    if (company.isNotEmpty &&
        names.isNotEmpty &&
        !names.any(
          (n) => n == company || n.contains(company) || company.contains(n),
        )) {
      issues.add(GstIdentityIssue.nameDiffers);
    }
    return issues;
  }

  /// Lower-case words without punctuation or legal-form words, so
  /// "M/s. Shiv Shanker Pashu Aahar Udyog Pvt Ltd" ≈ "Shiv Shanker Pashu Aahar Udyog".
  static String _nameKey(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where(
        (w) =>
            w.isNotEmpty &&
            !const {
              'm',
              's',
              'ms',
              'the',
              'pvt',
              'private',
              'ltd',
              'limited',
              'llp',
              'co',
              'and',
            }.contains(w),
      )
      .join(' ');
}

/// The reviewed values prepared for submission: what the buyer confirmed,
/// what OCR read, and which fields differ. Built from the form as displayed,
/// so edits made before validation or a retry are what gets sent.
class GstSubmissionDraft {
  final Map<GstField, String?> submitted;
  final Map<GstField, String?> ocr;
  final Set<GstField> editedFields;

  const GstSubmissionDraft._(this.submitted, this.ocr, this.editedFields);

  factory GstSubmissionDraft.fromForm(
    Map<GstField, String> formValues,
    GstCertificateData ocrData,
  ) {
    final ocr = ocrData.toFieldMap();
    final submitted = <GstField, String?>{};
    for (final f in GstField.values) {
      final v = (formValues[f] ?? '').trim();
      // Empty stays null: absent fields are never filled with a placeholder.
      submitted[f] = v.isEmpty
          ? null
          : f == GstField.gstin
          ? GstinRules.normalize(v)
          : v;
    }
    return GstSubmissionDraft._(submitted, ocr, {
      for (final f in GstField.values)
        if (submitted[f] != ocr[f]) f,
    });
  }

  bool get gstinEdited => editedFields.contains(GstField.gstin);

  /// Request body for the future `submit_buyer_gst_verification` RPC. It holds
  /// no status, verification or company fields: the server derives the company
  /// from the session and sets the status itself.
  Map<String, Object?> toPayload() => {
    'submitted': {for (final e in submitted.entries) e.key.name: e.value},
    'ocr': {for (final e in ocr.entries) e.key.name: e.value},
    'edited_fields': [for (final f in editedFields) f.name],
  };
}
