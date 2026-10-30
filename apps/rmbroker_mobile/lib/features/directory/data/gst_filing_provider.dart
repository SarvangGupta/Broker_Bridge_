import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../domain/gst_certificate_data.dart';
import '../domain/gst_filing_history.dart';

/// Exception thrown on GST API communication or validation errors.
class GstApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isTimeout;
  final bool isInvalidGstin;

  const GstApiException({
    required this.message,
    this.statusCode,
    this.isTimeout = false,
    this.isInvalidGstin = false,
  });

  @override
  String toString() => message;
}

/// Abstract adapter interface for GST filing data providers.
abstract class GstFilingDataProvider {
  Future<GstFilingSnapshot> fetchFilingHistory(
    String gstin, {
    String? companyId,
    bool forceRefresh = false,
  });
}

/// High-fidelity offline provider and test fixture generator.
/// Accurately models monthly filers, quarterly filers (QRMP), cancelled taxpayers,
/// and partial historical records without network dependencies.
class GstMockDataProvider implements GstFilingDataProvider {
  final bool simulateTimeout;
  final bool simulateFailure;
  final String? failureMessage;

  const GstMockDataProvider({
    this.simulateTimeout = false,
    this.simulateFailure = false,
    this.failureMessage,
  });

  @override
  Future<GstFilingSnapshot> fetchFilingHistory(
    String gstin, {
    String? companyId,
    bool forceRefresh = false,
  }) async {
    if (simulateTimeout) {
      await Future.delayed(const Duration(milliseconds: 100));
      throw const GstApiException(
        message: 'GST portal gateway timed out while retrieving return filings. Please try again.',
        isTimeout: true,
      );
    }

    if (simulateFailure) {
      throw GstApiException(
        message: failureMessage ?? 'GST filing history provider returned an unexpected error.',
      );
    }

    final cleanGstin = GstinRules.normalize(gstin);
    if (!GstinRules.hasValidFormat(cleanGstin)) {
      throw const GstApiException(
        message: 'Invalid GSTIN format. A valid 15-character GSTIN is required to check filing history.',
        isInvalidGstin: true,
      );
    }

    // Determine taxpayer profile archetype based on GSTIN characteristics for rich testing:
    // 1. Cancelled Taxpayer: if GSTIN contains "CANC" or starts with "99"
    // 2. Quarterly Filer (QRMP): if GSTIN ends with "Q" or contains "QRMP" or is specific test case
    // 3. Partial History: if GSTIN contains "PART" or state code is "03" (Punjab)
    // 4. Regular Monthly Filer: default
    final isCancelled = cleanGstin.contains('C1Z') || cleanGstin.contains('CANC') || cleanGstin.startsWith('99');
    final isQuarterly = cleanGstin.contains('Q1Z') || cleanGstin.contains('QRMP') || cleanGstin.endsWith('Q') || cleanGstin.contains('QUART');
    final isPartial = cleanGstin.contains('P1Z') || cleanGstin.contains('PART') || cleanGstin.contains('NEW');

    final stateName = GstinRules.stateOf(cleanGstin) ?? 'Maharashtra';

    final taxpayer = GstTaxpayerDetails(
      gstin: cleanGstin,
      legalName: isCancelled
          ? 'DEFUNCT AGRO PROCESSORS PRIVATE LIMITED'
          : (isQuarterly ? 'KISAN SAMRUDDHI AGRO PRODUCER CO' : 'BHARAT AGRO COMMODITIES LLP'),
      tradeName: isCancelled
          ? 'Defunct Agro'
          : (isQuarterly ? 'Kisan Samruddhi Agro' : 'Bharat Agro Traders'),
      status: isCancelled ? 'Cancelled' : 'Active',
      registrationDate: isPartial ? '15/06/2024' : '01/07/2017',
      cancellationDate: isCancelled ? '31/03/2024' : null,
      state: stateName,
      principalAddress: 'Mandi Yard Gate 2, Commercial Complex, APMC, $stateName',
      taxpayerType: 'Regular',
      filingFrequency: isQuarterly ? 'Quarterly (QRMP)' : 'Monthly',
    );

    final filings = <TaxPeriodFiling>[];

    // Build historical years: FY 2026-27 YTD down to FY 2021-22
    final targetYears = isPartial
        ? ['2026-27', '2024-25']
        : ['2026-27', '2025-26', '2024-25', '2023-24', '2022-23', '2021-22'];

    for (final fy in targetYears) {
      if (isQuarterly) {
        // Quarterly filers file 4 quarters per year
        filings.addAll(_generateQuarterlyFilings(fy, isCancelled: isCancelled));
      } else {
        // Monthly filers file 12 months per year (or YTD for 2026-27)
        filings.addAll(_generateMonthlyFilings(fy, isCancelled: isCancelled));
      }
    }

    final summary = GstCredibilitySummary.fromFilings(
      taxpayer: taxpayer,
      filings: filings,
      dataLimitationNotice: isPartial
          ? 'Business registered in FY 2024-25. Historical records prior to registration date are not applicable.'
          : null,
    );

    return GstFilingSnapshot(
      gstin: cleanGstin,
      companyId: companyId,
      taxpayer: taxpayer,
      availableFinancialYears: targetYears,
      filings: filings,
      summary: summary,
      retrievedAt: DateTime.now(),
      dataSource: 'Test Fixture (Offline Mock)',
      isCached: false,
    );
  }

  List<TaxPeriodFiling> _generateMonthlyFilings(String fy, {required bool isCancelled}) {
    final list = <TaxPeriodFiling>[];
    final isCurrentYtd = fy == '2026-27';

    // Months in financial year: April (1) to March (12)
    final months = [
      ('April', 1),
      ('May', 2),
      ('June', 3),
      ('July', 4),
      ('August', 5),
      ('September', 6),
      ('October', 7),
      ('November', 8),
      ('December', 9),
      ('January', 10),
      ('February', 11),
      ('March', 12),
    ];

    final startYear = int.parse(fy.substring(0, 4));

    for (final (mName, order) in months) {
      final calendarYear = order <= 9 ? startYear : startYear + 1;
      final label = '$mName $calendarYear';

      // For 2026-27 YTD: assume current date is late 2026 (up to September filed, October due/filed)
      if (isCurrentYtd && order > 7) {
        if (order == 8) {
          list.add(TaxPeriodFiling(
            financialYear: fy,
            taxPeriod: label,
            periodOrder: order,
            gstr1Status: GstReturnStatus.notDue,
            gstr3bStatus: GstReturnStatus.notDue,
          ));
        }
        continue;
      }

      if (isCancelled && calendarYear >= 2024 && order >= 4) {
        list.add(TaxPeriodFiling(
          financialYear: fy,
          taxPeriod: label,
          periodOrder: order,
          gstr1Status: GstReturnStatus.notApplicable,
          gstr3bStatus: GstReturnStatus.notApplicable,
          delayNotice: 'Registration cancelled; returns not applicable.',
        ));
        continue;
      }

      // Format filing dates: GSTR-1 around 10th-11th, GSTR-3B around 18th-20th
      final nextMonthNum = (order % 12) + 1;
      final nextMonthYear = order == 12 ? calendarYear + 1 : calendarYear;
      final g1Date = '10/${nextMonthNum.toString().padLeft(2, '0')}/$nextMonthYear';
      final g3Date = '19/${nextMonthNum.toString().padLeft(2, '0')}/$nextMonthYear';

      // Simulate occasional minor 2-day filing delay for factual review
      final isDelayed = (order == 3 || order == 9) && !isCurrentYtd;
      final delayStr = isDelayed ? 'GSTR-3B filed 2 days after due date' : null;

      list.add(TaxPeriodFiling(
        financialYear: fy,
        taxPeriod: label,
        periodOrder: order,
        gstr1Status: GstReturnStatus.filed,
        gstr1FilingDate: g1Date,
        gstr1DueDate: '11/${nextMonthNum.toString().padLeft(2, '0')}/$nextMonthYear',
        gstr1Arn: 'AA27${calendarYear}000000$order',
        gstr3bStatus: GstReturnStatus.filed,
        gstr3bFilingDate: isDelayed ? '22/${nextMonthNum.toString().padLeft(2, '0')}/$nextMonthYear' : g3Date,
        gstr3bDueDate: '20/${nextMonthNum.toString().padLeft(2, '0')}/$nextMonthYear',
        gstr3bArn: 'AB27${calendarYear}000000$order',
        delayNotice: delayStr,
      ));
    }

    return list;
  }

  List<TaxPeriodFiling> _generateQuarterlyFilings(String fy, {required bool isCancelled}) {
    final list = <TaxPeriodFiling>[];
    final isCurrentYtd = fy == '2026-27';
    final startYear = int.parse(fy.substring(0, 4));

    final quarters = [
      ('Q1 (Apr–Jun)', 3, '13/07/$startYear', '22/07/$startYear'),
      ('Q2 (Jul–Sep)', 6, '13/10/$startYear', '22/10/$startYear'),
      ('Q3 (Oct–Dec)', 9, '13/01/${startYear + 1}', '22/01/${startYear + 1}'),
      ('Q4 (Jan–Mar)', 12, '13/04/${startYear + 1}', '22/04/${startYear + 1}'),
    ];

    for (final (qName, order, g1Due, g3Due) in quarters) {
      if (isCurrentYtd && order > 6) {
        if (order == 9) {
          list.add(TaxPeriodFiling(
            financialYear: fy,
            taxPeriod: '$qName $fy',
            periodOrder: order,
            gstr1Status: GstReturnStatus.notDue,
            gstr3bStatus: GstReturnStatus.notDue,
            isQuarterly: true,
          ));
        }
        continue;
      }

      if (isCancelled && startYear >= 2024) {
        list.add(TaxPeriodFiling(
          financialYear: fy,
          taxPeriod: '$qName $fy',
          periodOrder: order,
          gstr1Status: GstReturnStatus.notApplicable,
          gstr3bStatus: GstReturnStatus.notApplicable,
          isQuarterly: true,
          delayNotice: 'Registration cancelled; returns not applicable.',
        ));
        continue;
      }

      final g1Date = '12/${g1Due.substring(3)}';
      final g3Date = '20/${g3Due.substring(3)}';

      list.add(TaxPeriodFiling(
        financialYear: fy,
        taxPeriod: '$qName $fy',
        periodOrder: order,
        gstr1Status: GstReturnStatus.filed,
        gstr1FilingDate: g1Date,
        gstr1DueDate: g1Due,
        gstr1Arn: 'QRMP1${startYear}00$order',
        gstr3bStatus: GstReturnStatus.filed,
        gstr3bFilingDate: g3Date,
        gstr3bDueDate: g3Due,
        gstr3bArn: 'QRMP3${startYear}00$order',
        isQuarterly: true,
      ));
    }

    return list;
  }
}

/// Free Public GST API Provider (Jamku - Madrecha Solutions).
/// Public API Endpoint: https://gst.jamku.app/api/gstin/{gstin}
/// Cost: ₹0 (Zero subscription, zero per-GSTIN fees, completely free public access).
class GstJamkuPublicApiProvider implements GstFilingDataProvider {
  final Dio _dio;
  final String baseUrl;

  GstJamkuPublicApiProvider({
    Dio? dio,
    this.baseUrl = 'https://gst.jamku.app/api',
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': 'Mozilla/5.0 (compatible; RMBroker/1.0)',
                },
              ),
            );

  @override
  Future<GstFilingSnapshot> fetchFilingHistory(
    String gstin, {
    String? companyId,
    bool forceRefresh = false,
  }) async {
    final cleanGstin = GstinRules.normalize(gstin);
    if (!GstinRules.hasValidFormat(cleanGstin)) {
      throw const GstApiException(
        message: 'Invalid GSTIN format. A valid 15-character GSTIN is required.',
        isInvalidGstin: true,
      );
    }

    try {
      final response = await _dio.get('$baseUrl/gstin/$cleanGstin');
      final dynamic body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const GstApiException(
          message: 'Unexpected response from free GST registry.',
        );
      }

      if (body['success'] == false) {
        final msg = body['message']?.toString() ?? 'Failed to retrieve GST details.';
        final err = body['error']?.toString() ?? '';
        final isChecksumErr = err == 'InputError' || msg.toLowerCase().contains('checksum');
        throw GstApiException(
          message: isChecksumErr
              ? 'Invalid GSTIN format or checksum according to GSTN specification.'
              : msg,
          isInvalidGstin: isChecksumErr,
        );
      }

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const GstApiException(
          message: 'Empty data payload returned by free GST API.',
        );
      }

      final legalName = data['lgnm']?.toString().trim() ?? '';
      final tradeName = data['tradeName']?.toString().trim();
      final status = data['sts']?.toString().trim() ?? 'Active';
      final regDate = data['rgdt']?.toString().trim();
      final cxDate = data['cxdt']?.toString().trim();
      final address = data['adr']?.toString().trim();
      final state = GstinRules.stateOf(cleanGstin) ?? 'State not specified';
      final taxpayerType = data['dty']?.toString().trim() ?? 'Regular';

      final rawReturns = (data['returns'] as List<dynamic>?) ?? [];

      // Determine filing frequency
      final isComposition = taxpayerType.toLowerCase().contains('composition');
      final isQuarterly = isComposition ||
          rawReturns.any((r) {
            final taxp = (r['taxp']?.toString() ?? '').toLowerCase();
            return taxp.startsWith('q') || taxp.contains('quarter');
          });

      final filingFrequency = isQuarterly ? 'Quarterly (QRMP)' : 'Monthly';

      final taxpayer = GstTaxpayerDetails(
        gstin: cleanGstin,
        legalName: legalName.isNotEmpty ? legalName : (tradeName ?? 'Taxpayer ($cleanGstin)'),
        tradeName: tradeName?.isNotEmpty == true ? tradeName : null,
        status: status,
        registrationDate: regDate?.isNotEmpty == true ? regDate : null,
        cancellationDate: cxDate?.isNotEmpty == true ? cxDate : null,
        state: state,
        principalAddress: address?.isNotEmpty == true ? address : null,
        taxpayerType: taxpayerType,
        filingFrequency: filingFrequency,
      );

      // Parse and group returns
      final filings = _parseJamkuReturns(rawReturns, isQuarterly: isQuarterly);

      final availableYears = filings.isNotEmpty
          ? filings.map((f) => f.financialYear).toSet().toList()
          : <String>['2026-27', '2025-26', '2024-25', '2023-24', '2022-23', '2021-22'];
      availableYears.sort((a, b) => b.compareTo(a));

      String? limitationNotice;
      if (rawReturns.isEmpty) {
        limitationNotice =
            'No return filings returned in the free public registry for this GSTIN. You can verify complete filing history directly on the Official GST Portal (gst.gov.in).';
      } else if (availableYears.length < 5) {
        limitationNotice =
            'Free public API provides recent return filings (${availableYears.join(', ')}). Earlier historical years can be verified with official CAPTCHA on the Official GST Portal (gst.gov.in).';
      }

      final summary = GstCredibilitySummary.fromFilings(
        taxpayer: taxpayer,
        filings: filings,
        dataLimitationNotice: limitationNotice,
      );

      return GstFilingSnapshot(
        gstin: cleanGstin,
        companyId: companyId,
        taxpayer: taxpayer,
        availableFinancialYears: availableYears,
        filings: filings,
        summary: summary,
        retrievedAt: DateTime.now(),
        dataSource: 'Jamku Public GST API (Free)',
        isCached: false,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const GstApiException(
          message:
              'Free GST registry request timed out. Please try again or verify on the Official GST Portal.',
          isTimeout: true,
        );
      }
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        final body = e.response!.data as Map<String, dynamic>;
        final msg = body['message']?.toString() ?? '';
        final isChecksumErr = msg.toLowerCase().contains('checksum');
        throw GstApiException(
          message: isChecksumErr
              ? 'Invalid GSTIN format or checksum according to GSTN specification.'
              : msg,
          isInvalidGstin: isChecksumErr,
        );
      }
      throw GstApiException(
        message:
            'Free GST API is temporarily unreachable (${e.message ?? 'network issue'}). Please verify directly on the Official GST Portal (gst.gov.in).',
      );
    } catch (e) {
      if (e is GstApiException) rethrow;
      throw GstApiException(message: 'Error communicating with free GST source: $e');
    }
  }

  List<TaxPeriodFiling> _parseJamkuReturns(List<dynamic> rawReturns, {required bool isQuarterly}) {
    final groups = <String, Map<String, dynamic>>{};

    for (final item in rawReturns) {
      if (item is! Map<String, dynamic>) continue;
      final rawFy = item['fy']?.toString().trim() ?? '';
      final taxp = item['taxp']?.toString().trim() ?? '';
      final rtntype = (item['rtntype']?.toString().trim() ?? '').toUpperCase();
      final dof = item['dof']?.toString().trim();

      if (rawFy.isEmpty || taxp.isEmpty) continue;
      final fy = _normalizeFy(rawFy);
      final key = '$fy|$taxp';

      groups.putIfAbsent(key, () => {'fy': fy, 'taxp': taxp});
      if (rtntype == 'GSTR1' || rtntype == 'GSTR1A' || rtntype == 'IFF') {
        groups[key]!['gstr1Dof'] = dof;
      } else if (rtntype == 'GSTR3B') {
        groups[key]!['gstr3bDof'] = dof;
      } else if (rtntype == 'GSTR9' || rtntype == 'GSTR9C') {
        groups[key]!['annualDof'] = dof;
        groups[key]!['annualType'] = rtntype;
      }
    }

    final filings = <TaxPeriodFiling>[];
    for (final entry in groups.entries) {
      final g = entry.value;
      final fy = g['fy'] as String;
      final taxp = g['taxp'] as String;
      final g1Dof = g['gstr1Dof'] as String?;
      final g3Dof = g['gstr3bDof'] as String?;
      final annualDof = g['annualDof'] as String?;

      final order = _monthOrder(taxp);
      final g1Status = g1Dof != null ? GstReturnStatus.filed : GstReturnStatus.unavailable;
      final g3Status = g3Dof != null ? GstReturnStatus.filed : GstReturnStatus.unavailable;

      if (annualDof != null && g1Dof == null && g3Dof == null) {
        filings.add(TaxPeriodFiling(
          financialYear: fy,
          taxPeriod: '$taxp (${g['annualType']})',
          periodOrder: order,
          gstr1Status: GstReturnStatus.filed,
          gstr1FilingDate: annualDof,
          gstr3bStatus: GstReturnStatus.notApplicable,
          isQuarterly: false,
        ));
      } else {
        filings.add(TaxPeriodFiling(
          financialYear: fy,
          taxPeriod: taxp,
          periodOrder: order,
          gstr1Status: g1Status,
          gstr1FilingDate: g1Dof,
          gstr3bStatus: g3Status,
          gstr3bFilingDate: g3Dof,
          isQuarterly: isQuarterly,
        ));
      }
    }

    filings.sort((a, b) {
      final fyCmp = b.financialYear.compareTo(a.financialYear);
      if (fyCmp != 0) return fyCmp;
      return b.periodOrder.compareTo(a.periodOrder);
    });

    return filings;
  }

  String _normalizeFy(String raw) {
    final parts = raw.split('-');
    if (parts.length == 2 && parts[0].length == 4 && parts[1].length == 4) {
      return '${parts[0]}-${parts[1].substring(2)}';
    }
    return raw;
  }

  int _monthOrder(String taxp) {
    final lower = taxp.toLowerCase();
    if (lower.contains('apr')) return 1;
    if (lower.contains('may')) return 2;
    if (lower.contains('jun') || lower.contains('q1')) return 3;
    if (lower.contains('jul')) return 4;
    if (lower.contains('aug')) return 5;
    if (lower.contains('sep') || lower.contains('q2')) return 6;
    if (lower.contains('oct')) return 7;
    if (lower.contains('nov')) return 8;
    if (lower.contains('dec') || lower.contains('q3')) return 9;
    if (lower.contains('jan')) return 10;
    if (lower.contains('feb')) return 11;
    if (lower.contains('mar') || lower.contains('q4')) return 12;
    return 13;
  }
}

/// Repository managing retrieval, in-memory caching, database persistence,
/// and broker counterparty isolation for GST filing history snapshots.
class GstFilingRepository {
  final GstFilingDataProvider _provider;
  final SupabaseClient? _supabase;
  final SecureStorageService _storage;

  // In-memory cache keyed by normalized GSTIN
  final Map<String, GstFilingSnapshot> _memoryCache = {};

  // Cache duration: 24 hours
  static const Duration cacheDuration = Duration(hours: 24);

  GstFilingRepository({
    GstFilingDataProvider? provider,
    SupabaseClient? supabase,
    required SecureStorageService storage,
  })  : _provider = provider ?? GstJamkuPublicApiProvider(),
        _supabase = supabase,
        _storage = storage;

  /// Fetches GST filing history for [gstin], utilizing cache unless [forceRefresh] is true.
  /// Enforces counterparty broker isolation.
  Future<GstFilingSnapshot> getFilingHistory(
    String gstin, {
    String? companyId,
    bool forceRefresh = false,
  }) async {
    final cleanGstin = GstinRules.normalize(gstin);
    if (!GstinRules.hasValidFormat(cleanGstin)) {
      throw const GstApiException(
        message: 'Invalid GSTIN format. A valid 15-character GSTIN is required.',
        isInvalidGstin: true,
      );
    }

    // 1. Check in-memory cache if not forced refresh
    if (!forceRefresh && _memoryCache.containsKey(cleanGstin)) {
      final cached = _memoryCache[cleanGstin]!;
      final age = DateTime.now().difference(cached.retrievedAt);
      if (age < cacheDuration) {
        return GstFilingSnapshot(
          gstin: cached.gstin,
          companyId: cached.companyId ?? companyId,
          taxpayer: cached.taxpayer,
          availableFinancialYears: cached.availableFinancialYears,
          filings: cached.filings,
          summary: cached.summary,
          retrievedAt: cached.retrievedAt,
          dataSource: cached.dataSource,
          isCached: true,
        );
      }
    }

    // 2. Check Supabase database cache if connected
    final client = _supabase;
    if (!forceRefresh && client != null) {
      try {
        final rows = await client
            .from('counterparty_gst_filing_snapshots')
            .select('*')
            .eq('gstin', cleanGstin)
            .order('retrieved_at', ascending: false)
            .limit(1);

        if (rows.isNotEmpty) {
          final row = rows.first;
          final retrievedAt = DateTime.tryParse(row['retrieved_at']?.toString() ?? '') ?? DateTime.now();
          final age = DateTime.now().difference(retrievedAt);

          if (age < cacheDuration) {
            final payload = row['snapshot_payload'] as Map<String, dynamic>;
            final snapshot = GstFilingSnapshot.fromJson({
              ...payload,
              'gstin': cleanGstin,
              'companyId': companyId ?? row['company_id']?.toString(),
              'retrievedAt': retrievedAt.toIso8601String(),
              'isCached': true,
            });
            _memoryCache[cleanGstin] = snapshot;
            return snapshot;
          }
        }
      } catch (e) {
        debugPrint('GST filing database cache read notice: $e');
      }
    }

    // 3. Fetch fresh snapshot from provider
    final freshSnapshot = await _provider.fetchFilingHistory(
      cleanGstin,
      companyId: companyId,
      forceRefresh: forceRefresh,
    );

    // 4. Update memory cache
    _memoryCache[cleanGstin] = freshSnapshot;

    // 5. Persist to database for auditing and offline availability
    if (client != null) {
      try {
        final brokerId = await _storage.getUserId();
        await client.from('counterparty_gst_filing_snapshots').insert({
          'company_id': companyId,
          'broker_id': brokerId,
          'gstin': cleanGstin,
          'snapshot_payload': freshSnapshot.toJson(),
          'data_source': freshSnapshot.dataSource,
          'historical_coverage': freshSnapshot.summary.historicalCoverage,
          'total_filed': freshSnapshot.summary.totalConfirmedFiled,
          'total_overdue': freshSnapshot.summary.totalConfirmedOverdue,
          'registration_status': freshSnapshot.taxpayer.status,
          'retrieved_at': freshSnapshot.retrievedAt.toIso8601String(),
        });
      } catch (e) {
        debugPrint('GST filing database cache write notice: $e');
      }
    }

    return freshSnapshot;
  }

  /// Records a manual verification conducted by the broker on the Official GST Portal
  /// (services.gst.gov.in) with official CAPTCHA resolution.
  Future<GstFilingSnapshot> recordManualPortalVerification({
    required String gstin,
    String? companyId,
    required String observedStatus, // 'Active', 'Cancelled', 'Suspended'
    String? latestFilingSummary,
    String? brokerNotes,
  }) async {
    final cleanGstin = GstinRules.normalize(gstin);
    if (!GstinRules.hasValidFormat(cleanGstin)) {
      throw const GstApiException(
        message: 'Invalid GSTIN format. A valid 15-character GSTIN is required.',
        isInvalidGstin: true,
      );
    }

    final stateName = GstinRules.stateOf(cleanGstin) ?? 'State not specified';
    final taxpayer = GstTaxpayerDetails(
      gstin: cleanGstin,
      legalName: brokerNotes?.isNotEmpty == true
          ? brokerNotes!
          : 'Taxpayer ($cleanGstin)',
      status: observedStatus,
      state: stateName,
      taxpayerType: 'Regular',
      filingFrequency: 'Monthly',
    );

    final summary = GstCredibilitySummary(
      registrationStatus: observedStatus,
      isActive: observedStatus.toLowerCase() == 'active',
      totalConfirmedFiled: 1,
      totalConfirmedOverdue: 0,
      historicalCoverage: 'Official GST Portal Manual Lookup',
      filingFrequency: 'Monthly',
      dataLimitationNotice: latestFilingSummary?.isNotEmpty == true
          ? 'Broker verified on official portal: $latestFilingSummary'
          : 'Broker verified filing status directly on official portal services.gst.gov.in with official CAPTCHA.',
    );

    final snapshot = GstFilingSnapshot(
      gstin: cleanGstin,
      companyId: companyId,
      taxpayer: taxpayer,
      availableFinancialYears: const ['2026-27', '2025-26', '2024-25', '2023-24', '2022-23', '2021-22'],
      filings: const [],
      summary: summary,
      retrievedAt: DateTime.now(),
      dataSource: 'Official GST Portal (Manually Verified)',
      isCached: false,
    );

    _memoryCache[cleanGstin] = snapshot;

    final client = _supabase;
    if (client != null) {
      try {
        final brokerId = await _storage.getUserId();
        await client.from('counterparty_gst_filing_snapshots').insert({
          'company_id': companyId,
          'broker_id': brokerId,
          'gstin': cleanGstin,
          'snapshot_payload': snapshot.toJson(),
          'data_source': snapshot.dataSource,
          'historical_coverage': snapshot.summary.historicalCoverage,
          'total_filed': snapshot.summary.totalConfirmedFiled,
          'total_overdue': snapshot.summary.totalConfirmedOverdue,
          'registration_status': snapshot.taxpayer.status,
          'retrieved_at': snapshot.retrievedAt.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Manual GST portal verification persistence notice: $e');
      }
    }

    return snapshot;
  }

  /// Invalidate cache for a specific GSTIN
  void invalidateCache(String gstin) {
    final clean = GstinRules.normalize(gstin);
    _memoryCache.remove(clean);
  }
}

/// Provider for GstFilingRepository
final gstFilingRepositoryProvider = Provider<GstFilingRepository>((ref) {
  SupabaseClient? client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    client = null;
  }

  return GstFilingRepository(
    provider: GstJamkuPublicApiProvider(),
    supabase: client,
    storage: SecureStorageService(),
  );
});
