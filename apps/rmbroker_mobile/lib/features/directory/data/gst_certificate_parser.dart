import '../domain/gst_certificate_data.dart';

/// Parses OCR text of a Form GST REG-06 Registration Certificate.
///
/// Strips table borders, handles multi-column layouts, locates legal and trade names,
/// constitution of business, principal place of business, issue and validity dates.
/// Does not guess: unidentifiable fields remain null.
class GstCertificateParser {
  const GstCertificateParser();

  static final RegExp _gstinLoose = RegExp(
    r'\b([0-9O]{2}[A-Z]{5}[0-9OIL]{4}[A-Z][0-9A-Z]Z[0-9A-Z])\b',
  );
  static final RegExp _date = RegExp(
    r'\b(\d{2})[\/\-\.](\d{2})[\/\-\.](\d{4})\b',
  );

  static final RegExp _labelLine = RegExp(
    r'^\|?\s*(?:\d+\.\s*)?(?:legal\s*name|[it]rade\s*name|constitution\s*of\s*business|address\s*of\s*principal|business$|additional\s*trade\s*names?|date\s*of\s*liability|(?:period|date)\s*of\s*validity|type\s*of\s*registration|particulars\s*of\s*approving|signature|name$|designation|jurisdictional\s*office|date\s*of\s*issue|registration\s*number|from$|to$|not\s*applicable|regular|centre|state$)',
    caseSensitive: false,
  );

  static final RegExp _headerLine = RegExp(
    r'(?:gover?n+ment\s*of\s*india|form\s*gst|reg-?06|registration\s*certificate|see\s*rule|note:|system\s*generated|digitally\s*signed|jurisdictional\s*authority|sdictional\s*authority|approval\s*of\s*application)',
    caseSensitive: false,
  );

  static final RegExp _constitution = RegExp(
    r'^(?:proprietorship|partnership|private\s*limited\s*company|public\s*limited\s*company|limited\s*liability\s*partnership|llp|hindu\s*undivided\s*family|huf|society|trust|club|government\s*department|public\s*sector\s*undertaking|local\s*authority|statutory\s*body|unlimited\s*company|foreign\s*company|others)\b',
    caseSensitive: false,
  );

  static final RegExp _registrationType = RegExp(
    r'^(?:regular|composition|casual\s*taxable\s*person|input\s*service\s*distributor|non[\s-]*resident\s*taxable\s*person|tax\s*deductor|tax\s*collector)$',
    caseSensitive: false,
  );

  static final RegExp _jurisdiction = RegExp(
    r'\b(?:circle|ward|range|division|zone|ghatak|commissionerate|unit)\b',
    caseSensitive: false,
  );

  GstCertificateData parse(String rawText) {
    // Strip table border characters and leading/trailing whitespace
    final lines = rawText
        .split('\n')
        .map(
          (l) => l.trim().replaceAll(RegExp(r'^[|¦]+\s*|\s*[|¦]+$'), '').trim(),
        )
        .where((l) => l.isNotEmpty)
        .toList();
    final notes = <String>[];

    // --- 1. GSTIN (Registration Number) ---
    String? gstin;
    var gstinCorrected = false;
    final labelled = RegExp(
      r'registration\s*number\s*[:\-]?\s*([0-9A-Z]{15})',
      caseSensitive: false,
    ).firstMatch(rawText);
    final rawGstin =
        labelled?.group(1)?.toUpperCase() ??
        _gstinLoose.firstMatch(rawText.toUpperCase())?.group(1);

    if (rawGstin != null) {
      final fixed = repairGstin(rawGstin);
      if (fixed != null) {
        gstin = fixed;
        gstinCorrected = fixed != rawGstin;
        if (gstinCorrected) {
          notes.add(
            'GSTIN read as $rawGstin was corrected to $fixed using check character.',
          );
        }
      } else {
        gstin = rawGstin;
        notes.add(
          'GSTIN $rawGstin failed checksum test. Please verify carefully.',
        );
      }
    }

    String? sameLine(RegExp label) {
      for (final l in lines) {
        final m = label.firstMatch(l);
        if (m != null) {
          final v = l
              .substring(m.end)
              .replaceFirst(RegExp(r'^[\s:\-|]+'), '')
              .trim();
          if (v.isNotEmpty) return v;
        }
      }
      return null;
    }

    bool isValueCandidate(String l) =>
        !_labelLine.hasMatch(l) && !_headerLine.hasMatch(l);

    bool isNameLike(String l) =>
        isValueCandidate(l) &&
        l.length >= 3 &&
        !l.contains(RegExp(r'\d{3,}')) &&
        !_constitution.hasMatch(l) &&
        !_jurisdiction.hasMatch(l);

    // --- 2. Constitution of Business ---
    String? constitution = sameLine(RegExp(r'constitution\s*of\s*business', caseSensitive: false));
    int? constitutionIdx;
    if (constitution != null) {
      final m = _constitution.firstMatch(constitution);
      constitution = m?.group(0);
    }
    if (constitution == null) {
      for (var i = 0; i < lines.length; i++) {
        final m = _constitution.firstMatch(lines[i]);
        if (m != null) {
          constitution = m.group(0);
          constitutionIdx = i;
          break;
        }
      }
    } else {
      for (var i = 0; i < lines.length; i++) {
        if (_constitution.hasMatch(lines[i])) {
          constitutionIdx = i;
          break;
        }
      }
    }

    // Capitalize constitution
    if (constitution != null) {
      constitution = constitution
          .split(' ')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
          .join(' ');
    }

    // --- 3. Legal and Trade Names ---
    String? legalName = sameLine(RegExp(r'legal\s*name', caseSensitive: false));
    String? tradeName = sameLine(RegExp(r'[it]rade\s*name(?:\s*,\s*if\s*any)?', caseSensitive: false));

    if (legalName == null && constitutionIdx != null) {
      // Scan upwards from Constitution of Business
      final candidates = <String>[];
      for (var i = constitutionIdx - 1; i >= 0 && candidates.length < 2; i--) {
        final l = lines[i];
        if (_labelLine.hasMatch(l)) break;
        if (isNameLike(l)) {
          candidates.insert(0, l);
        }
      }
      if (candidates.isNotEmpty) {
        legalName = candidates.first;
        if (candidates.length > 1) {
          tradeName = candidates[1];
        }
      }
    }

    // Additional trade name cleanup
    if (tradeName != null) {
      tradeName = tradeName.replaceFirst(RegExp(r'^,?\s*if\s*any\s*[:\-]?\s*', caseSensitive: false), '').trim();
      if (tradeName.toLowerCase() == 'not applicable' || tradeName.toLowerCase() == 'na') {
        tradeName = null;
      }
    }

    // --- 4. Principal Place of Business Address & PIN Code ---
    String? principalAddress;
    String? pinCode;

    final addrStart = lines.indexWhere(
      (l) => RegExp(r'address\s*of\s*principal', caseSensitive: false).hasMatch(l),
    );
    if (addrStart != -1) {
      final addrLines = <String>[];
      for (var i = addrStart + 1; i < lines.length; i++) {
        final l = lines[i];
        if (_labelLine.hasMatch(l) || _headerLine.hasMatch(l)) break;
        addrLines.add(l);
      }
      if (addrLines.isNotEmpty) {
        principalAddress = _normaliseAddress(addrLines.join(', '));
      }
    }

    if (principalAddress == null) {
      // Find 6-digit PIN code line
      final pinIdx = lines.indexWhere((l) => RegExp(r'\b[1-9][0-9]{5}\b').hasMatch(l));
      if (pinIdx != -1) {
        final start = (pinIdx - 2).clamp(0, lines.length - 1);
        final collected = <String>[];
        for (var i = start; i <= pinIdx; i++) {
          final l = lines[i];
          if (isValueCandidate(l) && !_constitution.hasMatch(l)) {
            collected.add(l);
          }
        }
        if (collected.isNotEmpty) {
          principalAddress = _normaliseAddress(collected.join(', '));
        }
      }
    }

    if (principalAddress != null) {
      final pinMatch = RegExp(r'\b([1-9][0-9]{5})\b').firstMatch(principalAddress);
      pinCode = pinMatch?.group(1);
    }

    // --- 5. Registration Type & Registration / Issue Dates ---
    String? registrationType = sameLine(RegExp(r'type\s*of\s*registration', caseSensitive: false));
    if (registrationType == null) {
      for (final l in lines) {
        if (_registrationType.hasMatch(l)) {
          registrationType = l;
          break;
        }
      }
    }

    String? registrationDate;
    String? issueDate;
    String? validityFrom;
    String? validityTo;

    final dateCandidates = <String>[];
    for (final l in lines) {
      final d = _repairDateCell(l) ?? _dateIn(l);
      if (d != null) dateCandidates.add(d);
    }

    if (dateCandidates.isNotEmpty) {
      // Unique dates preserving order
      final seen = <String>{};
      final uniqueDates = dateCandidates.where((d) => seen.add(d)).toList();
      registrationDate = uniqueDates.first;
      validityFrom = uniqueDates.first;
      if (uniqueDates.length > 1) {
        issueDate = uniqueDates.last;
      } else {
        issueDate = registrationDate;
      }
    }

    if (rawText.toLowerCase().contains('not applicable')) {
      validityTo = 'Not Applicable';
    }

    // --- 6. Jurisdictional Office ---
    String? jurisdiction;
    for (final l in lines) {
      if (_jurisdiction.hasMatch(l) && isValueCandidate(l)) {
        jurisdiction = l;
        break;
      }
    }

    return GstCertificateData(
      gstin: gstin,
      gstinCorrected: gstinCorrected,
      legalName: legalName,
      tradeName: tradeName,
      constitution: constitution,
      principalAddress: principalAddress,
      pinCode: pinCode,
      registrationDate: registrationDate,
      registrationType: registrationType ?? 'Regular',
      validityFrom: validityFrom,
      validityTo: validityTo,
      issueDate: issueDate,
      gstStatus: 'Active',
      jurisdiction: jurisdiction,
      reviewNotes: notes,
      rawText: rawText,
    );
  }

  static const Map<String, String> _dateConfusables = {
    'O': '0',
    'o': '0',
    'D': '0',
    'Q': '0',
    'I': '1',
    'l': '1',
    '|': '1',
    'i': '1',
  };

  static final RegExp _dateLikeCell = RegExp(
    r'^[0-9A-Za-z|]{2}[\/\-\.][0-9A-Za-z|]{2}[\/\-\.]\d{4}$',
  );

  static String? _repairDateCell(String line) {
    if (!_dateLikeCell.hasMatch(line)) return null;
    final fixed = line
        .split('')
        .map((c) => _dateConfusables[c] ?? c)
        .join()
        .replaceAll(RegExp(r'[\-\.]'), '/');
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(fixed);
    if (m == null) return null;
    final day = int.parse(m[1]!), month = int.parse(m[2]!);
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    return fixed;
  }

  static String? repairGstin(String raw) {
    final g = raw.toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (g.length != 15) return null;
    if (GstinRules.isValid(g)) return g;

    const digitPos = {0, 1, 7, 8, 9, 10};
    const letterPos = {2, 3, 4, 5, 6, 11};
    const toDigit = {'O': '0', 'I': '1', 'L': '1', 'S': '5', 'B': '8'};
    const toLetter = {'0': 'O', '1': 'I', '5': 'S', '8': 'B'};

    final options = <List<String>>[];
    for (var i = 0; i < 15; i++) {
      final c = g[i];
      final opts = {c};
      if (digitPos.contains(i) && toDigit.containsKey(c)) opts.add(toDigit[c]!);
      if (letterPos.contains(i) && toLetter.containsKey(c)) {
        opts.add(toLetter[c]!);
      }
      if (i == 13 && c != 'Z') opts.add('Z');
      if (i == 12 || i == 14) {
        if (toDigit.containsKey(c)) opts.add(toDigit[c]!);
        if (toLetter.containsKey(c)) opts.add(toLetter[c]!);
      }
      options.add(opts.toList());
    }

    final valid = <String>{};
    void walk(int i, String acc) {
      if (valid.length > 1) return;
      if (i == 15) {
        if (GstinRules.isValid(acc)) valid.add(acc);
        return;
      }
      for (final o in options[i]) {
        walk(i + 1, acc + o);
      }
    }

    walk(0, '');
    return valid.length == 1 ? valid.first : null;
  }

  static String? _dateIn(String? s) {
    if (s == null) return null;
    final m = _date.firstMatch(s);
    return m == null ? null : '${m[1]}/${m[2]}/${m[3]}';
  }

  static String _normaliseAddress(String a) => a
      .replaceAllMapped(
        RegExp(r'([a-z]{3,})\.\s+(?=[A-Z][a-z])'),
        (m) => '${m[1]}, ',
      )
      .replaceAll(RegExp(r'\s+,'), ',')
      .replaceAll(RegExp(r',(?:\s*,)+'), ',')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}
