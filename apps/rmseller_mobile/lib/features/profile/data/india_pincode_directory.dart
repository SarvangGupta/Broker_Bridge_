import 'package:flutter/foundation.dart';

import 'india_pincode_data.dart';

/// Structured result of an Indian PIN code lookup.
@immutable
class PinCodeLookupResult {
  final String pinCode;
  final String stateName;
  final String stateCode;

  /// Single district when the PIN maps to exactly one; empty when ambiguous.
  final String districtName;

  /// Every district India Post lists for this PIN (more than one for ~6% of PINs).
  final List<String> districtCandidates;

  /// Every state India Post lists for this PIN; more than one for 46 PINs (source
  /// inconsistencies, mostly Telangana/Andhra Pradesh). [stateName] is empty then.
  final List<String> stateCandidates;
  final bool isValid;

  const PinCodeLookupResult({
    required this.pinCode,
    required this.stateName,
    required this.stateCode,
    required this.districtName,
    this.districtCandidates = const [],
    this.stateCandidates = const [],
    this.isValid = true,
  });

  bool get isAmbiguous => districtCandidates.length > 1;
  bool get isStateAmbiguous => stateCandidates.length > 1;

  @override
  String toString() =>
      'PinCodeLookupResult(pin: $pinCode, district: $districtName, candidates: $districtCandidates, state: $stateName [$stateCode])';
}

/// Offline Indian PIN code directory backed by the India Post "All India Pincode Directory"
/// (data.gov.in, GODL-India). See `india_pincode_data.dart` for provenance.
///
/// A PIN identifies postal areas and their administrative district/state; it never
/// establishes a street address.
class IndiaPinCodeDirectory {
  const IndiaPinCodeDirectory._();

  static final RegExp _pinRegex = RegExp(r'^[1-9][0-9]{5}$');

  static Map<String, List<int>>? _index;

  static Map<String, List<int>> get _pinIndex {
    return _index ??= {
      for (final entry in kPinIndex.split(';'))
        if (entry.isNotEmpty)
          entry.substring(0, 6): entry.substring(7).split(',').map(int.parse).toList(),
    };
  }

  /// Validates whether a string is a formally valid 6-digit Indian PIN code.
  static bool isValidPin(String? pin) {
    if (pin == null) return false;
    return _pinRegex.hasMatch(pin.trim());
  }

  /// True when the PIN exists in the India Post directory.
  static bool isKnownPin(String? pin) => isValidPin(pin) && _pinIndex.containsKey(pin!.trim());

  /// Looks up state and district(s) for a PIN. Returns null if the PIN is malformed or
  /// not present in the India Post directory (never guesses from the prefix).
  static PinCodeLookupResult? lookup(String? pin) {
    if (!isValidPin(pin)) return null;
    final cleaned = pin!.trim();
    final idx = _pinIndex[cleaned];
    if (idx == null || idx.isEmpty) return null;

    final districts = <String>[];
    final states = <String>{};
    for (final i in idx) {
      final parts = kPinDistricts[i].split('|');
      districts.add(parts[0]);
      states.add(kPinStates[int.parse(parts[1])]);
    }
    // A PIN listed under two states is never resolved to either; the seller must review.
    final state = states.length == 1 ? states.first : '';
    return PinCodeLookupResult(
      pinCode: cleaned,
      stateName: state,
      stateCode: _stateCodes[_normalizeState(state)] ?? '',
      districtName: districts.length == 1 ? districts.first : '',
      districtCandidates: districts,
      stateCandidates: states.toList(),
    );
  }

  /// Normalised district key for matching across sources; applies audited aliases where
  /// India Post's postal name differs from the administrative name in the master.
  static String districtKey(String name) {
    final k = name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return _districtAliases[k] ?? k;
  }

  static const Map<String, String> _districtAliases = {
    'ganganagar': 'sriganganagar', // India Post "Ganganagar" = Rajasthan "Sri Ganganagar"
  };

  /// Hindi (Devanagari) name for a state/UT, or null when unknown.
  static String? stateNameHindi(String stateName) => _stateHindi[_normalizeState(stateName)];

  /// Compares state names across sources ("The Dadra and …" vs "Dadra and …", case).
  static bool sameState(String a, String b) => _normalizeState(a) == _normalizeState(b);

  static String _normalizeState(String s) =>
      s.toLowerCase().replaceFirst(RegExp(r'^the\s+'), '').replaceAll('&', 'and').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Checks if an address string conflicts with the state indicated by the PIN code.
  /// Returns conflict description if a conflict is detected, or null if consistent or unverified.
  static String? detectAddressConflict(String? pinCode, String? addressText) {
    if (pinCode == null || addressText == null) return null;
    final res = lookup(pinCode);
    if (res == null || res.stateName.isEmpty) return null;

    final addrLower = addressText.toLowerCase();
    for (final entry in _stateKeywords.entries) {
      if (sameState(entry.key, res.stateName)) continue;
      for (final kw in entry.value) {
        final hit = kw.length <= 3
            ? RegExp('(?:^|[^A-Za-z])${RegExp.escape(kw)}(?:[^A-Za-z]|\$)').hasMatch(addressText)
            : addrLower.contains(kw.toLowerCase());
        if (hit) {
          return 'PIN code $pinCode belongs to ${res.stateName}, but address mentions ${entry.key}.';
        }
      }
    }
    return null;
  }

  static const Map<String, String> _stateCodes = {
    'andaman and nicobar islands': 'AN', 'andhra pradesh': 'AP', 'arunachal pradesh': 'AR',
    'assam': 'AS', 'bihar': 'BR', 'chandigarh': 'CH', 'chhattisgarh': 'CT',
    'dadra and nagar haveli and daman and diu': 'DN', 'delhi': 'DL', 'goa': 'GA',
    'gujarat': 'GJ', 'haryana': 'HR', 'himachal pradesh': 'HP', 'jammu and kashmir': 'JK',
    'jharkhand': 'JH', 'karnataka': 'KA', 'kerala': 'KL', 'ladakh': 'LA', 'lakshadweep': 'LD',
    'madhya pradesh': 'MP', 'maharashtra': 'MH', 'manipur': 'MN', 'meghalaya': 'ML',
    'mizoram': 'MZ', 'nagaland': 'NL', 'odisha': 'OR', 'puducherry': 'PY', 'punjab': 'PB',
    'rajasthan': 'RJ', 'sikkim': 'SK', 'tamil nadu': 'TN', 'telangana': 'TG', 'tripura': 'TR',
    'uttar pradesh': 'UP', 'uttarakhand': 'UT', 'west bengal': 'WB',
  };

  static const Map<String, String> _stateHindi = {
    'andaman and nicobar islands': 'अंडमान और निकोबार द्वीपसमूह', 'andhra pradesh': 'आंध्र प्रदेश',
    'arunachal pradesh': 'अरुणाचल प्रदेश', 'assam': 'असम', 'bihar': 'बिहार', 'chandigarh': 'चंडीगढ़',
    'chhattisgarh': 'छत्तीसगढ़', 'dadra and nagar haveli and daman and diu': 'दादरा और नगर हवेली और दमन और दीव',
    'delhi': 'दिल्ली', 'goa': 'गोवा', 'gujarat': 'गुजरात', 'haryana': 'हरियाणा',
    'himachal pradesh': 'हिमाचल प्रदेश', 'jammu and kashmir': 'जम्मू और कश्मीर', 'jharkhand': 'झारखंड',
    'karnataka': 'कर्नाटक', 'kerala': 'केरल', 'ladakh': 'लद्दाख', 'lakshadweep': 'लक्षद्वीप',
    'madhya pradesh': 'मध्य प्रदेश', 'maharashtra': 'महाराष्ट्र', 'manipur': 'मणिपुर', 'meghalaya': 'मेघालय',
    'mizoram': 'मिज़ोरम', 'nagaland': 'नागालैंड', 'odisha': 'ओडिशा', 'puducherry': 'पुडुचेरी',
    'punjab': 'पंजाब', 'rajasthan': 'राजस्थान', 'sikkim': 'सिक्किम', 'tamil nadu': 'तमिलनाडु',
    'telangana': 'तेलंगाना', 'tripura': 'त्रिपुरा', 'uttar pradesh': 'उत्तर प्रदेश',
    'uttarakhand': 'उत्तराखंड', 'west bengal': 'पश्चिम बंगाल',
  };

  static const Map<String, List<String>> _stateKeywords = {
    'Rajasthan': ['Rajasthan', 'राजस्थान', 'Raj.'],
    'Madhya Pradesh': ['Madhya Pradesh', 'मध्य प्रदेश', 'म.प्र.', 'MP'],
    'Gujarat': ['Gujarat', 'गुजरात', 'Guj.'],
    'Maharashtra': ['Maharashtra', 'महाराष्ट्र'],
    'Uttar Pradesh': ['Uttar Pradesh', 'उत्तर प्रदेश', 'उ.प्र.', 'UP'],
    'Uttarakhand': ['Uttarakhand', 'उत्तराखंड'],
    'Haryana': ['Haryana', 'हरियाणा'],
    'Punjab': ['Punjab', 'पंजाब'],
    'Delhi': ['Delhi', 'दिल्ली'],
    'Bihar': ['Bihar', 'बिहार'],
    'Jharkhand': ['Jharkhand', 'झारखंड'],
    'West Bengal': ['West Bengal', 'पश्चिम बंगाल'],
    'Karnataka': ['Karnataka', 'कर्नाटक'],
    'Tamil Nadu': ['Tamil Nadu', 'तमिलनाडु'],
    'Andhra Pradesh': ['Andhra Pradesh', 'आंध्र प्रदेश'],
    'Telangana': ['Telangana', 'तेलंगाना'],
    'Odisha': ['Odisha', 'ओडिशा'],
    'Chhattisgarh': ['Chhattisgarh', 'छत्तीसगढ़'],
    'Himachal Pradesh': ['Himachal Pradesh', 'हिमाचल प्रदेश'],
    'Kerala': ['Kerala', 'केरल'],
    'Assam': ['Assam', 'असम'],
  };
}
