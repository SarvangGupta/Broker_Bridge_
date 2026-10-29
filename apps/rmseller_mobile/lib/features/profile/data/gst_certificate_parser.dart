import '../domain/gst_certificate_extracted_data.dart';
import 'india_pincode_directory.dart';

/// Parses OCR text of a Form GST REG-06 Registration Certificate.
///
/// On-device OCR returns the certificate's table as two separate columns (all labels,
/// then all values, not always in order), so each field is read from its label on the
/// same line when present, otherwise recognised by its own shape. Nothing is guessed:
/// a field that cannot be identified stays null.
class GstCertificateParser {
  const GstCertificateParser();

  static final RegExp _gstinLoose = RegExp(r'\b([0-9O]{2}[A-Z]{5}[0-9OIL]{4}[A-Z][0-9A-Z]Z[0-9A-Z])\b');
  static final RegExp _date = RegExp(r'\b(\d{2})[\/\-\.](\d{2})[\/\-\.](\d{4})\b');

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

  static final RegExp _jurisdiction = RegExp(r'\b(?:circle|ward|range|division|zone|ghatak|commissionerate|unit)\b', caseSensitive: false);

  GstCertificateExtractedData parse(String rawText) {
    // Table borders are read as "|" at the start/end of cells ("|HARI SHANKAR KHANDELWAL",
    // "|16/06/2022"); strip them so labels and values are recognised.
    final lines = rawText
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'^[|¦]+\s*|\s*[|¦]+$'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final notes = <String>[];

    // --- GSTIN (Registration Number) ---
    String? gstin;
    var gstinCorrected = false;
    final labelled = RegExp(r'registration\s*number\s*[:\-]?\s*([0-9A-Z]{15})', caseSensitive: false).firstMatch(rawText);
    final rawGstin = labelled?.group(1)?.toUpperCase() ?? _gstinLoose.firstMatch(rawText.toUpperCase())?.group(1);
    if (rawGstin != null) {
      final fixed = repairGstin(rawGstin);
      if (fixed != null) {
        gstin = fixed;
        gstinCorrected = fixed != rawGstin;
        if (gstinCorrected) {
          notes.add('GSTIN read as $rawGstin was corrected to $fixed using its check character. Please compare it with the certificate.');
        }
      } else {
        gstin = rawGstin;
        notes.add('GSTIN $rawGstin failed the GSTIN check-character test. Please verify it against the certificate.');
      }
    }

    String? sameLine(RegExp label) {
      for (final l in lines) {
        final m = label.firstMatch(l);
        if (m != null) {
          final v = l.substring(m.end).replaceFirst(RegExp(r'^[\s:\-|]+'), '').trim();
          if (v.isNotEmpty) return v;
        }
      }
      return null;
    }

    bool isValueCandidate(String l) => !_labelLine.hasMatch(l) && !_headerLine.hasMatch(l);
    bool isNameLike(String l) =>
        isValueCandidate(l) &&
        RegExp(r'^[A-Za-z][A-Za-z .&\-()]{2,80}$').hasMatch(l) &&
        !_constitution.hasMatch(l) &&
        !_jurisdiction.hasMatch(l) &&
        !RegExp(r'^(?:superintendent|inspector|officer|commissioner|deputy|assistant)', caseSensitive: false).hasMatch(l);

    // --- Constitution, Legal Name, Trade Name ---
    String? constitution = sameLine(RegExp(r'constitution\s*of\s*business', caseSensitive: false));
    var legalName = sameLine(RegExp(r'^\|?\s*(?:\d+\.\s*)?legal\s*name', caseSensitive: false));
    var tradeName = sameLine(RegExp(r'^\|?\s*(?:\d+\.\s*)?[it]rade\s*name(?:\s*,?\s*if\s*any)?', caseSensitive: false));
    final consIdx = lines.indexWhere((l) => _constitution.hasMatch(l));
    if (consIdx >= 0) constitution ??= lines[consIdx];
    if ((legalName == null || tradeName == null) && consIdx > 0) {
      // Value column: Legal Name and Trade Name are printed directly above the constitution.
      // OCR noise without Latin text (e.g. the emblem motto read as "ाथगेय जग)") can sit
      // between the names and the constitution; skip it, but stop at any real label/value.
      final above = <String>[];
      for (var i = consIdx - 1; i >= 0 && above.length < 2; i--) {
        if (RegExp(r'[A-Za-z]').allMatches(lines[i]).length < 3) continue;
        if (!isNameLike(lines[i])) break;
        above.insert(0, lines[i]);
      }
      if (above.length == 2) {
        legalName ??= above[0];
        tradeName ??= above[1];
      } else if (above.length == 1) {
        legalName ??= above[0];
      }
    }
    if (tradeName != null && RegExp(r'^(?:na|n/a|-+|nil|none)$', caseSensitive: false).hasMatch(tradeName)) tradeName = null;

    // --- Principal place of business (address with PIN) ---
    var address = sameLine(RegExp(r'address\s*of\s*principal\s*place\s*of\s*business', caseSensitive: false));
    if (address == null) {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!isValueCandidate(l) || !RegExp(r'\b[1-9][0-9]{5}\b').hasMatch(l) || !l.contains(',')) continue;
        // Join a wrapped address: preceding comma-ended value lines belong to it.
        final parts = [l];
        for (var j = i - 1; j >= 0 && parts.length < 3; j--) {
          if (isValueCandidate(lines[j]) && lines[j].endsWith(',')) {
            parts.insert(0, lines[j]);
          } else {
            break;
          }
        }
        address = parts.join(' ');
        break;
      }
    }
    if (address != null) address = _normaliseAddress(address);

    String? pin;
    String? state;
    String? district;
    if (address != null) {
      pin = RegExp(r'\b([1-9][0-9]{5})\b(?!.*\b[1-9][0-9]{5}\b)').firstMatch(address)?.group(1);
      final r = IndiaPinCodeDirectory.lookup(pin);
      if (pin != null && r == null) {
        notes.add('PIN code $pin was not found in the India Post directory. Please verify it.');
      } else if (r != null) {
        if (r.isStateAmbiguous) {
          notes.add('PIN code $pin is listed under more than one state (${r.stateCandidates.join(', ')}). Please select the state and district.');
        } else {
          state = r.stateName;
          final conflict = IndiaPinCodeDirectory.detectAddressConflict(pin, address);
          if (conflict != null) notes.add(conflict);
          if (r.districtName.isNotEmpty) {
            district = r.districtName;
          } else if (r.isAmbiguous) {
            final mentioned = r.districtCandidates.where((d) => address!.toLowerCase().contains(d.toLowerCase())).toList();
            if (mentioned.length == 1) {
              district = mentioned.first;
            } else {
              notes.add('PIN code $pin covers more than one district (${r.districtCandidates.join(', ')}). Please select the district.');
            }
          }
        }
      }
    }

    // --- Jurisdictional Office ---
    var office = sameLine(RegExp(r'jurisdictional\s*office', caseSensitive: false));
    office ??= lines.where((l) => isValueCandidate(l) && _jurisdiction.hasMatch(l) && l != address).firstOrNull;
    if (office != null) {
      office = office
          .replaceAllMapped(RegExp(r'(\S)\s*-\s+(?=\S)'), (m) => '${m[1]} - ')
          .replaceAll(RegExp(r'\s*/\s*'), ' / ')
          .trim();
    }

    // --- Dates: issue date must never be the Date of Liability or a validity date ---
    var issueDate = _dateIn(sameLine(RegExp(r'date\s*of\s*issue(?:\s*of\s*certificate)?', caseSensitive: false)));
    final liability = _dateIn(sameLine(RegExp(r'date\s*of\s*liability', caseSensitive: false)));
    var issueInferred = false;
    if (issueDate == null) {
      // Value column: standalone date lines. Validity lines carry "From"/"To".
      final standalone = lines
          .where((l) => RegExp(r'^\d{2}[\/\-\.]\d{2}[\/\-\.]\d{4}$').hasMatch(l))
          .map((l) => l.replaceAll(RegExp(r'[\-\.]'), '/'))
          .toSet()
          .toList();
      final validityFrom = lines.map((l) => RegExp(r'^(\d{2}[\/\-\.]\d{2}[\/\-\.]\d{4})\s*to\b', caseSensitive: false).firstMatch(l)?.group(1)).nonNulls.firstOrNull;
      final earliest = standalone.isEmpty ? null : (standalone..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)))).first;
      final excluded = {liability, validityFrom?.replaceAll(RegExp(r'[\-\.]'), '/'), earliest}.nonNulls.toSet();
      final candidates = standalone.where((d) => !excluded.contains(d)).toList()
        ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
      if (candidates.isNotEmpty) {
        // The certificate is issued on or after the liability date: take the latest remaining date.
        issueDate = candidates.last;
        issueInferred = true;
        notes.add('Certificate issue date $issueDate was identified from the layout. Please confirm it.');
      } else if (standalone.isNotEmpty) {
        notes.add('Certificate issue date could not be told apart from the liability date. Please enter it.');
      }
    }

    return GstCertificateExtractedData(
      legalName: legalName,
      tradeName: tradeName,
      gstin: gstin,
      gstinCorrected: gstinCorrected,
      constitution: constitution,
      principalAddress: address,
      pinCode: pin,
      state: state,
      district: district,
      jurisdictionalOffice: office,
      issueDate: issueDate,
      issueDateInferred: issueInferred,
      dateOfLiability: liability ?? _dateIn(lines.where((l) => RegExp(r'^\d{2}[\/\-\.]\d{2}[\/\-\.]\d{4}$').hasMatch(l)).firstOrNull),
      reviewNotes: notes,
    );
  }

  /// Validates a GSTIN with its check character. When it fails, tries the usual OCR
  /// confusions (O↔0, I↔1) only at positions whose expected class allows them, and
  /// returns the single variant that passes; null when none (or several) pass.
  static String? repairGstin(String raw) {
    final g = raw.toUpperCase();
    if (g.length != 15) return null;
    if (isValidGstin(g)) return g;
    // Positions: 0-1 digits, 2-6 letters, 7-10 digits, 11 letter, 12 alnum, 13 'Z', 14 check.
    const digitPos = {0, 1, 7, 8, 9, 10};
    const letterPos = {2, 3, 4, 5, 6, 11};
    const toDigit = {'O': '0', 'I': '1', 'L': '1', 'S': '5', 'B': '8'};
    const toLetter = {'0': 'O', '1': 'I', '5': 'S', '8': 'B'};
    final options = <List<String>>[];
    for (var i = 0; i < 15; i++) {
      final c = g[i];
      final opts = {c};
      if (digitPos.contains(i) && toDigit.containsKey(c)) opts.add(toDigit[c]!);
      if (letterPos.contains(i) && toLetter.containsKey(c)) opts.add(toLetter[c]!);
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
        if (isValidGstin(acc)) valid.add(acc);
        return;
      }
      for (final o in options[i]) {
        walk(i + 1, acc + o);
      }
    }

    walk(0, '');
    return valid.length == 1 ? valid.first : null;
  }

  /// GSTIN structure + check character (mod-36 algorithm used by GSTN).
  static bool isValidGstin(String g) {
    if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$').hasMatch(g)) return false;
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var sum = 0;
    for (var i = 0; i < 14; i++) {
      final p = chars.indexOf(g[i]) * (i.isEven ? 1 : 2);
      sum += p ~/ 36 + p % 36;
    }
    return chars[(36 - sum % 36) % 36] == g[14];
  }

  static String? _dateIn(String? s) {
    if (s == null) return null;
    final m = _date.firstMatch(s);
    return m == null ? null : '${m[1]}/${m[2]}/${m[3]}';
  }

  static String _sortKey(String ddmmyyyy) {
    final p = ddmmyyyy.split('/');
    return p.length == 3 ? '${p[2]}${p[1]}${p[0]}' : ddmmyyyy;
  }

  /// Fixes OCR punctuation slips ("Shanti Nagar. Gurjer" → "Shanti Nagar, Gurjer") without
  /// changing words; full stops inside abbreviations ("Raj.", "No.") are kept.
  static String _normaliseAddress(String a) => a
      .replaceAllMapped(RegExp(r'([a-z]{3,})\.\s+(?=[A-Z][a-z])'), (m) => '${m[1]}, ')
      .replaceAll(RegExp(r'\s+,'), ',')
      .replaceAll(RegExp(r',(?:\s*,)+'), ',')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}
