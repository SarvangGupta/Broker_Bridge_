/// Domain entity representing an authenticated Buyer user in RMBuyer.
class BuyerUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? companyId;
  final String? companyName;
  final String? companyGst;

  const BuyerUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.companyId,
    this.companyName,
    this.companyGst,
  });

  /// Authoritative check: User role must be 'buyer' or 'admin'
  bool get isBuyerOrAdmin {
    final r = role.toLowerCase().trim();
    return r == 'buyer' || r == 'admin';
  }

  factory BuyerUser.fromMap(Map<String, dynamic> map) {
    return BuyerUser(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      fullName: (map['full_name'] as String?) ??
          (map['fullName'] as String?) ??
          (map['name'] as String?) ??
          'Buyer Procurement Lead',
      role: (map['role'] as String? ?? '').toLowerCase().trim(),
      companyId: map['company_id'] as String? ?? map['companyId'] as String?,
      companyName: map['company_name'] as String? ?? map['companyName'] as String?,
      companyGst: map['gst'] as String? ?? map['companyGst'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'company_id': companyId,
      'company_name': companyName,
      'company_gst': companyGst,
    };
  }
}
