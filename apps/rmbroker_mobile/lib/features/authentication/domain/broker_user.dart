/// Authenticated broker profile representation.
class BrokerUser {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'broker' or 'admin'
  final String? companyId;

  const BrokerUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.companyId,
  });

  /// Authoritative role check: Only 'broker' and 'admin' are authorized.
  bool get isBrokerOrAdmin {
    final normalized = role.toLowerCase().trim();
    return normalized == 'broker' || normalized == 'admin';
  }

  factory BrokerUser.fromMap(Map<String, dynamic> map) {
    return BrokerUser(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      fullName:
          (map['full_name'] as String?) ??
          (map['fullName'] as String?) ??
          'Commodity Broker',
      role: (map['role'] as String?) ?? '',
      companyId: map['company_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'company_id': companyId,
    };
  }

  @override
  String toString() =>
      'BrokerUser(id: $id, email: $email, role: $role, name: $fullName)';
}
