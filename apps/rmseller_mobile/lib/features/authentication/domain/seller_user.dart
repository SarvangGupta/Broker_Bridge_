/// Domain entity representing an authenticated and verified commodity seller.
class SellerUser {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'seller' or 'admin'
  final String? companyId;
  final String? companyName;
  final String? companyGst;
  final int trustScore;
  final bool isVerified;

  const SellerUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.companyId,
    this.companyName,
    this.companyGst,
    this.trustScore = 100,
    this.isVerified = false,
  });

  bool get isSellerAdmin => role.toLowerCase() == 'admin' || role.toLowerCase() == 'seller_admin';
  bool get hasVerifiedCompany => companyId != null && companyId!.isNotEmpty;

  factory SellerUser.fromMap(Map<String, dynamic> map) {
    return SellerUser(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: (map['name'] as String?) ??
          (map['fullName'] as String?) ??
          (map['full_name'] as String?) ??
          'Commodity Seller Lead',
      role: map['role']?.toString().toLowerCase().trim() ?? 'seller',
      companyId: map['company_id']?.toString() ?? map['companyId']?.toString(),
      companyName: map['company_name']?.toString() ?? map['companyName']?.toString(),
      companyGst: map['company_gst']?.toString() ?? map['companyGst']?.toString(),
      trustScore: (map['trust_score'] as num?)?.toInt() ?? 100,
      isVerified: map['is_verified'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': fullName,
      'role': role,
      'company_id': companyId,
      'company_name': companyName,
      'company_gst': companyGst,
      'trust_score': trustScore,
      'is_verified': isVerified,
    };
  }
}
