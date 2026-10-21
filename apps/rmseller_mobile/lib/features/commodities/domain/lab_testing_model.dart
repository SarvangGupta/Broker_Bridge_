import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

/// Represents a single chemical or physical laboratory test parameter.
class LabTestParameter {
  final String id;
  final String name;
  final double? listedCharge; // null for 'Other' / unpriced
  final String category; // 'Proximate', 'Minerals', 'Energy', 'Other'
  final bool isCustom;

  const LabTestParameter({
    required this.id,
    required this.name,
    this.listedCharge,
    this.category = 'Proximate',
    this.isCustom = false,
  });

  bool get hasFixedPrice => listedCharge != null;

  String get priceLabel => listedCharge != null ? '₹${listedCharge!.toInt()}' : 'Not Specified';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'listed_charge': listedCharge,
        'category': category,
        'is_custom': isCustom,
      };

  factory LabTestParameter.fromMap(Map<String, dynamic> map) => LabTestParameter(
        id: map['id'] as String,
        name: map['name'] as String,
        listedCharge: (map['listed_charge'] as num?)?.toDouble(),
        category: (map['category'] as String?) ?? 'Proximate',
        isCustom: (map['is_custom'] as bool?) ?? false,
      );
}

/// Official rate card for Riddhi Siddhi Laboratory, Jaipur.
class LabTestRateCard {
  static const String laboratoryName = 'Riddhi Siddhi Laboratory';
  static const String laboratoryAddress =
      'F-772 B, Road Number 6, Vishwakarma Industrial Area, Jaipur, Rajasthan.';
  static const String upiVpa = 'rs.lab.jaipur@upi';

  static const List<LabTestParameter> standardParameters = [
    LabTestParameter(id: 'PARAM-CP', name: 'Crude Protein', listedCharge: 200, category: 'Proximate'),
    LabTestParameter(id: 'PARAM-FAT', name: 'Fat / Oil', listedCharge: 150, category: 'Proximate'),
    LabTestParameter(id: 'PARAM-CF', name: 'Crude Fiber', listedCharge: 200, category: 'Proximate'),
    LabTestParameter(id: 'PARAM-AIA', name: 'AIA (Acid Insoluble Ash)', listedCharge: 200, category: 'Proximate'),
    LabTestParameter(id: 'PARAM-MOIST', name: 'Moisture', listedCharge: 100, category: 'Proximate'),
    LabTestParameter(id: 'PARAM-CALC', name: 'Calcium', listedCharge: 450, category: 'Minerals'),
    LabTestParameter(id: 'PARAM-SALT', name: 'Salt (NaCl)', listedCharge: 480, category: 'Minerals'),
    LabTestParameter(id: 'PARAM-UREA', name: 'Urea', listedCharge: 550, category: 'Minerals'),
    LabTestParameter(id: 'PARAM-STARCH', name: 'Starch', listedCharge: 500, category: 'Minerals'),
    LabTestParameter(id: 'PARAM-PHOS', name: 'Phosphorus', listedCharge: 500, category: 'Minerals'),
    LabTestParameter(id: 'PARAM-TE', name: 'Total Energy', listedCharge: 850, category: 'Energy'),
    LabTestParameter(id: 'PARAM-ME', name: 'Metabolic Energy (ME)', listedCharge: 850, category: 'Energy'),
    LabTestParameter(id: 'PARAM-TDN', name: 'Total Digestive Nutrients (TDN)', listedCharge: 750, category: 'Energy'),
    LabTestParameter(id: 'PARAM-ASH', name: 'Total Ash', listedCharge: 150, category: 'Proximate'),
    LabTestParameter(id: 'PARAM-FFA', name: 'FFA (Free Fatty Acids)', listedCharge: 100, category: 'Proximate'),
    LabTestParameter(id: 'PARAM-OTHER', name: 'Other (Custom Parameter)', listedCharge: null, category: 'Other', isCustom: true),
  ];

  /// Calculates the estimated total from selected parameters without double-counting.
  /// Strictly ignores unpriced/custom parameters.
  static double calculateTotal(Iterable<LabTestParameter> selected) {
    final seenIds = <String>{};
    double sum = 0.0;
    for (final param in selected) {
      if (seenIds.add(param.id)) {
        if (param.listedCharge != null) {
          sum += param.listedCharge!;
        }
      }
    }
    return sum;
  }
}

/// Permitted lifecycle states for Lab Payment & Request processing.
enum LabPaymentStatus {
  awaitingPayment,
  paymentPending,
  paymentFailed,
  paidVerified,
  requestSubmitted,
  reportAvailable;

  String get label {
    switch (this) {
      case LabPaymentStatus.awaitingPayment:
        return 'Awaiting Payment';
      case LabPaymentStatus.paymentPending:
        return 'Payment Verification Pending';
      case LabPaymentStatus.paymentFailed:
        return 'Payment Failed / Cancelled';
      case LabPaymentStatus.paidVerified:
        return 'Paid — Payment Verified';
      case LabPaymentStatus.requestSubmitted:
        return 'Testing Request Submitted';
      case LabPaymentStatus.reportAvailable:
        return 'Report Available';
    }
  }

  Color get color {
    switch (this) {
      case LabPaymentStatus.awaitingPayment:
        return AppColors.warning;
      case LabPaymentStatus.paymentPending:
        return Colors.orange;
      case LabPaymentStatus.paymentFailed:
        return AppColors.error;
      case LabPaymentStatus.paidVerified:
        return AppColors.primary;
      case LabPaymentStatus.requestSubmitted:
        return AppColors.secondary;
      case LabPaymentStatus.reportAvailable:
        return AppColors.success;
    }
  }
}

/// Represents an authoritative lab testing service request.
class LabTestingRequest {
  final String id;
  final String availabilityId;
  final String lotNumber;
  final String commodityName;
  final String companyId;
  final List<LabTestParameter> selectedTests;
  final double estimatedTotal;
  final double finalPayableAmount;
  final String currency;
  final String upiVpa;
  final String payeeName;
  final String transactionReference;
  final LabPaymentStatus paymentStatus;
  final bool adminNotified;
  final String? adminNotificationId;
  final String? reportUrl;
  final String reportStatus; // 'Sample Pending', 'Testing In Progress', 'Report Uploaded', 'Verified'
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? customNotes;

  const LabTestingRequest({
    required this.id,
    required this.availabilityId,
    required this.lotNumber,
    required this.commodityName,
    required this.companyId,
    required this.selectedTests,
    required this.estimatedTotal,
    required this.finalPayableAmount,
    this.currency = 'INR',
    this.upiVpa = LabTestRateCard.upiVpa,
    this.payeeName = LabTestRateCard.laboratoryName,
    required this.transactionReference,
    this.paymentStatus = LabPaymentStatus.awaitingPayment,
    this.adminNotified = false,
    this.adminNotificationId,
    this.reportUrl,
    this.reportStatus = 'Sample Pending',
    required this.createdAt,
    this.verifiedAt,
    this.customNotes,
  });

  bool get isPaid =>
      paymentStatus == LabPaymentStatus.paidVerified ||
      paymentStatus == LabPaymentStatus.requestSubmitted ||
      paymentStatus == LabPaymentStatus.reportAvailable;

  bool get isReportReady =>
      (paymentStatus == LabPaymentStatus.reportAvailable || reportStatus == 'Verified' || reportStatus == 'Report Uploaded') &&
      reportUrl != null &&
      reportUrl!.isNotEmpty;

  LabTestingRequest copyWith({
    String? id,
    String? availabilityId,
    String? lotNumber,
    String? commodityName,
    String? companyId,
    List<LabTestParameter>? selectedTests,
    double? estimatedTotal,
    double? finalPayableAmount,
    String? currency,
    String? upiVpa,
    String? payeeName,
    String? transactionReference,
    LabPaymentStatus? paymentStatus,
    bool? adminNotified,
    String? adminNotificationId,
    String? reportUrl,
    String? reportStatus,
    DateTime? createdAt,
    DateTime? verifiedAt,
    String? customNotes,
  }) {
    return LabTestingRequest(
      id: id ?? this.id,
      availabilityId: availabilityId ?? this.availabilityId,
      lotNumber: lotNumber ?? this.lotNumber,
      commodityName: commodityName ?? this.commodityName,
      companyId: companyId ?? this.companyId,
      selectedTests: selectedTests ?? this.selectedTests,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      finalPayableAmount: finalPayableAmount ?? this.finalPayableAmount,
      currency: currency ?? this.currency,
      upiVpa: upiVpa ?? this.upiVpa,
      payeeName: payeeName ?? this.payeeName,
      transactionReference: transactionReference ?? this.transactionReference,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      adminNotified: adminNotified ?? this.adminNotified,
      adminNotificationId: adminNotificationId ?? this.adminNotificationId,
      reportUrl: reportUrl ?? this.reportUrl,
      reportStatus: reportStatus ?? this.reportStatus,
      createdAt: createdAt ?? this.createdAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      customNotes: customNotes ?? this.customNotes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'availability_id': availabilityId,
        'lot_number': lotNumber,
        'commodity_name': commodityName,
        'company_id': companyId,
        'selected_tests': selectedTests.map((t) => t.toMap()).toList(),
        'estimated_total': estimatedTotal,
        'final_payable_amount': finalPayableAmount,
        'currency': currency,
        'upi_vpa': upiVpa,
        'payee_name': payeeName,
        'transaction_reference': transactionReference,
        'payment_status': paymentStatus.name,
        'admin_notified': adminNotified,
        'admin_notification_id': adminNotificationId,
        'report_url': reportUrl,
        'report_status': reportStatus,
        'created_at': createdAt.toIso8601String(),
        'verified_at': verifiedAt?.toIso8601String(),
        'custom_notes': customNotes,
      };

  factory LabTestingRequest.fromMap(Map<String, dynamic> map) => LabTestingRequest(
        id: map['id'] as String,
        availabilityId: map['availability_id'] as String,
        lotNumber: map['lot_number'] as String,
        commodityName: map['commodity_name'] as String,
        companyId: (map['company_id'] as String?) ?? '',
        selectedTests: ((map['selected_tests'] as List?) ?? [])
            .map((t) => LabTestParameter.fromMap(t as Map<String, dynamic>))
            .toList(),
        estimatedTotal: (map['estimated_total'] as num).toDouble(),
        finalPayableAmount: (map['final_payable_amount'] as num).toDouble(),
        currency: (map['currency'] as String?) ?? 'INR',
        upiVpa: (map['upi_vpa'] as String?) ?? LabTestRateCard.upiVpa,
        payeeName: (map['payee_name'] as String?) ?? LabTestRateCard.laboratoryName,
        transactionReference: map['transaction_reference'] as String,
        paymentStatus: LabPaymentStatus.values.firstWhere(
          (s) => s.name == map['payment_status'],
          orElse: () => LabPaymentStatus.awaitingPayment,
        ),
        adminNotified: (map['admin_notified'] as bool?) ?? false,
        adminNotificationId: map['admin_notification_id'] as String?,
        reportUrl: map['report_url'] as String?,
        reportStatus: (map['report_status'] as String?) ?? 'Sample Pending',
        createdAt: DateTime.parse(map['created_at'] as String),
        verifiedAt: map['verified_at'] != null ? DateTime.parse(map['verified_at'] as String) : null,
        customNotes: map['custom_notes'] as String?,
      );
}

/// Model representing an optional existing lab report or certificate attachment (UX-02).
class LabReportAttachment {
  final String fileName;
  final String? localFilePath;
  final int? fileSizeBytes;
  final String fileType; // 'image' or 'document'
  final String? remoteStorageUrl;
  final bool isUploaded;
  final String? uploadError;
  final String? reportReference; // Auto-generated document reference (RB-SELLER-POST-UX-02)

  const LabReportAttachment({
    required this.fileName,
    this.localFilePath,
    this.fileSizeBytes,
    required this.fileType,
    this.remoteStorageUrl,
    this.isUploaded = false,
    this.uploadError,
    this.reportReference,
  });

  bool get isImage => fileType == 'image';
  bool get isDocument => fileType == 'document';

  String get formattedSize {
    if (fileSizeBytes == null || fileSizeBytes! <= 0) return '';
    if (fileSizeBytes! < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes! < 1024 * 1024) return '${(fileSizeBytes! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  LabReportAttachment copyWith({
    String? fileName,
    String? localFilePath,
    int? fileSizeBytes,
    String? fileType,
    String? remoteStorageUrl,
    bool? isUploaded,
    String? uploadError,
    String? reportReference,
  }) {
    return LabReportAttachment(
      fileName: fileName ?? this.fileName,
      localFilePath: localFilePath ?? this.localFilePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileType: fileType ?? this.fileType,
      remoteStorageUrl: remoteStorageUrl ?? this.remoteStorageUrl,
      isUploaded: isUploaded ?? this.isUploaded,
      uploadError: uploadError ?? this.uploadError,
      reportReference: reportReference ?? this.reportReference,
    );
  }

  Map<String, dynamic> toMap() => {
        'file_name': fileName,
        'local_file_path': localFilePath,
        'file_size_bytes': fileSizeBytes,
        'file_type': fileType,
        'remote_storage_url': remoteStorageUrl,
        'is_uploaded': isUploaded,
        'upload_error': uploadError,
        'report_reference': reportReference,
      };

  factory LabReportAttachment.fromMap(Map<String, dynamic> map) => LabReportAttachment(
        fileName: map['file_name'] as String,
        localFilePath: map['local_file_path'] as String?,
        fileSizeBytes: map['file_size_bytes'] as int?,
        fileType: (map['file_type'] as String?) ?? 'document',
        remoteStorageUrl: map['remote_storage_url'] as String?,
        isUploaded: (map['is_uploaded'] as bool?) ?? false,
        uploadError: map['upload_error'] as String?,
        reportReference: map['report_reference'] as String?,
      );
}

