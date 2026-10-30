import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/gst_filing_provider.dart';
import '../../domain/gst_filing_history.dart';

enum GstFilingLoadingStatus {
  initial,
  loading,
  success,
  empty,
  error,
}

@immutable
class GstFilingState {
  final GstFilingLoadingStatus status;
  final GstFilingSnapshot? snapshot;
  final String? errorMessage;
  final String? selectedFinancialYear;
  final bool isRefreshing;

  const GstFilingState({
    this.status = GstFilingLoadingStatus.initial,
    this.snapshot,
    this.errorMessage,
    this.selectedFinancialYear,
    this.isRefreshing = false,
  });

  bool get isLoading =>
      status == GstFilingLoadingStatus.loading ||
      status == GstFilingLoadingStatus.initial;
  bool get isSuccess => status == GstFilingLoadingStatus.success;
  bool get isEmpty => status == GstFilingLoadingStatus.empty;
  bool get isError => status == GstFilingLoadingStatus.error;

  List<TaxPeriodFiling> get displayedFilings {
    if (snapshot == null) return const [];
    if (selectedFinancialYear == null || selectedFinancialYear == 'All') {
      return snapshot!.filings;
    }
    return snapshot!.filingsForYear(selectedFinancialYear!);
  }

  GstFilingState copyWith({
    GstFilingLoadingStatus? status,
    GstFilingSnapshot? snapshot,
    String? errorMessage,
    String? selectedFinancialYear,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return GstFilingState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedFinancialYear: selectedFinancialYear ?? this.selectedFinancialYear,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class GstFilingController extends Notifier<GstFilingState> {
  final String gstin;

  GstFilingController(this.gstin);

  GstFilingRepository get _repository => ref.read(gstFilingRepositoryProvider);

  @override
  GstFilingState build() {
    return const GstFilingState();
  }

  /// Load GST filing history for [targetGstin], with caching unless [forceRefresh] is true.
  Future<void> loadFilingHistory(
    String targetGstin, {
    String? companyId,
    bool forceRefresh = false,
  }) async {
    final isInitial = state.snapshot == null;
    state = state.copyWith(
      status: isInitial ? GstFilingLoadingStatus.loading : state.status,
      isRefreshing: forceRefresh,
      clearError: true,
    );

    try {
      final snapshot = await _repository.getFilingHistory(
        targetGstin,
        companyId: companyId,
        forceRefresh: forceRefresh,
      );

      final defaultYear = snapshot.availableFinancialYears.isNotEmpty
          ? snapshot.availableFinancialYears.first
          : null;

      if (snapshot.filings.isEmpty) {
        state = state.copyWith(
          status: GstFilingLoadingStatus.empty,
          snapshot: snapshot,
          selectedFinancialYear: defaultYear,
          isRefreshing: false,
        );
      } else {
        state = state.copyWith(
          status: GstFilingLoadingStatus.success,
          snapshot: snapshot,
          selectedFinancialYear: state.selectedFinancialYear ?? defaultYear,
          isRefreshing: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: GstFilingLoadingStatus.error,
        errorMessage: e is GstApiException ? e.message : 'Failed to retrieve GST filing history: $e',
        isRefreshing: false,
      );
    }
  }

  /// Record manual verification from the Official GST Portal (services.gst.gov.in)
  Future<void> recordManualPortalVerification({
    required String targetGstin,
    String? companyId,
    required String observedStatus,
    String? latestFilingSummary,
    String? brokerNotes,
  }) async {
    state = state.copyWith(status: GstFilingLoadingStatus.loading, clearError: true);
    try {
      final snapshot = await _repository.recordManualPortalVerification(
        gstin: targetGstin,
        companyId: companyId,
        observedStatus: observedStatus,
        latestFilingSummary: latestFilingSummary,
        brokerNotes: brokerNotes,
      );
      state = state.copyWith(
        status: GstFilingLoadingStatus.success,
        snapshot: snapshot,
        selectedFinancialYear: 'All',
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: GstFilingLoadingStatus.error,
        errorMessage: 'Failed to record manual portal verification: $e',
        isRefreshing: false,
      );
    }
  }

  /// Change financial year filter
  void selectFinancialYear(String? fy) {
    state = state.copyWith(selectedFinancialYear: fy);
  }

  /// Reset state
  void clear() {
    state = const GstFilingState();
  }
}

/// Family provider for GstFilingController keyed by GSTIN
final gstFilingControllerProvider =
    NotifierProvider.family<GstFilingController, GstFilingState, String>(
  (gstin) => GstFilingController(gstin),
);
