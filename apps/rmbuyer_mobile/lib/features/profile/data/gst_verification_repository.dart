import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../domain/buyer_profile.dart';
import '../domain/gst_certificate_data.dart';
import 'buyer_profile_repository.dart';

/// GST verification status as established by an authoritative GST
/// verification record. `companies.is_verified` is NOT a source: it is a
/// legacy company-approval flag (set by the web Company Approvals action or
/// seed data, and currently writable by the company's own users), and it
/// carries no evidence that a GST certificate was submitted or reviewed.
enum GstVerificationStatus {
  notSubmitted,
  pending,
  approved,
  rejected,
  noCompany,
}

/// The latest GST verification record for a company, as stored by the backend.
class GstVerificationRecord {
  final GstVerificationStatus status;
  final String? gstin;
  final String? legalName;
  final String? tradeName;
  final String? constitution;
  final String? principalAddress;
  final String? pinCode;
  final String? registrationType;
  final String? registrationDate;
  final String? validityFrom;
  final String? validityTo;
  final String? issueDate;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  const GstVerificationRecord({
    required this.status,
    this.gstin,
    this.legalName,
    this.tradeName,
    this.constitution,
    this.principalAddress,
    this.pinCode,
    this.registrationType,
    this.registrationDate,
    this.validityFrom,
    this.validityTo,
    this.issueDate,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  /// Parses a `buyer_gst_verifications` row. Throws on an unknown status so a
  /// status is never guessed.
  factory GstVerificationRecord.fromRow(Map<String, dynamic> row) {
    final status = switch (row['status']?.toString()) {
      'pending' => GstVerificationStatus.pending,
      'approved' => GstVerificationStatus.approved,
      'rejected' => GstVerificationStatus.rejected,
      final other => throw FormatException(
        'Unknown GST verification status: $other',
      ),
    };
    DateTime? date(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    String? str(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }
    String? normDate(Object? v) {
      final s = str(v);
      if (s == null) return null;
      final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
      if (m != null) {
        return '${m[3]}/${m[2]}/${m[1]}';
      }
      return s;
    }

    return GstVerificationRecord(
      status: status,
      gstin: str(row['gstin']),
      legalName: str(row['legal_name']),
      tradeName: str(row['trade_name']),
      constitution: str(row['constitution']),
      principalAddress: str(row['principal_address']),
      pinCode: str(row['pin_code']),
      registrationType: str(row['registration_type']),
      registrationDate: normDate(row['registration_date']),
      validityFrom: normDate(row['validity_from']),
      validityTo: normDate(row['validity_to']),
      issueDate: normDate(row['issue_date']),
      rejectionReason: str(row['rejection_reason']),
      submittedAt: date(row['submitted_at']),
      reviewedAt: date(row['reviewed_at']),
    );
  }
}

/// Where authoritative GST verification records are read from.
abstract class GstVerificationRecordSource {
  /// Whether the backend supports secure submission and records.
  bool get available;

  /// The company's latest record, or null when none exists. Throws when the
  /// backend cannot be read.
  Future<GstVerificationRecord?> latestFor(String companyId);

  /// Uploads the certificate image and submits [draft] for review. Returns the
  /// record only once the server has saved it (status `pending`); throws
  /// otherwise. Never called when [available] is false.
  Future<GstVerificationRecord> submit(
    GstSubmissionDraft draft,
    String imagePath,
  );
}

/// Production today: migrations 0053/0054 are not applied there, so there is
/// no `buyer_gst_verifications` table, submission RPC or certificate bucket and
/// no company can have a GST verification record.
class NoGstVerificationBackend implements GstVerificationRecordSource {
  const NoGstVerificationBackend();

  @override
  bool get available => false;

  @override
  Future<GstVerificationRecord?> latestFor(String companyId) async => null;

  @override
  Future<GstVerificationRecord> submit(
    GstSubmissionDraft draft,
    String imagePath,
  ) => throw StateError('GST verification submission is not available.');
}

/// The secure backend from migration 0054 (`buyer_gst_verifications`,
/// `submit_buyer_gst_verification`, private bucket). Ownership, validation and
/// the `pending` status are decided by the server; this class only uploads to
/// the caller's own folder and calls the RPC.
class SupabaseGstVerificationBackend implements GstVerificationRecordSource {
  static const String bucket = 'brokerbridge_buyer_gst_certificates';
  static const int maxBytes = 5 * 1024 * 1024;
  static const Duration timeout = Duration(seconds: 30);

  final SupabaseClient? _customClient;

  SupabaseGstVerificationBackend({SupabaseClient? client})
    : _customClient = client;

  SupabaseClient get _client => _customClient ?? Supabase.instance.client;

  @override
  bool get available => true;

  @override
  Future<GstVerificationRecord?> latestFor(String companyId) async {
    final row = await _client
        .from('buyer_gst_verifications')
        .select(
          'status, gstin, rejection_reason, submitted_at, reviewed_at, '
          'legal_name, trade_name, constitution, principal_address, pin_code, '
          'registration_type, registration_date, validity_from, validity_to, issue_date',
        )
        .eq('company_id', companyId)
        .neq('status', 'superseded')
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(timeout);
    return row == null ? null : GstVerificationRecord.fromRow(row);
  }

  @override
  Future<GstVerificationRecord> submit(
    GstSubmissionDraft draft,
    String imagePath,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const GstSubmissionException('Please sign in again.');
    }
    final bytes = await File(imagePath).readAsBytes();
    if (bytes.isEmpty) {
      throw const GstSubmissionException('The certificate image is empty.');
    }
    if (bytes.length > maxBytes) {
      throw const GstSubmissionException(
        'The certificate image is larger than 5 MB.',
      );
    }
    final isPng = imagePath.toLowerCase().endsWith('.png');
    final objectPath = '$uid/${_uuidV4()}.${isPng ? 'png' : 'jpg'}';

    await _client.storage
        .from(bucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: isPng ? 'image/png' : 'image/jpeg',
          ),
        )
        .timeout(timeout);

    final row = await _client
        .rpc(
          'submit_buyer_gst_verification',
          params: {
            'p_submission': draft.toPayload(),
            'p_certificate_path': objectPath,
          },
        )
        .timeout(timeout);
    final map = row is List ? (row.isEmpty ? null : row.first) : row;
    if (map is! Map) {
      throw const GstSubmissionException(
        'The server did not confirm the submission.',
      );
    }
    final record = GstVerificationRecord.fromRow(
      Map<String, dynamic>.from(map),
    );
    if (record.status != GstVerificationStatus.pending) {
      throw const GstSubmissionException(
        'The server did not confirm the submission.',
      );
    }
    return record;
  }

  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}

/// The source to use in this build: the secure backend only when explicitly
/// enabled for a non-production project (see [AppConfig]).
GstVerificationRecordSource defaultGstVerificationSource() =>
    AppConfig.gstVerificationBackendEnabled
    ? SupabaseGstVerificationBackend()
    : const NoGstVerificationBackend();

/// A submission failure with a message safe to show the buyer.
class GstSubmissionException implements Exception {
  final String message;
  const GstSubmissionException(this.message);

  /// Maps server errors (by SQLSTATE, never by message text) to buyer-facing text.
  static String describe(Object error) {
    if (error is GstSubmissionException) return error.message;
    if (error is TimeoutException) {
      return 'No response from the server. Refresh your status before trying again.';
    }
    if (error is StorageException) {
      return 'The certificate could not be uploaded. Use a JPG or PNG under 5 MB and try again.';
    }
    if (error is PostgrestException) {
      return switch (error.code) {
        '23505' => 'This GSTIN is already registered for verification by another account.',
        '22023' => 'The server rejected these details: ${error.message}',
        '42501' =>
          'You are not allowed to submit GST verification for this account.',
        _ => 'The submission could not be saved. Please try again.',
      };
    }
    return 'The submission could not be saved. Please try again.';
  }
}

class GstVerificationState {
  final GstVerificationStatus status;
  final BuyerProfile profile;
  final GstVerificationRecord? record;

  const GstVerificationState(this.status, this.profile, this.record);

  /// The legacy company flag is set but no GST record supports it.
  bool get hasUnbackedLegacyFlag =>
      profile.companyVerified == true &&
      status != GstVerificationStatus.approved;
}

/// Reads the buyer's GST verification status and submits certificates through
/// the secure backend. Never writes the company record.
class GstVerificationRepository {
  final BuyerProfileRepository _profiles;
  final GstVerificationRecordSource _records;

  GstVerificationRepository({
    BuyerProfileRepository? profiles,
    GstVerificationRecordSource? records,
  }) : _profiles = profiles ?? BuyerProfileRepository(),
       _records = records ?? defaultGstVerificationSource();

  bool get submissionAvailable => _records.available;

  /// Server-confirmed submission; throws on any failure (see
  /// [GstSubmissionException.describe]).
  Future<GstVerificationRecord> submit(
    GstSubmissionDraft draft,
    String imagePath,
  ) => _records.submit(draft, imagePath);

  Future<GstVerificationState> loadStatus() async {
    final profile = await _profiles.getProfile();
    final companyId = profile.companyId;
    if (companyId == null) {
      return GstVerificationState(
        GstVerificationStatus.noCompany,
        profile,
        null,
      );
    }
    final record = await _records.latestFor(companyId);
    return GstVerificationState(
      record?.status ?? GstVerificationStatus.notSubmitted,
      profile,
      record,
    );
  }
}
