/// Broker lifecycle and relationship status for the Seller.
enum SellerBrokerStatus {
  /// Registered and verified licensed mandi broker desk.
  registeredVerified,

  /// Registered broker desk, but administrative KYC/profile verification is pending.
  pendingVerification,

  /// Contact nominated by seller and invited to platform; pending broker registration and self-verification.
  invitationPending,
}

/// Domain entity representing an authorized commodity broker desk for the Seller.
/// COUNTERPARTY SHIELD INVARIANT:
/// Buyer identities and personal contact details are strictly excluded.
class SellerBrokerModel {
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
  final double? averageRating;
  final int reviewCount;
  final SellerBrokerStatus status;
  final DateTime? invitedAt;
  final String? nominationSource;

  const SellerBrokerModel({
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
    this.averageRating,
    this.reviewCount = 0,
    this.status = SellerBrokerStatus.registeredVerified,
    this.invitedAt,
    this.nominationSource,
  });

  bool get hasPhone => mobile != null && mobile!.trim().isNotEmpty;
  bool get hasWhatsApp => mobile != null && mobile!.trim().isNotEmpty;
  bool get hasRatings => averageRating != null && reviewCount > 0;

  bool get isInvitationPending =>
      status == SellerBrokerStatus.invitationPending;
  bool get isPendingVerification =>
      status == SellerBrokerStatus.pendingVerification;
  bool get isRegisteredVerified =>
      status == SellerBrokerStatus.registeredVerified && isVerified;

  // Convenience aliases
  String? get phone => mobile;
  List<String> get specialtyCommodities => commoditiesHandled;

  SellerBrokerModel copyWith({
    String? id,
    String? name,
    String? email,
    String? mobile,
    String? companyName,
    String? companyGst,
    String? location,
    int? trustScore,
    bool? isVerified,
    List<String>? commoditiesHandled,
    double? averageRating,
    int? reviewCount,
    SellerBrokerStatus? status,
    DateTime? invitedAt,
    String? nominationSource,
  }) {
    return SellerBrokerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      companyName: companyName ?? this.companyName,
      companyGst: companyGst ?? this.companyGst,
      location: location ?? this.location,
      trustScore: trustScore ?? this.trustScore,
      isVerified: isVerified ?? this.isVerified,
      commoditiesHandled: commoditiesHandled ?? this.commoditiesHandled,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      status: status ?? this.status,
      invitedAt: invitedAt ?? this.invitedAt,
      nominationSource: nominationSource ?? this.nominationSource,
    );
  }

  factory SellerBrokerModel.fromMap(Map<String, dynamic> map) {
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

    final avgRatingRaw = map['average_rating'] ?? map['avg_rating'];
    final double? avgRating = (avgRatingRaw is num)
        ? avgRatingRaw.toDouble()
        : null;

    final reviewCountRaw = map['review_count'] ?? map['reviews_count'];
    final int revCount = (reviewCountRaw is num) ? reviewCountRaw.toInt() : 0;

    SellerBrokerStatus brokerStatus = isVerified
        ? SellerBrokerStatus.registeredVerified
        : SellerBrokerStatus.pendingVerification;

    if (map['status_enum'] != null) {
      final s = map['status_enum'].toString();
      if (s == 'invitationPending') {
        brokerStatus = SellerBrokerStatus.invitationPending;
      } else if (s == 'pendingVerification') {
        brokerStatus = SellerBrokerStatus.pendingVerification;
      } else {
        brokerStatus = SellerBrokerStatus.registeredVerified;
      }
    }

    DateTime? invited;
    if (map['invited_at'] != null) {
      invited = DateTime.tryParse(map['invited_at'].toString());
    }

    return SellerBrokerModel(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Authorized Mandi Broker',
      email: map['email'] as String?,
      mobile: map['mobile'] as String?,
      companyName:
          (company['name'] as String?) ??
          (map['company_name'] as String?) ??
          'Licensed Mandi Broker Desk',
      companyGst:
          (company['gst'] as String?) ?? (map['company_gst'] as String?),
      location:
          (map['location'] as String?) ??
          (map['mandi'] as String?) ??
          'Mandi Trading Desk',
      trustScore: trustScore,
      isVerified: isVerified,
      commoditiesHandled: commodities.isNotEmpty
          ? commodities
          : const ['Soybean', 'Chana', 'Mustard', 'Wheat'],
      averageRating: avgRating,
      reviewCount: revCount,
      status: brokerStatus,
      invitedAt: invited,
      nominationSource: map['nomination_source'] as String?,
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
      'average_rating': averageRating,
      'review_count': reviewCount,
      'status_enum': status.name,
      'invited_at': invitedAt?.toIso8601String(),
      'nomination_source': nominationSource,
    };
  }
}
