/// Domain entity representing an administrative audit log record for Seller profile modifications.
/// STRICT SECURITY RULES:
/// - Stored server-side and only readable by authorized platform administrators.
/// - Summaries must never contain plain unmasked bank account numbers, credentials, or sensitive OCR payloads.
class SellerProfileAuditEntry {
  final String id;
  final String sellerId;
  final String companyId;
  final String actorId;
  final String operationType; // 'MANUAL_EDIT' or 'INVOICE_ASSISTED_EDIT'
  final List<String> changedFields;
  final String changeSummary;
  final String source; // 'rmseller_mobile'
  final String requestId;
  final DateTime timestamp;
  final String? documentUrl;

  const SellerProfileAuditEntry({
    required this.id,
    required this.sellerId,
    required this.companyId,
    required this.actorId,
    required this.operationType,
    required this.changedFields,
    required this.changeSummary,
    this.source = 'rmseller_mobile',
    required this.requestId,
    required this.timestamp,
    this.documentUrl,
  });

  factory SellerProfileAuditEntry.fromMap(Map<String, dynamic> map) {
    List<String> fields = [];
    if (map['changed_fields'] is List) {
      fields = (map['changed_fields'] as List).map((e) => e.toString()).toList();
    }

    return SellerProfileAuditEntry(
      id: map['id']?.toString() ?? '',
      sellerId: map['seller_id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      actorId: map['actor_id']?.toString() ?? '',
      operationType: map['operation_type']?.toString() ?? 'MANUAL_EDIT',
      changedFields: fields,
      changeSummary: map['change_summary']?.toString() ?? '',
      source: map['source']?.toString() ?? 'rmseller_mobile',
      requestId: map['request_id']?.toString() ?? '',
      timestamp: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      documentUrl: map['document_url']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'seller_id': sellerId,
      'company_id': companyId,
      'actor_id': actorId,
      'operation_type': operationType,
      'changed_fields': changedFields,
      'change_summary': changeSummary,
      'source': source,
      'request_id': requestId,
      'created_at': timestamp.toIso8601String(),
      'document_url': documentUrl,
    };
  }
}
