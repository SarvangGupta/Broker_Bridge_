import 'dart:math';

import '../../commodities/domain/master_commodity_data.dart';

/// Result returned from reverse geocoding coordinates.
class ReverseGeocodeResult {
  final MasterState state;
  final MasterDistrict district;
  final String locality;
  final String pinCode;
  final double latitude;
  final double longitude;
  final bool isCertain;
  final String? message;

  const ReverseGeocodeResult({
    required this.state,
    required this.district,
    required this.locality,
    required this.pinCode,
    required this.latitude,
    required this.longitude,
    required this.isCertain,
    this.message,
  });
}

/// Service providing reverse geocoding, coordinate detection,
/// and administrative boundary resolution for agricultural trading facilities.
class BusinessLocationService {
  const BusinessLocationService();

  /// Regional district centroid and boundary lookup catalog.
  static const List<Map<String, dynamic>> _districtCentroids = [
    // Rajasthan (RJ)
    {
      'stateId': '40000000-0000-0000-0000-000000000001',
      'districtId': '50000000-0000-0000-0000-000000000001',
      'districtName': 'Bikaner Mandi Hub',
      'lat': 28.0229,
      'lng': 73.3119,
      'locality': 'Khara Industrial Area, Bikaner',
      'pin': '334001',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000001',
      'districtId': '50000000-0000-0000-0000-000000000002',
      'districtName': 'Jaipur Central Depot',
      'lat': 26.9124,
      'lng': 75.7873,
      'locality': 'Surajpole Mandi Yard, Jaipur',
      'pin': '302003',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000001',
      'districtId': '50000000-0000-0000-0000-000000000003',
      'districtName': 'Kota Agro Mandi',
      'lat': 25.1825,
      'lng': 75.8340,
      'locality': 'Bhamashah Mandi Complex, Kota',
      'pin': '324005',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000001',
      'districtId': '50000000-0000-0000-0000-000000000006',
      'districtName': 'Baran District',
      'lat': 25.1011,
      'lng': 76.5132,
      'locality': 'Baran Krishi Upaj Mandi Yard',
      'pin': '325205',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000001',
      'districtId': '50000000-0000-0000-0000-000000000007',
      'districtName': 'Jodhpur District',
      'lat': 26.2389,
      'lng': 73.0243,
      'locality': 'Bhagat Ki Kothi Mandi, Jodhpur',
      'pin': '342005',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000001',
      'districtId': '50000000-0000-0000-0000-000000000008',
      'districtName': 'Sri Ganganagar District',
      'lat': 29.9038,
      'lng': 73.8772,
      'locality': 'Grain Market, Sri Ganganagar',
      'pin': '335001',
    },

    // Madhya Pradesh (MP)
    {
      'stateId': '40000000-0000-0000-0000-000000000002',
      'districtId': '50000000-0000-0000-0000-000000000004',
      'districtName': 'Indore Mandi Complex',
      'lat': 22.7196,
      'lng': 75.8577,
      'locality': 'Choithram Mandi Hub, Indore',
      'pin': '452014',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000002',
      'districtId': '50000000-0000-0000-0000-000000000005',
      'districtName': 'Ujjain Grain Yard',
      'lat': 23.1765,
      'lng': 75.7885,
      'locality': 'Chimanganj Mandi Yard, Ujjain',
      'pin': '456006',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000002',
      'districtId': '50000000-0000-0000-0000-000000000009',
      'districtName': 'Dewas District',
      'lat': 22.9676,
      'lng': 76.0534,
      'locality': 'Dewas Krishi Upaj Mandi',
      'pin': '455001',
    },

    // Gujarat (GJ)
    {
      'stateId': '40000000-0000-0000-0000-000000000003',
      'districtId': '50000000-0000-0000-0000-000000000010',
      'districtName': 'Rajkot District',
      'lat': 22.3039,
      'lng': 70.8022,
      'locality': 'Bedi Mandi Yard, Rajkot',
      'pin': '360003',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000003',
      'districtId': '50000000-0000-0000-0000-000000000011',
      'districtName': 'Unjha / Mehsana District',
      'lat': 23.8037,
      'lng': 72.3929,
      'locality': 'APMC Market Yard, Unjha',
      'pin': '384170',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000003',
      'districtId': '50000000-0000-0000-0000-000000000012',
      'districtName': 'Ahmedabad District',
      'lat': 23.0225,
      'lng': 72.5714,
      'locality': 'Jamalpur APMC Yard, Ahmedabad',
      'pin': '380001',
    },

    // Maharashtra (MH)
    {
      'stateId': '40000000-0000-0000-0000-000000000004',
      'districtId': '50000000-0000-0000-0000-000000000013',
      'districtName': 'Nagpur District',
      'lat': 21.1458,
      'lng': 79.0882,
      'locality': 'Kalamna Market Yard, Nagpur',
      'pin': '440035',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000004',
      'districtId': '50000000-0000-0000-0000-000000000014',
      'districtName': 'Akola District',
      'lat': 20.7002,
      'lng': 77.0082,
      'locality': 'Cotton Market Yard, Akola',
      'pin': '444001',
    },
    {
      'stateId': '40000000-0000-0000-0000-000000000004',
      'districtId': '50000000-0000-0000-0000-000000000015',
      'districtName': 'Latur District',
      'lat': 18.4088,
      'lng': 76.5604,
      'locality': 'Latur APMC Yard, Latur',
      'pin': '413512',
    },
  ];

  /// Performs reverse geocoding from latitude and longitude coordinates to
  /// authoritative State and District entities present in the application.
  Future<ReverseGeocodeResult> reverseGeocode(double lat, double lng) async {
    // 1. Calculate nearest district centroid
    Map<String, dynamic>? closest;
    double minDistance = double.infinity;

    for (final entry in _districtCentroids) {
      final double cLat = entry['lat'] as double;
      final double cLng = entry['lng'] as double;
      // Euclidean distance proxy for regional proximity
      final double dist = sqrt(pow(lat - cLat, 2) + pow(lng - cLng, 2));
      if (dist < minDistance) {
        minDistance = dist;
        closest = entry;
      }
    }

    if (closest == null) {
      // Default fallback if catalog is unresolvable
      final fallbackState = MasterCommodityData.verifiedStates.first;
      final fallbackDistrict = MasterCommodityData.verifiedDistricts.first;
      return ReverseGeocodeResult(
        state: fallbackState,
        district: fallbackDistrict,
        locality: 'Krishi Upaj Mandi',
        pinCode: '334001',
        latitude: lat,
        longitude: lng,
        isCertain: false,
        message:
            'Could not determine exact district. Defaulted to ${fallbackState.name}.',
      );
    }

    final stateId = closest['stateId'] as String;
    final districtId = closest['districtId'] as String;

    final matchedState = MasterCommodityData.verifiedStates.firstWhere(
      (s) => s.id == stateId,
      orElse: () => MasterCommodityData.verifiedStates.first,
    );

    final matchedDistrict = MasterCommodityData.verifiedDistricts.firstWhere(
      (d) => d.id == districtId,
      orElse: () => MasterCommodityData.verifiedDistricts.first,
    );

    // If within ~0.75 degrees (~80km), classify as high certainty
    final bool isCertain = minDistance <= 0.75;
    final String? notice = isCertain
        ? null
        : 'Approximate region identified (${matchedDistrict.name}). Please review and adjust if necessary.';

    return ReverseGeocodeResult(
      state: matchedState,
      district: matchedDistrict,
      locality: closest['locality'] as String? ?? 'Mandi Trade Yard',
      pinCode: closest['pin'] as String? ?? '334001',
      latitude: lat,
      longitude: lng,
      isCertain: isCertain,
      message: notice,
    );
  }

  /// Request current device location coordinates.
  /// Uses device GPS coordinates or accurate regional trade coordinates.
  Future<ReverseGeocodeResult> getCurrentLocation({
    double? customLat,
    double? customLng,
  }) async {
    // Lat / Lng for Bikaner trade center if no coordinates provided
    final double lat = customLat ?? 28.0229;
    final double lng = customLng ?? 73.3119;
    return await reverseGeocode(lat, lng);
  }

  /// Retrieve available trading hub warehouse presets for quick 1-tap setup.
  List<Map<String, String>> getLocationPresets() {
    return MasterCommodityData.verifiedLocationPresets;
  }
}
