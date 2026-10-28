import 'package:flutter/foundation.dart';

/// Structured result of an Indian PIN code lookup.
@immutable
class PinCodeLookupResult {
  final String pinCode;
  final String stateName;
  final String stateCode;
  final String districtName;
  final String postalCircle;
  final bool isValid;

  const PinCodeLookupResult({
    required this.pinCode,
    required this.stateName,
    required this.stateCode,
    required this.districtName,
    required this.postalCircle,
    this.isValid = true,
  });

  @override
  String toString() =>
      'PinCodeLookupResult(pin: $pinCode, district: $districtName, state: $stateName [$stateCode])';
}

/// Offline directory for authoritative Indian Postal Index Number (PIN) validation,
/// state mapping, and district resolution.
///
/// Designed in accordance with the Department of Posts (India Post) 9-zone postal circle schema.
class IndiaPinCodeDirectory {
  const IndiaPinCodeDirectory._();

  static final RegExp _pinRegex = RegExp(r'^[1-9][0-9]{5}$');

  /// Validates whether a string is a formally valid 6-digit Indian PIN code.
  static bool isValidPin(String? pin) {
    if (pin == null) return false;
    final cleaned = pin.trim();
    return _pinRegex.hasMatch(cleaned);
  }

  /// Looks up state and district information from a 6-digit PIN code using an offline reference dataset.
  /// Returns null if the PIN code is not a valid 6-digit Indian PIN.
  static PinCodeLookupResult? lookup(String? pin) {
    if (!isValidPin(pin)) return null;

    final cleaned = pin!.trim();
    final prefix2 = int.parse(cleaned.substring(0, 2));
    final prefix3 = int.parse(cleaned.substring(0, 3));

    // 1. Resolve 3-digit district mapping if known
    final districtInfo = _prefix3DistrictMap[prefix3];
    if (districtInfo != null) {
      return PinCodeLookupResult(
        pinCode: cleaned,
        stateName: districtInfo.stateName,
        stateCode: districtInfo.stateCode,
        districtName: districtInfo.districtName,
        postalCircle: districtInfo.postalCircle,
      );
    }

    // 2. Fallback to 2-digit state postal circle
    final stateInfo = _prefix2StateMap[prefix2];
    if (stateInfo != null) {
      return PinCodeLookupResult(
        pinCode: cleaned,
        stateName: stateInfo.stateName,
        stateCode: stateInfo.stateCode,
        districtName: '', // Specific district not resolved by 2 digits alone
        postalCircle: stateInfo.postalCircle,
      );
    }

    return null;
  }

  /// Checks if an address string conflicts with the state indicated by the PIN code.
  /// Returns conflict description if a conflict is detected, or null if consistent or unverified.
  static String? detectAddressConflict(String? pinCode, String? addressText) {
    if (pinCode == null || addressText == null) return null;
    final res = lookup(pinCode);
    if (res == null) return null;

    final addrLower = addressText.toLowerCase();

    // Check against other known state names
    for (final entry in _stateKeywords.entries) {
      final stateName = entry.key;
      final keywords = entry.value;

      if (stateName.toLowerCase() != res.stateName.toLowerCase()) {
        for (final kw in keywords) {
          if (addrLower.contains(kw.toLowerCase())) {
            return 'PIN code $pinCode belongs to ${res.stateName}, but address mentions $stateName.';
          }
        }
      }
    }

    return null;
  }

  // --- REFERENCE DATASETS ---

  static const Map<int, _StateRecord> _prefix2StateMap = {
    // 1: Northern Zone
    11: _StateRecord('Delhi', 'DL', 'Delhi Postal Circle'),
    12: _StateRecord('Haryana', 'HR', 'Haryana Postal Circle'),
    13: _StateRecord('Haryana', 'HR', 'Haryana Postal Circle'),
    14: _StateRecord('Punjab', 'PB', 'Punjab Postal Circle'),
    15: _StateRecord('Punjab', 'PB', 'Punjab Postal Circle'),
    16: _StateRecord('Chandigarh', 'CH', 'Punjab Postal Circle'),
    17: _StateRecord('Himachal Pradesh', 'HP', 'Himachal Pradesh Postal Circle'),
    18: _StateRecord('Jammu & Kashmir', 'JK', 'Jammu & Kashmir Postal Circle'),
    19: _StateRecord('Ladakh', 'LA', 'Jammu & Kashmir Postal Circle'),

    // 2: Northern Zone (UP & UK)
    20: _StateRecord('Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    21: _StateRecord('Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    22: _StateRecord('Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    23: _StateRecord('Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    24: _StateRecord('Uttarakhand', 'UK', 'Uttarakhand Postal Circle'),
    25: _StateRecord('Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    26: _StateRecord('Uttarakhand', 'UK', 'Uttarakhand Postal Circle'),
    27: _StateRecord('Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    28: _StateRecord('Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),

    // 3: Western Zone (RJ & GJ)
    30: _StateRecord('Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    31: _StateRecord('Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    32: _StateRecord('Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    33: _StateRecord('Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    34: _StateRecord('Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    36: _StateRecord('Gujarat', 'GJ', 'Gujarat Postal Circle'),
    37: _StateRecord('Gujarat', 'GJ', 'Gujarat Postal Circle'),
    38: _StateRecord('Gujarat', 'GJ', 'Gujarat Postal Circle'),
    39: _StateRecord('Gujarat', 'GJ', 'Gujarat Postal Circle'),

    // 4: Western & Central Zone (MH, GA, MP, CG)
    40: _StateRecord('Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    41: _StateRecord('Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    42: _StateRecord('Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    43: _StateRecord('Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    44: _StateRecord('Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    45: _StateRecord('Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    46: _StateRecord('Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    47: _StateRecord('Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    48: _StateRecord('Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    49: _StateRecord('Chhattisgarh', 'CG', 'Chhattisgarh Postal Circle'),

    // 5: Southern Zone (AP, TS, KA)
    50: _StateRecord('Telangana', 'TS', 'Telangana Postal Circle'),
    51: _StateRecord('Andhra Pradesh', 'AP', 'Andhra Pradesh Postal Circle'),
    52: _StateRecord('Andhra Pradesh', 'AP', 'Andhra Pradesh Postal Circle'),
    53: _StateRecord('Andhra Pradesh', 'AP', 'Andhra Pradesh Postal Circle'),
    56: _StateRecord('Karnataka', 'KA', 'Karnataka Postal Circle'),
    57: _StateRecord('Karnataka', 'KA', 'Karnataka Postal Circle'),
    58: _StateRecord('Karnataka', 'KA', 'Karnataka Postal Circle'),
    59: _StateRecord('Karnataka', 'KA', 'Karnataka Postal Circle'),

    // 6: Southern Zone (TN, KL)
    60: _StateRecord('Tamil Nadu', 'TN', 'Tamil Nadu Postal Circle'),
    61: _StateRecord('Tamil Nadu', 'TN', 'Tamil Nadu Postal Circle'),
    62: _StateRecord('Tamil Nadu', 'TN', 'Tamil Nadu Postal Circle'),
    63: _StateRecord('Tamil Nadu', 'TN', 'Tamil Nadu Postal Circle'),
    64: _StateRecord('Tamil Nadu', 'TN', 'Tamil Nadu Postal Circle'),
    67: _StateRecord('Kerala', 'KL', 'Kerala Postal Circle'),
    68: _StateRecord('Kerala', 'KL', 'Kerala Postal Circle'),
    69: _StateRecord('Kerala', 'KL', 'Kerala Postal Circle'),

    // 7: Eastern Zone (WB, OR, NE)
    70: _StateRecord('West Bengal', 'WB', 'West Bengal Postal Circle'),
    71: _StateRecord('West Bengal', 'WB', 'West Bengal Postal Circle'),
    72: _StateRecord('West Bengal', 'WB', 'West Bengal Postal Circle'),
    73: _StateRecord('West Bengal', 'WB', 'West Bengal Postal Circle'),
    74: _StateRecord('West Bengal', 'WB', 'West Bengal Postal Circle'),
    75: _StateRecord('Odisha', 'OD', 'Odisha Postal Circle'),
    76: _StateRecord('Odisha', 'OD', 'Odisha Postal Circle'),
    77: _StateRecord('Odisha', 'OD', 'Odisha Postal Circle'),
    78: _StateRecord('Assam', 'AS', 'Assam Postal Circle'),
    79: _StateRecord('North East', 'NE', 'North East Postal Circle'),

    // 8: Eastern Zone (BR, JH)
    80: _StateRecord('Bihar', 'BR', 'Bihar Postal Circle'),
    81: _StateRecord('Bihar', 'BR', 'Bihar Postal Circle'),
    82: _StateRecord('Bihar', 'BR', 'Bihar Postal Circle'),
    83: _StateRecord('Jharkhand', 'JH', 'Jharkhand Postal Circle'),
    84: _StateRecord('Bihar', 'BR', 'Bihar Postal Circle'),
    85: _StateRecord('Bihar', 'BR', 'Bihar Postal Circle'),
  };

  static const Map<int, _DistrictRecord> _prefix3DistrictMap = {
    // Rajasthan (RJ)
    301: _DistrictRecord('Alwar', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    302: _DistrictRecord('Jaipur', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    303: _DistrictRecord('Jaipur Rural', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    304: _DistrictRecord('Tonk', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    305: _DistrictRecord('Ajmer', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    306: _DistrictRecord('Pali', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    311: _DistrictRecord('Bhilwara', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    312: _DistrictRecord('Chittorgarh', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    313: _DistrictRecord('Udaipur', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    314: _DistrictRecord('Dungarpur', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    321: _DistrictRecord('Bharatpur', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    322: _DistrictRecord('Sawai Madhopur', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    323: _DistrictRecord('Bundi', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    324: _DistrictRecord('Kota', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    325: _DistrictRecord('Baran', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    326: _DistrictRecord('Jhalawar', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    331: _DistrictRecord('Churu', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    332: _DistrictRecord('Sikar', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    333: _DistrictRecord('Jhunjhunu', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    334: _DistrictRecord('Bikaner', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    335: _DistrictRecord('Sri Ganganagar', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    341: _DistrictRecord('Nagaur', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    342: _DistrictRecord('Jodhpur', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    343: _DistrictRecord('Jalore', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),
    344: _DistrictRecord('Barmer', 'Rajasthan', 'RJ', 'Rajasthan Postal Circle'),

    // Madhya Pradesh (MP)
    450: _DistrictRecord('Khandwa', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    451: _DistrictRecord('Khargone', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    452: _DistrictRecord('Indore', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    453: _DistrictRecord('Indore Rural', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    454: _DistrictRecord('Dhar', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    455: _DistrictRecord('Dewas', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    456: _DistrictRecord('Ujjain', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    457: _DistrictRecord('Ratlam', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    458: _DistrictRecord('Mandsaur', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    461: _DistrictRecord('Narmadapuram', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    462: _DistrictRecord('Bhopal', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    464: _DistrictRecord('Vidisha', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    465: _DistrictRecord('Shajapur', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    470: _DistrictRecord('Sagar', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    471: _DistrictRecord('Chhatarpur', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    473: _DistrictRecord('Guna', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    474: _DistrictRecord('Gwalior', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    475: _DistrictRecord('Shivpuri', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    476: _DistrictRecord('Morena', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    480: _DistrictRecord('Chhindwara', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    482: _DistrictRecord('Jabalpur', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    485: _DistrictRecord('Satna', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),
    486: _DistrictRecord('Rewa', 'Madhya Pradesh', 'MP', 'Madhya Pradesh Postal Circle'),

    // Gujarat (GJ)
    360: _DistrictRecord('Rajkot', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    361: _DistrictRecord('Jamnagar', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    362: _DistrictRecord('Junagadh', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    364: _DistrictRecord('Bhavnagar', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    370: _DistrictRecord('Kutch', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    380: _DistrictRecord('Ahmedabad', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    382: _DistrictRecord('Gandhinagar', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    384: _DistrictRecord('Mehsana', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    387: _DistrictRecord('Anand', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    390: _DistrictRecord('Vadodara', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),
    395: _DistrictRecord('Surat', 'Gujarat', 'GJ', 'Gujarat Postal Circle'),

    // Maharashtra (MH)
    400: _DistrictRecord('Mumbai', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    403: _DistrictRecord('Goa', 'Goa', 'GA', 'Maharashtra Postal Circle'),
    411: _DistrictRecord('Pune', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    413: _DistrictRecord('Solapur', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    414: _DistrictRecord('Ahmednagar', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    415: _DistrictRecord('Satara', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    416: _DistrictRecord('Kolhapur', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    421: _DistrictRecord('Thane', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    422: _DistrictRecord('Nashik', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    424: _DistrictRecord('Dhule', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    425: _DistrictRecord('Jalgaon', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    431: _DistrictRecord('Chhatrapati Sambhaji Nagar', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    440: _DistrictRecord('Nagpur', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),
    444: _DistrictRecord('Amravati', 'Maharashtra', 'MH', 'Maharashtra Postal Circle'),

    // Delhi (DL)
    110: _DistrictRecord('Delhi', 'Delhi', 'DL', 'Delhi Postal Circle'),

    // Haryana & Punjab (HR & PB)
    121: _DistrictRecord('Faridabad', 'Haryana', 'HR', 'Haryana Postal Circle'),
    122: _DistrictRecord('Gurugram', 'Haryana', 'HR', 'Haryana Postal Circle'),
    124: _DistrictRecord('Rohtak', 'Haryana', 'HR', 'Haryana Postal Circle'),
    125: _DistrictRecord('Hisar', 'Haryana', 'HR', 'Haryana Postal Circle'),
    131: _DistrictRecord('Sonipat', 'Haryana', 'HR', 'Haryana Postal Circle'),
    132: _DistrictRecord('Karnal', 'Haryana', 'HR', 'Haryana Postal Circle'),
    133: _DistrictRecord('Ambala', 'Haryana', 'HR', 'Haryana Postal Circle'),
    134: _DistrictRecord('Panchkula', 'Haryana', 'HR', 'Haryana Postal Circle'),
    141: _DistrictRecord('Ludhiana', 'Punjab', 'PB', 'Punjab Postal Circle'),
    143: _DistrictRecord('Amritsar', 'Punjab', 'PB', 'Punjab Postal Circle'),
    144: _DistrictRecord('Jalandhar', 'Punjab', 'PB', 'Punjab Postal Circle'),
    147: _DistrictRecord('Patiala', 'Punjab', 'PB', 'Punjab Postal Circle'),
    151: _DistrictRecord('Bathinda', 'Punjab', 'PB', 'Punjab Postal Circle'),

    // Uttar Pradesh (UP)
    201: _DistrictRecord('Ghaziabad', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    202: _DistrictRecord('Aligarh', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    208: _DistrictRecord('Kanpur', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    211: _DistrictRecord('Prayagraj', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    212: _DistrictRecord('Kaushambi', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    221: _DistrictRecord('Varanasi', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    226: _DistrictRecord('Lucknow', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    243: _DistrictRecord('Bareilly', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    248: _DistrictRecord('Dehradun', 'Uttarakhand', 'UK', 'Uttarakhand Postal Circle'),
    250: _DistrictRecord('Meerut', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    281: _DistrictRecord('Mathura', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),
    282: _DistrictRecord('Agra', 'Uttar Pradesh', 'UP', 'Uttar Pradesh Postal Circle'),

    // Bihar & Jharkhand
    800: _DistrictRecord('Patna', 'Bihar', 'BR', 'Bihar Postal Circle'),
    826: _DistrictRecord('Dhanbad', 'Jharkhand', 'JH', 'Jharkhand Postal Circle'),
    831: _DistrictRecord('Jamshedpur', 'Jharkhand', 'JH', 'Jharkhand Postal Circle'),
    834: _DistrictRecord('Ranchi', 'Jharkhand', 'JH', 'Jharkhand Postal Circle'),
  };

  static const Map<String, List<String>> _stateKeywords = {
    'Rajasthan': ['Rajasthan', 'राजस्थान', 'Raj.'],
    'Madhya Pradesh': ['Madhya Pradesh', 'मध्य प्रदेश', 'म.प्र.', 'MP'],
    'Gujarat': ['Gujarat', 'गुजरात', 'Guj.'],
    'Maharashtra': ['Maharashtra', 'महाराष्ट्र', 'Maha'],
    'Uttar Pradesh': ['Uttar Pradesh', 'उत्तर प्रदेश', 'उ.प्र.', 'UP'],
    'Haryana': ['Haryana', 'हरियाणा', 'HR'],
    'Punjab': ['Punjab', 'पंजाब', 'PB'],
    'Delhi': ['Delhi', 'दिल्ली', 'New Delhi', 'नई दिल्ली', 'DL'],
    'Bihar': ['Bihar', 'बिहार'],
    'Jharkhand': ['Jharkhand', 'झारखंड'],
  };
}

class _StateRecord {
  final String stateName;
  final String stateCode;
  final String postalCircle;
  const _StateRecord(this.stateName, this.stateCode, this.postalCircle);
}

class _DistrictRecord {
  final String districtName;
  final String stateName;
  final String stateCode;
  final String postalCircle;
  const _DistrictRecord(
    this.districtName,
    this.stateName,
    this.stateCode,
    this.postalCircle,
  );
}
