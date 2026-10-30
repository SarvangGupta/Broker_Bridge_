import '../domain/cheque_leaf_data.dart';

/// Parses OCR text of an Indian Bank Cheque Leaf.
class ChequeLeafParser {
  const ChequeLeafParser();

  static final RegExp _ifscRegex = RegExp(r'\b([A-Z]{4}0[A-Z0-9]{6})\b');
  static final RegExp _accRegex = RegExp(
    r'(?:A[\/\.]?C|ACCOUNT|ACC)[\s\.:#No]*([0-9]{9,18})\b',
    caseSensitive: false,
  );
  static final RegExp _standaloneDigits = RegExp(r'\b([0-9]{9,18})\b');

  static final RegExp _branchRegex = RegExp(
    r'(?:BRANCH|BR[\.:]|BRANCH[\s:]+)([A-Za-z0-9\s,\-]+)',
    caseSensitive: false,
  );

  static final List<String> _knownBanks = [
    'State Bank of India',
    'HDFC Bank',
    'ICICI Bank',
    'Punjab National Bank',
    'Bank of Baroda',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'Canara Bank',
    'Union Bank of India',
    'IDFC FIRST Bank',
    'Yes Bank',
    'IndusInd Bank',
    'Bank of India',
    'Central Bank of India',
    'Indian Overseas Bank',
    'Indian Bank',
    'Bank of Maharashtra',
    'Punjab & Sind Bank',
    'UCO Bank',
    'Federal Bank',
  ];

  ChequeLeafData parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final notes = <String>[];

    // --- 1. IFSC Extraction ---
    String? ifsc;
    final ifscMatch = _ifscRegex.firstMatch(rawText.toUpperCase());
    if (ifscMatch != null) {
      ifsc = ifscMatch.group(1);
    } else {
      notes.add('IFSC code could not be detected automatically.');
    }

    // --- 2. Bank Name Extraction ---
    String? bankName;
    for (final b in _knownBanks) {
      if (rawText.toLowerCase().contains(b.toLowerCase())) {
        bankName = b;
        break;
      }
    }
    if (bankName == null && ifsc != null) {
      bankName = IfscRules.bankNameFromIfsc(ifsc);
    }

    // --- 3. Account Number Extraction ---
    String? accountNumber;
    final accMatch = _accRegex.firstMatch(rawText);
    if (accMatch != null) {
      accountNumber = accMatch.group(1);
    } else {
      // Fallback: check for 9-18 digit numbers that are not IFSC or dates
      for (final l in lines) {
        final digitMatch = _standaloneDigits.firstMatch(l);
        if (digitMatch != null) {
          final candidate = digitMatch.group(1)!;
          // Avoid dates or pincodes
          if (candidate.length >= 9 && candidate.length <= 18) {
            accountNumber = candidate;
            break;
          }
        }
      }
    }

    if (accountNumber == null) {
      notes.add('Account number was not clearly recognized.');
    }

    // --- 4. Branch Extraction ---
    String? branch;
    for (final l in lines) {
      final bMatch = _branchRegex.firstMatch(l);
      if (bMatch != null) {
        final candidate = bMatch.group(1)?.trim();
        if (candidate != null && candidate.isNotEmpty && candidate.length < 50) {
          branch = candidate.replaceAll(RegExp(r'[\.:]+$'), '').trim();
          break;
        }
      }
    }

    // --- 5. Account Holder Name Extraction ---
    String? accountHolderName;
    for (final l in lines) {
      final m = RegExp(r'(?:FOR|A\/C\s*OF|PAYABLE\s*TO)\s+([A-Za-z\s\.\&]+)', caseSensitive: false).firstMatch(l);
      if (m != null) {
        final name = m.group(1)?.trim();
        if (name != null && name.length >= 3 && !name.toLowerCase().contains('signatory')) {
          accountHolderName = name;
          break;
        }
      }
    }

    // Fallback: look around "Authorised Signatory"
    if (accountHolderName == null) {
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].toLowerCase().contains('signatory') || lines[i].toLowerCase().contains('signature')) {
          if (i > 0 && lines[i - 1].length >= 3 && !lines[i - 1].contains(RegExp(r'\d'))) {
            accountHolderName = lines[i - 1].trim();
            break;
          }
        }
      }
    }

    return ChequeLeafData(
      accountHolderName: accountHolderName,
      bankName: bankName,
      accountNumber: accountNumber,
      ifsc: ifsc,
      branch: branch,
      reviewNotes: notes,
      rawText: rawText,
    );
  }
}

