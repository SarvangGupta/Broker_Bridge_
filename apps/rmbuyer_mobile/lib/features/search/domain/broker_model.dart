/// Domain entity representing an authorized commodity broker desk.
/// Strict Counterparty Shield: Seller identifiers and seller contact information
/// are mathematically excluded from this model.
class BrokerModel {
  final String id;
  final String name;
  final String? email;
  final String? mobile;
  final String? companyName;
  final String? companyGst;
  final String? location;
  final int trustScore;
  final bool isVerified;
  final List<String> commoditiesHandled;

  /// False when [commoditiesHandled] is the default list substituted because
  /// the source row carried no commodity data.
  final bool hasCommodityData;

  /// False when [trustScore] is the default substituted because the source
  /// row carried no trust score.
  final bool hasTrustScore;

  const BrokerModel({
    required this.id,
    required this.name,
    this.email,
    this.mobile,
    this.companyName,
    this.companyGst,
    this.location,
    this.trustScore = 100,
    this.isVerified = false,
    this.commoditiesHandled = const [],
    this.hasCommodityData = true,
    this.hasTrustScore = true,
  });

  /// Trust is shown only for verified companies with a stored score; the
  /// column defaults to 100, so an unverified company's score is not earned.
  bool get showsTrustScore => hasTrustScore && isVerified;

  bool get hasPhone => mobile != null && mobile!.trim().isNotEmpty;
  bool get hasWhatsApp => mobile != null && mobile!.trim().isNotEmpty;

  factory BrokerModel.fromMap(Map<String, dynamic> map) {
    // Handle embedded company object if joined
    final company = map['companies'] as Map<String, dynamic>? ?? {};

    final commoditiesRaw = map['commodities'] ?? map['commodities_handled'];
    List<String> commodities = [];
    if (commoditiesRaw is List) {
      commodities = commoditiesRaw.map((e) => e.toString()).toList();
    } else if (commoditiesRaw is String && commoditiesRaw.isNotEmpty) {
      commodities = commoditiesRaw.split(',').map((e) => e.trim()).toList();
    }

    final trustScoreRaw = company['trust_score'] ?? map['trust_score'];
    final trustScore = (trustScoreRaw is num) ? trustScoreRaw.toInt() : 100;

    final isVerifiedRaw = company['is_verified'] ?? map['is_verified'];
    final isVerified = isVerifiedRaw == true;

    return BrokerModel(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Authorized Mandi Broker',
      email: map['email'] as String?,
      mobile: map['mobile'] as String?,
      companyName: (company['name'] as String?) ??
          (map['company_name'] as String?) ??
          'Licensed Mandi Broker Desk',
      companyGst: (company['gst'] as String?) ?? (map['company_gst'] as String?),
      location: (map['location'] as String?) ??
          (map['mandi'] as String?) ??
          'Mandi Trading Floor',
      trustScore: trustScore,
      isVerified: isVerified,
      commoditiesHandled: commodities.isNotEmpty
          ? commodities
          : const ['Soybean', 'Chana', 'Wheat', 'Mustard'],
      hasCommodityData: commodities.isNotEmpty,
      hasTrustScore: trustScoreRaw is num,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'company_name': companyName,
      'company_gst': companyGst,
      'location': location,
      'trust_score': trustScore,
      'is_verified': isVerified,
      'commodities': commoditiesHandled,
    };
  }
}
