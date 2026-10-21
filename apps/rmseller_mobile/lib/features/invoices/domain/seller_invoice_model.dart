/// Domain model representing a Broker-shared or Mandi tax invoice for the Seller.
/// STRICT COUNTERPARTY SHIELD INVARIANT:
/// Buyer identity, direct phone, and contact details are strictly omitted.
class SellerInvoice {
  final String id;
  final String dealId;
  final String sellerId;
  final String invoiceNo;
  final double amount;
  final String status; // 'Pending', 'Paid', 'Partially Paid', 'Overdue'
  final String fileUrl;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String commodityName;
  final String gradeName;
  final double quantity;
  final String unit;
  final double ratePerUnit;
  final double gstRate; // e.g., 0.05 for 5% GST
  final String brokerDeskName;
  final String? bookingReference;
  final String? paymentReference;

  const SellerInvoice({
    required this.id,
    required this.dealId,
    required this.sellerId,
    required this.invoiceNo,
    required this.amount,
    required this.status,
    required this.fileUrl,
    required this.createdAt,
    this.dueDate,
    this.paidAt,
    required this.commodityName,
    required this.gradeName,
    required this.quantity,
    required this.unit,
    required this.ratePerUnit,
    this.gstRate = 0.05,
    required this.brokerDeskName,
    this.bookingReference,
    this.paymentReference,
  });

  double get taxableAmount => quantity * ratePerUnit;
  double get gstAmount => taxableAmount * gstRate;
  double get totalWithTax => taxableAmount + gstAmount;
  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isOverdue => status.toLowerCase() == 'overdue';

  factory SellerInvoice.fromMap(Map<String, dynamic> map) {
    return SellerInvoice(
      id: map['id']?.toString() ?? '',
      dealId: map['deal_id']?.toString() ?? '',
      sellerId: map['seller_id']?.toString() ?? '',
      invoiceNo: map['invoice_no'] as String? ?? 'INV-PENDING',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'Pending',
      fileUrl: map['file_url'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'].toString()) : null,
      paidAt: map['paid_at'] != null ? DateTime.tryParse(map['paid_at'].toString()) : null,
      commodityName: map['commodity_name'] as String? ?? 'Agricultural Commodity',
      gradeName: map['grade_name'] as String? ?? 'FAQ Standard',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'MT',
      ratePerUnit: (map['rate_per_unit'] as num?)?.toDouble() ?? 0.0,
      gstRate: (map['gst_rate'] as num?)?.toDouble() ?? 0.05,
      brokerDeskName: map['broker_desk_name'] as String? ?? 'Verified Mandi Broker Desk',
      bookingReference: map['booking_reference'] as String?,
      paymentReference: map['payment_reference'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deal_id': dealId,
      'seller_id': sellerId,
      'invoice_no': invoiceNo,
      'amount': amount,
      'status': status,
      'file_url': fileUrl,
      'created_at': createdAt.toIso8601String(),
      'commodity_name': commodityName,
      'grade_name': gradeName,
      'quantity': quantity,
      'unit': unit,
      'rate_per_unit': ratePerUnit,
      'broker_desk_name': brokerDeskName,
      'booking_reference': bookingReference,
      'payment_reference': paymentReference,
    };
  }
}

/// Domain model representing a commercial deal or dispatch document
class SellerDocument {
  final String id;
  final String dealId;
  final String? dispatchId;
  final String documentType; // 'Tax Invoice', 'Lorry Receipt (LR)', 'E-Way Bill', 'Weighbridge Slip', 'Quality Test Certificate'
  final String fileName;
  final String fileUrl;
  final DateTime createdAt;
  final String? uploadedBy;

  const SellerDocument({
    required this.id,
    required this.dealId,
    this.dispatchId,
    required this.documentType,
    required this.fileName,
    required this.fileUrl,
    required this.createdAt,
    this.uploadedBy,
  });

  factory SellerDocument.fromMap(Map<String, dynamic> map) {
    return SellerDocument(
      id: map['id']?.toString() ?? '',
      dealId: map['deal_id']?.toString() ?? '',
      dispatchId: map['dispatch_id']?.toString(),
      documentType: map['document_type'] as String? ?? 'Supporting Document',
      fileName: map['file_name'] as String? ?? 'document.pdf',
      fileUrl: map['file_url'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      uploadedBy: map['uploaded_by']?.toString(),
    );
  }
}
