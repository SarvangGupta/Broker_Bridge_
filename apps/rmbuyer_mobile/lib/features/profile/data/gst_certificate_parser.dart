import '../domain/gst_certificate_data.dart';

/// Parses OCR text of a Form GST REG-06 Registration Certificate.
///
/// Ported from RMSeller's `GstCertificateParser` (same label/value handling for
/// ML Kit's split label and value columns), without the India Post PIN
/// directory: the state comes from the GSTIN's state code instead. Nothing is
/// guessed: a field that cannot be identified stays null.
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
    // Table borders are read as "|" at the start/end of cells; strip them.
    final lines = rawText
        .split('\n')
        .map(
          (l) => l.trim().replaceAll(RegExp(r'^[|¦]+\s*|\s*[|¦]+$'), '').trim(),
        )
        .where((l) => l.isNotEmpty)
        .toList();
    final notes = <String>[];

    // --- GSTIN (Registration Number) ---
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
            'GSTIN read as $rawGstin was corrected to $fixed using its check character. Please compare it with the certificate.',
          );
        }
      } else {
        gstin = rawGstin;
        notes.add(
          'GSTIN $rawGstin failed the GSTIN check-character test. Please verify it against the certificate.',
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
        RegExp(r'^[A-Za-z][A-Za-z .&\-()]{2,80}$').hasMatch(l) &&
        !_constitution.hasMatch(l) &&
        !_jurisdiction.hasMatch(l) &&
        !RegExp(
          r'^(?:superintendent|inspector|officer|commissioner|deputy|assistant)',
          caseSensitive: false,
        ).hasMatch(l);

    // --- Constitution, Legal Name, Trade Name ---
    String? constitution = sameLine(
      RegExp(r'constitution\s*of\s*business', caseSensitive: false),
    );
    var legalName = sameLine(
      RegExp(r'^\|?\s*(?:\d+\.\s*)?legal\s*name', caseSensitive: false),
    );
    var tradeName = sameLine(
      RegExp(
        r'^\|?\s*(?:\d+\.\s*)?[it]rade\s*name(?:\s*,?\s*if\s*any)?',
        caseSensitive: false,
      ),
    );
    final consIdx = lines.indexWhere((l) => _constitution.hasMatch(l));
    if (consIdx >= 0) constitution ??= lines[consIdx];
    if ((legalName == null || tradeName == null) && consIdx > 0) {
      // Value column: Legal Name and Trade Name sit directly above the constitution.
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
    if (tradeName != null &&
        RegExp(
          r'^(?:na|n/a|-+|nil|none)$',
          caseSensitive: false,
        ).hasMatch(tradeName)) {
      tradeName = null;
    }
    final corrected = <GstField>{};
    if (tradeName != null) {
      final fixed = repairTradeName(tradeName);
      if (fixed != tradeName) {
        notes.add(
          'Trade name read as "$tradeName" was corrected to "$fixed". Please compare it with the certificate.',
        );
        tradeName = fixed;
        corrected.add(GstField.tradeName);
      }
    }

    // --- Principal place of business (address with PIN) ---
    var address = sameLine(
      RegExp(
        r'address\s*of\s*principal\s*place\s*of\s*business',
        caseSensitive: false,
      ),
    );
    if (address == null) {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!isValueCandidate(l) ||
            !RegExp(r'\b[1-9][0-9]{5}\b').hasMatch(l) ||
            !l.contains(',')) {
          continue;
        }
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
    final pin = address == null
        ? null
        : RegExp(r'\b([1-9][0-9]{5})\b(?!.*\b[1-9][0-9]{5}\b)')
              .firstMatch(address)
              ?.group(1);

    // --- Dates ---
    // Value-column dates printed on their own line, in document order, with
    // duplicates kept (Date of Liability and Valid From are often equal).
    // Unambiguous OCR digit confusables are repaired; an unreadable date cell
    // is reported for manual review and never guessed.
    final standalone = <String>[];
    for (final l in lines) {
      final date = _repairDateCell(l);
      if (date != null) {
        standalone.add(date);
      } else if (_dateLikeCell.hasMatch(l)) {
        notes.add(
          'A date on the certificate could not be read (OCR read "$l"). Please enter it from the certificate.',
        );
      }
    }
    final liability = _dateIn(
      sameLine(RegExp(r'date\s*of\s*liability', caseSensitive: false)),
    );
    // Without a labelled value, the first standalone date is the Date of
    // Liability (row 6 precedes validity and issue date on REG-06).
    final registrationDate = liability ?? standalone.firstOrNull;

    // Validity: "From <date> To <date|Not Applicable>" on one line, else the
    // value column: liability (6), valid from (7), issue date (9). The second
    // date is Valid From only when the layout proves it (three dates, or the
    // liability date repeated); two different dates mean the second is the
    // issue date.
    final validityLine = lines
        .map(
          (l) => RegExp(
            r'(?:^|\bfrom\s*[:\-]?\s*)(\d{2}[\/\-\.]\d{2}[\/\-\.]\d{4})\s*to\b',
            caseSensitive: false,
          ).firstMatch(l),
        )
        .nonNulls
        .firstOrNull;

    // Look for date on the immediate lines after a standalone 'From' label.
    String? followingFromDate;
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].trim().toLowerCase();
      if (l == 'from' || l.startsWith('from:') || l.startsWith('from -')) {
        for (int j = i + 1; j <= i + 4 && j < lines.length; j++) {
          final d = _repairDateCell(lines[j]) ?? _dateIn(lines[j]);
          if (d != null) {
            followingFromDate = d;
            break;
          }
        }
        if (followingFromDate != null) break;
      }
    }

    String? layoutValidityFrom;
    if (standalone.length >= 2) {
      if (standalone.length >= 3 || standalone[1] == standalone[0]) {
        layoutValidityFrom = standalone[1];
      }
    }
    layoutValidityFrom ??= followingFromDate;

    final labelledValidityFrom =
        _dateIn(validityLine?.group(1)) ??
        _dateIn(sameLine(RegExp(r'^from\b', caseSensitive: false)));
    final validityFrom = labelledValidityFrom ?? layoutValidityFrom;
    if (labelledValidityFrom == null && layoutValidityFrom != null) {
      notes.add(
        'Valid-from date $layoutValidityFrom was identified from the layout. Please confirm it.',
      );
    }
    final hasValidityRow = lines.any(
      (l) => RegExp(
        r'(?:date|period)\s*of\s*validity',
        caseSensitive: false,
      ).hasMatch(l),
    );
    final toOnSameLine = lines
        .map(
          (l) => RegExp(
            r'\bto\s*[:\-]?\s*(not\s*applicable|\d{2}[\/\-\.]\d{2}[\/\-\.]\d{4})',
            caseSensitive: false,
          ).firstMatch(l)?.group(1),
        )
        .nonNulls
        .firstOrNull;
    final validityTo =
        (toOnSameLine == null
            ? null
            : _dateIn(toOnSameLine) ?? 'Not Applicable') ??
        _dateIn(sameLine(RegExp(r'^to\b', caseSensitive: false))) ??
        (hasValidityRow &&
                lines.any(
                  (l) => RegExp(
                    r'^not\s*applicable$',
                    caseSensitive: false,
                  ).hasMatch(l),
                )
            ? 'Not Applicable'
            : null);

    // Issue date must never be the Date of Liability, a validity date or the
    // signature timestamp (ported from RMSeller).
    var issueDate = _dateIn(
      sameLine(
        RegExp(
          r'date\s*of\s*issue(?:\s*of\s*certificate)?',
          caseSensitive: false,
        ),
      ),
    );
    if (issueDate == null) {
      final distinct = standalone.toSet().toList();
      final earliest = distinct.isEmpty
          ? null
          : (List.of(
              distinct,
            )..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)))).first;
      final excluded = {
        registrationDate,
        validityFrom,
        earliest,
      }.nonNulls.toSet();
      final candidates = distinct.where((d) => !excluded.contains(d)).toList()
        ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
      if (candidates.isNotEmpty) {
        // Issued on or after the liability date: take the latest remaining date.
        issueDate = candidates.last;
        notes.add(
          'Certificate issue date $issueDate was identified from the layout. Please confirm it.',
        );
      }
    }

    final registrationType =
        sameLine(RegExp(r'type\s*of\s*registration', caseSensitive: false)) ??
        lines.where((l) => _registrationType.hasMatch(l)).firstOrNull;

    return GstCertificateData(
      gstin: gstin,
      gstinCorrected: gstinCorrected,
      legalName: legalName,
      tradeName: tradeName,
      constitution: constitution,
      principalAddress: address,
      pinCode: pin,
      registrationDate: registrationDate,
      registrationType: registrationType,
      validityFrom: validityFrom,
      validityTo: validityTo,
      issueDate: issueDate,
      correctedFields: corrected,
      reviewNotes: notes,
    );
  }

  /// Common words in Indian agri/feed trade names. Used only to undo a single
  /// stray character inserted by OCR inside a word ("Paslhu" → "Pashu").
  static const List<String> tradeVocabulary = [
    'Pashu',
    'Aahar',
    'Ahar',
    'Udyog',
    'Traders',
    'Trading',
    'Feeds',
    'Feed',
    'Agro',
    'Industries',
    'Enterprises',
    'Mills',
    'Mill',
    'Dairy',
    'Krishi',
    'Kendra',
    'Bhandar',
    'Company',
    'Corporation',
    'Products',
    'Foods',
  ];

  /// Corrects a word only when deleting exactly one interior character turns
  /// it into a vocabulary word and the word is not already a vocabulary word.
  /// Everything else is returned unchanged: no global character substitution.
  static String repairTradeName(String name) {
    final vocab = {for (final v in tradeVocabulary) v.toLowerCase(): v};
    return name
        .split(' ')
        .map((word) {
          final lower = word.toLowerCase();
          if (word.length < 5 || vocab.containsKey(lower)) return word;
          final matches = <String>{};
          for (var i = 1; i < word.length - 1; i++) {
            final candidate = lower.substring(0, i) + lower.substring(i + 1);
            final hit = vocab[candidate];
            if (hit != null) matches.add(hit);
          }
          if (matches.length != 1) return word;
          final hit = matches.single;
          // Keep the OCR word's casing style (UPPER, lower or Title).
          if (word == word.toUpperCase()) return hit.toUpperCase();
          if (word == word.toLowerCase()) return hit.toLowerCase();
          return hit;
        })
        .join(' ');
  }

  /// Digit confusables that OCR produces in printed dates. Anything else
  /// (e.g. "J") is not mapped: such a cell is unreadable, not guessed.
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

  /// A cell shaped like a date (dd/mm/yyyy with OCR noise in day/month).
  static final RegExp _dateLikeCell = RegExp(
    r'^[0-9A-Za-z|]{2}[\/\-\.][0-9A-Za-z|]{2}[\/\-\.]\d{4}$',
  );

  /// A standalone date cell, with unambiguous confusables repaired, as
  /// dd/mm/yyyy; null when the line is not a confidently readable date.
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

  /// Validates a GSTIN with its check character. When it fails, tries the usual OCR
  /// confusions (O↔0, I↔1) only at positions whose expected class allows them, and
  /// returns the single variant that passes; null when none (or several) pass.
  static String? repairGstin(String raw) {
    final g = raw.toUpperCase();
    if (g.length != 15) return null;
    if (GstinRules.isValid(g)) return g;
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

  static String _sortKey(String ddmmyyyy) {
    final p = ddmmyyyy.split('/');
    return p.length == 3 ? '${p[2]}${p[1]}${p[0]}' : ddmmyyyy;
  }

  static String? _dateIn(String? s) {
    if (s == null) return null;
    final m = _date.firstMatch(s);
    return m == null ? null : '${m[1]}/${m[2]}/${m[3]}';
  }

  /// Fixes OCR punctuation slips ("Shanti Nagar. Gurjer" → "Shanti Nagar, Gurjer").
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
