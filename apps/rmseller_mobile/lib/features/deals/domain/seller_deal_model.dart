/// Domain entity representing a commercial deal contract for the Seller.
/// STRICT COUNTERPARTY SHIELD INVARIANT:
/// Buyer personal contact information and identities are strictly omitted.
class SellerDealModel {
  final String id;
  final String requirementId;
  final String quotationId;
  final String commodityName;
  final String gradeName;
  final double agreedQuantity;
  final String unit;
  final double agreedPrice;
  final String status;
  final String brokerDeskName;
  final String? brokerId;
  final String? bookingReference;
  final DateTime createdAt;
  final DateTime? closedAt;

  // Invoice & Documents metadata
  final String? invoiceNo;
  final String? invoiceId;
  final double? invoiceAmount;
  final String? invoiceStatus; // 'Pending', 'Paid', 'Partially Paid'
  final int documentsCount;

  // Logistics & Dispatch metadata
  final String? vehicleNumber;
  final DateTime? dispatchDate;

  // Commission metadata
  final double? commissionRate;
  final String commissionBasis; // '₹/MT', '₹/QTL', '₹/Bag', '% of Invoice'
  final String commissionStatus; // 'Agreed', 'Proposed', 'Paid', 'None'
  final double? commissionAmount; // Total agreed commission payable
  final double commissionPaid;
  final double commissionOutstanding;

  const SellerDealModel({
    required this.id,
    required this.requirementId,
    required this.quotationId,
    required this.commodityName,
    required this.gradeName,
    required this.agreedQuantity,
    required this.unit,
    required this.agreedPrice,
    required this.status,
    required this.brokerDeskName,
    this.brokerId,
    this.bookingReference,
    required this.createdAt,
    this.closedAt,
    this.invoiceNo,
    this.invoiceId,
    this.invoiceAmount,
    this.invoiceStatus,
    this.documentsCount = 0,
    this.vehicleNumber,
    this.dispatchDate,
    this.commissionRate,
    this.commissionBasis = '₹/MT',
    this.commissionStatus = 'Agreed',
    this.commissionAmount,
    this.commissionPaid = 0.0,
    this.commissionOutstanding = 0.0,
  });

  double get totalDealValue => agreedQuantity * agreedPrice;
  bool get isBookingCreated => bookingReference != null && bookingReference!.isNotEmpty;
  bool get isCompleted =>
      status.toLowerCase() == 'completed' ||
      status.toLowerCase() == 'delivered' ||
      status.toLowerCase() == 'settled';
  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' ||
      status.toLowerCase() == 'rejected';
  bool get isActive => !isCompleted && !isCancelled;

  factory SellerDealModel.fromMap(Map<String, dynamic> map) {
    final req = map['requirements'] as Map<String, dynamic>?;
    final comm = req?['master_commodities'] as Map<String, dynamic>?;
    final grade = req?['master_grades'] as Map<String, dynamic>?;
    final unit = req?['master_units'] as Map<String, dynamic>?;

    final qty = (map['agreed_quantity'] as num?)?.toDouble() ?? 0.0;
    final price = (map['agreed_price'] as num?)?.toDouble() ?? 0.0;
    final dealStatus = map['status'] as String? ?? 'Dispatch Pending';

    // Commission extraction & calculation
    final rate = (map['commission_rate'] as num?)?.toDouble() ??
        (map['broker_commission_rate'] as num?)?.toDouble();
    final basis = (map['commission_basis'] as String?) ?? '₹/MT';
    double? calculatedCommission = (map['commission_amount'] as num?)?.toDouble();

    if (calculatedCommission == null && rate != null && rate > 0) {
      if (basis.contains('MT')) {
        calculatedCommission = rate * qty;
      } else if (basis.contains('QTL')) {
        calculatedCommission = rate * (qty * 10);
      } else if (basis.contains('%')) {
        calculatedCommission = (rate / 100) * (qty * price);
      } else {
        calculatedCommission = rate * qty;
      }
    }

    final paidCommission = (map['commission_paid'] as num?)?.toDouble() ??
        (dealStatus.toLowerCase() == 'settled' || dealStatus.toLowerCase() == 'completed'
            ? (calculatedCommission ?? 0.0)
            : 0.0);
    final outstandingCommission = (map['commission_outstanding'] as num?)?.toDouble() ??
        ((calculatedCommission ?? 0.0) - paidCommission).clamp(0.0, double.infinity);

    return SellerDealModel(
      id: map['id']?.toString() ?? '',
      requirementId: map['requirement_id']?.toString() ?? '',
      quotationId: map['quotation_id']?.toString() ?? '',
      commodityName: comm?['name'] as String? ?? (map['commodity_name'] as String?) ?? 'Commodity',
      gradeName: grade?['grade_name'] as String? ?? (map['grade_name'] as String?) ?? 'Standard FAQ',
      agreedQuantity: qty,
      unit: unit?['symbol'] as String? ?? (map['unit'] as String?) ?? 'MT',
      agreedPrice: price,
      status: dealStatus,
      brokerDeskName: (map['broker_desk_name'] as String?) ?? 'Verified Mandi Broker Desk',
      brokerId: map['broker_id']?.toString(),
      bookingReference: map['booking_reference'] as String? ??
          (map['bookings'] != null
              ? (map['bookings'] as Map<String, dynamic>)['booking_reference'] as String?
              : null),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      closedAt: map['closed_at'] != null ? DateTime.tryParse(map['closed_at'].toString()) : null,
      invoiceNo: map['invoice_no'] as String?,
      invoiceId: map['invoice_id'] as String?,
      invoiceAmount: (map['invoice_amount'] as num?)?.toDouble(),
      invoiceStatus: map['invoice_status'] as String?,
      documentsCount: (map['documents_count'] as num?)?.toInt() ?? 0,
      vehicleNumber: map['vehicle_number'] as String?,
      dispatchDate: map['dispatch_date'] != null ? DateTime.tryParse(map['dispatch_date'].toString()) : null,
      commissionRate: rate,
      commissionBasis: basis,
      commissionStatus: map['commission_status'] as String? ?? 'Agreed',
      commissionAmount: calculatedCommission,
      commissionPaid: paidCommission,
      commissionOutstanding: outstandingCommission,
    );
  }
}
