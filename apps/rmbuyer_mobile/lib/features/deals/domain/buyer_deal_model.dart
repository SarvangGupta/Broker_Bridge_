/// Domain entity representing a finalized or in-progress deal visible to the buyer.
/// Strict Counterparty Shield: Seller identifiers and seller contact information
/// are mathematically excluded from this model.
class BuyerDeal {
  final String id;
  final String requirementId;
  final String commodityName;
  final String gradeName;
  final double agreedQuantity;
  final String unit;
  final double agreedPrice;
  final String status;
  final String brokerDeskName;
  final DateTime createdAt;
  final DateTime? closedAt;

  const BuyerDeal({
    required this.id,
    required this.requirementId,
    required this.commodityName,
    required this.gradeName,
    required this.agreedQuantity,
    required this.unit,
    required this.agreedPrice,
    required this.status,
    required this.brokerDeskName,
    required this.createdAt,
    this.closedAt,
  });

  factory BuyerDeal.fromMap(Map<String, dynamic> map) {
    return BuyerDeal(
      id: map['id'] as String? ?? '',
      requirementId: map['requirement_id'] as String? ?? '',
      commodityName: (map['commodity_name'] as String?) ??
          (map['commodityName'] as String?) ??
          'Agricultural Commodity',
      gradeName: (map['grade_name'] as String?) ??
          (map['gradeName'] as String?) ??
          'Standard Commercial Grade',
      agreedQuantity: (map['agreed_quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'MT',
      agreedPrice: (map['agreed_price'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'Dispatch Pending',
      brokerDeskName: (map['broker_name'] as String?) ??
          (map['broker_desk'] as String?) ??
          'Broker Desk',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      closedAt: map['closed_at'] != null
          ? DateTime.tryParse(map['closed_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requirement_id': requirementId,
      'commodity_name': commodityName,
      'grade_name': gradeName,
      'agreed_quantity': agreedQuantity,
      'unit': unit,
      'agreed_price': agreedPrice,
      'status': status,
      'broker_name': brokerDeskName,
      'created_at': createdAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }
}
