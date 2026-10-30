import 'package:flutter/foundation.dart';

/// Counterparty verification request created when a broker registers
/// a counterparty manually without a GST certificate copy.
@immutable
class CounterpartyVerificationRequest {
  final String id;
  final String companyId;
  final String brokerId;
  final String role; // 'buyer' | 'seller'
  final String gstin;
  final String? legalName;
  final String? tradeName;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime createdAt;

  const CounterpartyVerificationRequest({
    required this.id,
    required this.companyId,
    required this.brokerId,
    required this.role,
    required this.gstin,
    this.legalName,
    this.tradeName,
    this.status = 'pending',
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory CounterpartyVerificationRequest.fromJson(Map<String, dynamic> json) {
    return CounterpartyVerificationRequest(
      id: json['id']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? json['company_id']?.toString() ?? '',
      brokerId: json['brokerId']?.toString() ?? json['broker_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'buyer',
      gstin: json['gstin']?.toString() ?? '',
      legalName: json['legalName']?.toString() ?? json['legal_name']?.toString(),
      tradeName: json['tradeName']?.toString() ?? json['trade_name']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      reviewedBy: json['reviewedBy']?.toString() ?? json['reviewed_by']?.toString(),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'].toString())
          : (json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null),
      rejectionReason: json['rejectionReason']?.toString() ?? json['rejection_reason']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'brokerId': brokerId,
      'role': role,
      'gstin': gstin,
      'legalName': legalName,
      'tradeName': tradeName,
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

