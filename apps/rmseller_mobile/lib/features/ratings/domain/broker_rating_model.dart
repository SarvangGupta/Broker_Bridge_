/// Domain entities for Broker Ratings, Seller Feedback, and Eligibility.
/// Enforces the RB-SELLER-05 Rating Permission Matrix:
/// - Seller -> Broker: Allowed for eligible trading relationships.
/// - Seller -> Buyer: Prohibited (Strict Counterparty Shield).
/// - Broker -> Broker: Prohibited.
/// - Buyer -> Seller: Prohibited.
class BrokerRating {
  final String id;
  final String brokerId;
  final String brokerName;
  final String sellerId;
  final String? dealId;
  final String? dealReference;
  final int rating; // 1 to 5 stars
  final int mandiKnowledgeRating; // 1 to 5 stars
  final int promptnessRating; // 1 to 5 stars
  final int settlementRating; // 1 to 5 stars
  final int communicationRating; // 1 to 5 stars
  final String feedback; // Optional written comments, max 500 characters
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isVerifiedTrade;

  const BrokerRating({
    required this.id,
    required this.brokerId,
    required this.brokerName,
    required this.sellerId,
    this.dealId,
    this.dealReference,
    required this.rating,
    this.mandiKnowledgeRating = 5,
    this.promptnessRating = 5,
    this.settlementRating = 5,
    this.communicationRating = 5,
    this.feedback = '',
    required this.createdAt,
    this.updatedAt,
    this.isVerifiedTrade = true,
  });

  bool get hasWrittenFeedback => feedback.trim().isNotEmpty;

  factory BrokerRating.fromMap(Map<String, dynamic> map) {
    return BrokerRating(
      id: (map['id'] as String?) ?? '',
      brokerId: (map['broker_id'] as String?) ?? '',
      brokerName: (map['broker_name'] as String?) ?? 'Authorized Broker Desk',
      sellerId: (map['seller_id'] as String?) ?? '',
      dealId: map['deal_id'] as String?,
      dealReference: map['deal_reference'] as String?,
      rating: ((map['rating'] as num?)?.toInt() ?? 5).clamp(1, 5),
      mandiKnowledgeRating: ((map['mandi_knowledge_rating'] as num?)?.toInt() ?? 5).clamp(1, 5),
      promptnessRating: ((map['promptness_rating'] as num?)?.toInt() ?? 5).clamp(1, 5),
      settlementRating: ((map['settlement_rating'] as num?)?.toInt() ?? 5).clamp(1, 5),
      communicationRating: ((map['communication_rating'] as num?)?.toInt() ?? 5).clamp(1, 5),
      feedback: (map['feedback'] as String?) ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      isVerifiedTrade: (map['is_verified_trade'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'broker_id': brokerId,
      'broker_name': brokerName,
      'seller_id': sellerId,
      'deal_id': dealId,
      'deal_reference': dealReference,
      'rating': rating,
      'mandi_knowledge_rating': mandiKnowledgeRating,
      'promptness_rating': promptnessRating,
      'settlement_rating': settlementRating,
      'communication_rating': communicationRating,
      'feedback': feedback,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_verified_trade': isVerifiedTrade,
    };
  }

  BrokerRating copyWith({
    String? id,
    String? brokerId,
    String? brokerName,
    String? sellerId,
    String? dealId,
    String? dealReference,
    int? rating,
    int? mandiKnowledgeRating,
    int? promptnessRating,
    int? settlementRating,
    int? communicationRating,
    String? feedback,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerifiedTrade,
  }) {
    return BrokerRating(
      id: id ?? this.id,
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      sellerId: sellerId ?? this.sellerId,
      dealId: dealId ?? this.dealId,
      dealReference: dealReference ?? this.dealReference,
      rating: rating ?? this.rating,
      mandiKnowledgeRating: mandiKnowledgeRating ?? this.mandiKnowledgeRating,
      promptnessRating: promptnessRating ?? this.promptnessRating,
      settlementRating: settlementRating ?? this.settlementRating,
      communicationRating: communicationRating ?? this.communicationRating,
      feedback: feedback ?? this.feedback,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerifiedTrade: isVerifiedTrade ?? this.isVerifiedTrade,
    );
  }
}

/// Aggregate summary of ratings for a Broker desk.
class BrokerRatingSummary {
  final String brokerId;
  final double averageRating; // 0.0 to 5.0 (0.0 means unrated)
  final int totalReviews;
  final int trustScore; // 0 to 100 from companies.trust_score
  final Map<int, int> starDistribution; // e.g. {5: 18, 4: 5, 3: 1, 2: 0, 1: 0}
  final Map<String, double> criteriaAverages; // sub-criteria averages
  final List<BrokerRating> recentReviews;
  final BrokerRating? userReview; // current seller's review if exists

  const BrokerRatingSummary({
    required this.brokerId,
    required this.averageRating,
    required this.totalReviews,
    required this.trustScore,
    required this.starDistribution,
    this.criteriaAverages = const {},
    this.recentReviews = const [],
    this.userReview,
  });

  bool get isUnrated => totalReviews == 0;
  bool get hasUserReviewed => userReview != null;

  double getPercentage(int star) {
    if (totalReviews == 0) return 0.0;
    final count = starDistribution[star] ?? 0;
    return count / totalReviews;
  }

  factory BrokerRatingSummary.empty(String brokerId, {int trustScore = 100}) {
    return BrokerRatingSummary(
      brokerId: brokerId,
      averageRating: 0.0,
      totalReviews: 0,
      trustScore: trustScore,
      starDistribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      criteriaAverages: {
        'Mandi Knowledge': 0.0,
        'Promptness': 0.0,
        'Settlement': 0.0,
        'Communication': 0.0,
      },
      recentReviews: const [],
      userReview: null,
    );
  }
}

/// Represents the evaluated rating eligibility for a Seller to rate a Broker.
class RatingEligibility {
  final bool isEligible;
  final String reason;
  final String? eligibleDealId;
  final String? eligibleDealReference;
  final List<String> completedDealIds;
  final bool hasAlreadyRated;
  final BrokerRating? existingRating;

  const RatingEligibility({
    required this.isEligible,
    required this.reason,
    this.eligibleDealId,
    this.eligibleDealReference,
    this.completedDealIds = const [],
    this.hasAlreadyRated = false,
    this.existingRating,
  });

  factory RatingEligibility.eligible({
    required String dealId,
    required String dealReference,
    List<String> completedDealIds = const [],
    BrokerRating? existingRating,
  }) {
    return RatingEligibility(
      isEligible: true,
      reason: existingRating != null
          ? 'You have previously rated this verified trade. You may update your feedback.'
          : 'Eligible: Verified completed transaction ($dealReference).',
      eligibleDealId: dealId,
      eligibleDealReference: dealReference,
      completedDealIds: completedDealIds,
      hasAlreadyRated: existingRating != null,
      existingRating: existingRating,
    );
  }

  factory RatingEligibility.ineligible({
    required String reason,
    BrokerRating? existingRating,
  }) {
    return RatingEligibility(
      isEligible: false,
      reason: reason,
      hasAlreadyRated: existingRating != null,
      existingRating: existingRating,
    );
  }
}
