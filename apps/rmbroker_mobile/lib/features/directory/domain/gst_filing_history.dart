import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Filing status constants for GST returns supported by official GSTN/GSP sources.
class GstReturnStatus {
  static const String filed = 'Filed';
  static const String notFiled = 'Not Filed';
  static const String notDue = 'Not Due';
  static const String notApplicable = 'Not Applicable';
  static const String unavailable = 'Unavailable';

  static bool isFiled(String? status) =>
      status?.trim().toLowerCase() == 'filed';

  static bool isNotFiled(String? status) =>
      status?.trim().toLowerCase() == 'not filed';

  static bool isNotDue(String? status) =>
      status?.trim().toLowerCase() == 'not due';

  static bool isNotApplicable(String? status) =>
      status?.trim().toLowerCase() == 'not applicable';
}

/// Detailed taxpayer profile details retrieved from the official GST registry.
@immutable
class GstTaxpayerDetails {
  final String gstin;
  final String legalName;
  final String? tradeName;
  final String status; // 'Active', 'Cancelled', 'Suspended'
  final String? registrationDate;
  final String? cancellationDate;
  final String? state;
  final String? principalAddress;
  final String? taxpayerType; // 'Regular', 'Composition', etc.
  final String filingFrequency; // 'Monthly', 'Quarterly (QRMP)'

  const GstTaxpayerDetails({
    required this.gstin,
    required this.legalName,
    this.tradeName,
    this.status = 'Active',
    this.registrationDate,
    this.cancellationDate,
    this.state,
    this.principalAddress,
    this.taxpayerType = 'Regular',
    this.filingFrequency = 'Monthly',
  });

  bool get isActive => status.trim().toLowerCase() == 'active';
  bool get isCancelled => status.trim().toLowerCase() == 'cancelled';
  bool get isSuspended => status.trim().toLowerCase() == 'suspended';
  bool get isQuarterlyFiler => filingFrequency.toLowerCase().contains('quarter');

  factory GstTaxpayerDetails.fromJson(Map<String, dynamic> json) {
    return GstTaxpayerDetails(
      gstin: json['gstin']?.toString() ?? '',
      legalName: json['legalName']?.toString() ?? json['legal_name']?.toString() ?? '',
      tradeName: json['tradeName']?.toString() ?? json['trade_name']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      registrationDate: json['registrationDate']?.toString() ?? json['registration_date']?.toString(),
      cancellationDate: json['cancellationDate']?.toString() ?? json['cancellation_date']?.toString(),
      state: json['state']?.toString(),
      principalAddress: json['principalAddress']?.toString() ?? json['principal_address']?.toString(),
      taxpayerType: json['taxpayerType']?.toString() ?? json['taxpayer_type']?.toString() ?? 'Regular',
      filingFrequency: json['filingFrequency']?.toString() ?? json['filing_frequency']?.toString() ?? 'Monthly',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gstin': gstin,
      'legalName': legalName,
      'tradeName': tradeName,
      'status': status,
      'registrationDate': registrationDate,
      'cancellationDate': cancellationDate,
      'state': state,
      'principalAddress': principalAddress,
      'taxpayerType': taxpayerType,
      'filingFrequency': filingFrequency,
    };
  }
}

/// Single tax period filing record combining GSTR-1 / IFF and GSTR-3B filings.
@immutable
class TaxPeriodFiling {
  final String financialYear; // e.g. '2025-26', '2026-27'
  final String taxPeriod; // e.g. 'March 2026', 'Q3 (Oct-Dec 2025)'
  final int periodOrder; // 1 for April ... 12 for March
  final String gstr1Status; // 'Filed', 'Not Filed', 'Not Due', 'Not Applicable', 'Unavailable'
  final String? gstr1FilingDate; // DD/MM/YYYY
  final String? gstr1DueDate; // DD/MM/YYYY
  final String? gstr1Arn;
  final String gstr3bStatus; // 'Filed', 'Not Filed', 'Not Due', 'Not Applicable', 'Unavailable'
  final String? gstr3bFilingDate; // DD/MM/YYYY
  final String? gstr3bDueDate; // DD/MM/YYYY
  final String? gstr3bArn;
  final bool isQuarterly;
  final String? delayNotice;

  const TaxPeriodFiling({
    required this.financialYear,
    required this.taxPeriod,
    required this.periodOrder,
    required this.gstr1Status,
    this.gstr1FilingDate,
    this.gstr1DueDate,
    this.gstr1Arn,
    required this.gstr3bStatus,
    this.gstr3bFilingDate,
    this.gstr3bDueDate,
    this.gstr3bArn,
    this.isQuarterly = false,
    this.delayNotice,
  });

  bool get isGstr1Filed => GstReturnStatus.isFiled(gstr1Status);
  bool get isGstr3bFiled => GstReturnStatus.isFiled(gstr3bStatus);

  factory TaxPeriodFiling.fromJson(Map<String, dynamic> json) {
    return TaxPeriodFiling(
      financialYear: json['financialYear']?.toString() ?? json['financial_year']?.toString() ?? '',
      taxPeriod: json['taxPeriod']?.toString() ?? json['tax_period']?.toString() ?? '',
      periodOrder: (json['periodOrder'] ?? json['period_order'] ?? 0) as int,
      gstr1Status: json['gstr1Status']?.toString() ?? json['gstr1_status']?.toString() ?? GstReturnStatus.unavailable,
      gstr1FilingDate: json['gstr1FilingDate']?.toString() ?? json['gstr1_filing_date']?.toString(),
      gstr1DueDate: json['gstr1DueDate']?.toString() ?? json['gstr1_due_date']?.toString(),
      gstr1Arn: json['gstr1Arn']?.toString() ?? json['gstr1_arn']?.toString(),
      gstr3bStatus: json['gstr3bStatus']?.toString() ?? json['gstr3b_status']?.toString() ?? GstReturnStatus.unavailable,
      gstr3bFilingDate: json['gstr3bFilingDate']?.toString() ?? json['gstr3b_filing_date']?.toString(),
      gstr3bDueDate: json['gstr3bDueDate']?.toString() ?? json['gstr3b_due_date']?.toString(),
      gstr3bArn: json['gstr3bArn']?.toString() ?? json['gstr3b_arn']?.toString(),
      isQuarterly: (json['isQuarterly'] ?? json['is_quarterly'] ?? false) as bool,
      delayNotice: json['delayNotice']?.toString() ?? json['delay_notice']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'financialYear': financialYear,
      'taxPeriod': taxPeriod,
      'periodOrder': periodOrder,
      'gstr1Status': gstr1Status,
      'gstr1FilingDate': gstr1FilingDate,
      'gstr1DueDate': gstr1DueDate,
      'gstr1Arn': gstr1Arn,
      'gstr3bStatus': gstr3bStatus,
      'gstr3bFilingDate': gstr3bFilingDate,
      'gstr3bDueDate': gstr3bDueDate,
      'gstr3bArn': gstr3bArn,
      'isQuarterly': isQuarterly,
      'delayNotice': delayNotice,
    };
  }
}

/// Factual summary of counterparty credibility without speculative credit scores.
@immutable
class GstCredibilitySummary {
  final String registrationStatus;
  final bool isActive;
  final int totalConfirmedFiled;
  final int totalConfirmedOverdue;
  final String? latestFilingDate;
  final String historicalCoverage;
  final String filingFrequency;
  final List<String> delayObservations;
  final String? dataLimitationNotice;

  const GstCredibilitySummary({
    required this.registrationStatus,
    required this.isActive,
    required this.totalConfirmedFiled,
    this.totalConfirmedOverdue = 0,
    this.latestFilingDate,
    required this.historicalCoverage,
    required this.filingFrequency,
    this.delayObservations = const [],
    this.dataLimitationNotice,
  });

  factory GstCredibilitySummary.fromFilings({
    required GstTaxpayerDetails taxpayer,
    required List<TaxPeriodFiling> filings,
    String? dataLimitationNotice,
  }) {
    var filedCount = 0;
    var overdueCount = 0;
    DateTime? maxFilingDate;
    final observations = <String>[];

    final dateFormats = [
      DateFormat('dd/MM/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd-MM-yyyy'),
    ];

    DateTime? parseDate(String? str) {
      if (str == null || str.trim().isEmpty) return null;
      for (final fmt in dateFormats) {
        try {
          return fmt.parse(str.trim());
        } catch (_) {}
      }
      return null;
    }

    for (final f in filings) {
      if (f.isGstr1Filed) {
        filedCount++;
        final d = parseDate(f.gstr1FilingDate);
        if (d != null && (maxFilingDate == null || d.isAfter(maxFilingDate))) {
          maxFilingDate = d;
        }
      } else if (f.gstr1Status == GstReturnStatus.notFiled) {
        overdueCount++;
      }

      if (f.isGstr3bFiled) {
        filedCount++;
        final d = parseDate(f.gstr3bFilingDate);
        if (d != null && (maxFilingDate == null || d.isAfter(maxFilingDate))) {
          maxFilingDate = d;
        }
      } else if (f.gstr3bStatus == GstReturnStatus.notFiled) {
        overdueCount++;
      }

      if (f.delayNotice != null && f.delayNotice!.isNotEmpty) {
        observations.add('${f.taxPeriod}: ${f.delayNotice}');
      }
    }

    // Determine historical coverage
    final years = filings.map((f) => f.financialYear).toSet().toList();
    years.sort();
    final coverage = years.isNotEmpty
        ? 'FY ${years.first} to FY ${years.last} (${years.length} Financial Years)'
        : 'No filing records returned';

    final latestStr = maxFilingDate != null
        ? DateFormat('dd MMM yyyy').format(maxFilingDate)
        : null;

    return GstCredibilitySummary(
      registrationStatus: taxpayer.status,
      isActive: taxpayer.isActive,
      totalConfirmedFiled: filedCount,
      totalConfirmedOverdue: overdueCount,
      latestFilingDate: latestStr,
      historicalCoverage: coverage,
      filingFrequency: taxpayer.filingFrequency,
      delayObservations: observations,
      dataLimitationNotice: dataLimitationNotice,
    );
  }

  factory GstCredibilitySummary.fromJson(Map<String, dynamic> json) {
    return GstCredibilitySummary(
      registrationStatus: json['registrationStatus']?.toString() ?? 'Active',
      isActive: (json['isActive'] ?? true) as bool,
      totalConfirmedFiled: (json['totalConfirmedFiled'] ?? 0) as int,
      totalConfirmedOverdue: (json['totalConfirmedOverdue'] ?? 0) as int,
      latestFilingDate: json['latestFilingDate']?.toString(),
      historicalCoverage: json['historicalCoverage']?.toString() ?? '',
      filingFrequency: json['filingFrequency']?.toString() ?? 'Monthly',
      delayObservations: (json['delayObservations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dataLimitationNotice: json['dataLimitationNotice']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registrationStatus': registrationStatus,
      'isActive': isActive,
      'totalConfirmedFiled': totalConfirmedFiled,
      'totalConfirmedOverdue': totalConfirmedOverdue,
      'latestFilingDate': latestFilingDate,
      'historicalCoverage': historicalCoverage,
      'filingFrequency': filingFrequency,
      'delayObservations': delayObservations,
      'dataLimitationNotice': dataLimitationNotice,
    };
  }
}

/// Comprehensive GST filing history snapshot container.
@immutable
class GstFilingSnapshot {
  final String gstin;
  final String? companyId;
  final GstTaxpayerDetails taxpayer;
  final List<String> availableFinancialYears;
  final List<TaxPeriodFiling> filings;
  final GstCredibilitySummary summary;
  final DateTime retrievedAt;
  final String dataSource;
  final bool isCached;

  const GstFilingSnapshot({
    required this.gstin,
    this.companyId,
    required this.taxpayer,
    required this.availableFinancialYears,
    required this.filings,
    required this.summary,
    required this.retrievedAt,
    required this.dataSource,
    this.isCached = false,
  });

  String get formattedRetrievedAt {
    return DateFormat('dd MMM yyyy, hh:mm a').format(retrievedAt.toLocal());
  }

  List<TaxPeriodFiling> filingsForYear(String fy) {
    return filings.where((f) => f.financialYear == fy).toList();
  }

  factory GstFilingSnapshot.fromJson(Map<String, dynamic> json) {
    final taxpayerJson = (json['taxpayer'] as Map<String, dynamic>?) ?? {};
    final filingsList = (json['filings'] as List<dynamic>?) ?? [];
    final summaryJson = (json['summary'] as Map<String, dynamic>?) ?? {};

    final parsedFilings = filingsList
        .map((e) => TaxPeriodFiling.fromJson(e as Map<String, dynamic>))
        .toList();

    final years = (json['availableFinancialYears'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        parsedFilings.map((f) => f.financialYear).toSet().toList();

    return GstFilingSnapshot(
      gstin: json['gstin']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? json['company_id']?.toString(),
      taxpayer: GstTaxpayerDetails.fromJson(taxpayerJson),
      availableFinancialYears: years,
      filings: parsedFilings,
      summary: GstCredibilitySummary.fromJson(summaryJson),
      retrievedAt: json['retrievedAt'] != null
          ? DateTime.tryParse(json['retrievedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dataSource: json['dataSource']?.toString() ?? 'GSTN Public Taxpayer Search',
      isCached: (json['isCached'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gstin': gstin,
      'companyId': companyId,
      'taxpayer': taxpayer.toJson(),
      'availableFinancialYears': availableFinancialYears,
      'filings': filings.map((f) => f.toJson()).toList(),
      'summary': summary.toJson(),
      'retrievedAt': retrievedAt.toIso8601String(),
      'dataSource': dataSource,
      'isCached': isCached,
    };
  }
}

