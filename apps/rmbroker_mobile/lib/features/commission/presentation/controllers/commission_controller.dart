import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../deals/data/deal_repository.dart';
import '../../data/commission_repository.dart';
import '../../domain/commission_model.dart';

/// Provider for CommissionRepository
final commissionRepositoryProvider = Provider<CommissionRepository>((ref) {
  return CommissionRepository();
});

/// Provider for CommissionController
final commissionControllerProvider =
    NotifierProvider<CommissionController, CommissionState>(
  CommissionController.new,
);

enum CommissionViewStatus {
  initial,
  loading,
  loaded,
  empty,
  error,
}

class CommissionState {
  final CommissionViewStatus status;
  final CommissionSummary summary;
  final List<CommissionRecord> allRecords;
  final List<CommissionRecord> filteredRecords;
  final CommissionStatus? selectedStatus;
  final String selectedPeriod;
  final String searchQuery;
  final String? errorMessage;
  final bool isSubmittingPayment;
  final String? paymentSuccessMessage;

  const CommissionState({
    this.status = CommissionViewStatus.initial,
    required this.summary,
    this.allRecords = const [],
    this.filteredRecords = const [],
    this.selectedStatus,
    this.selectedPeriod = 'All Time',
    this.searchQuery = '',
    this.errorMessage,
    this.isSubmittingPayment = false,
    this.paymentSuccessMessage,
  });

  factory CommissionState.initial() {
    return CommissionState(
      status: CommissionViewStatus.initial,
      summary: CommissionSummary.zero(),
      allRecords: const [],
      filteredRecords: const [],
    );
  }

  CommissionState copyWith({
    CommissionViewStatus? status,
    CommissionSummary? summary,
    List<CommissionRecord>? allRecords,
    List<CommissionRecord>? filteredRecords,
    CommissionStatus? selectedStatus,
    bool clearSelectedStatus = false,
    String? selectedPeriod,
    String? searchQuery,
    String? errorMessage,
    bool? isSubmittingPayment,
    String? paymentSuccessMessage,
    bool clearMessages = false,
  }) {
    return CommissionState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      allRecords: allRecords ?? this.allRecords,
      filteredRecords: filteredRecords ?? this.filteredRecords,
      selectedStatus: clearSelectedStatus ? null : (selectedStatus ?? this.selectedStatus),
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      isSubmittingPayment: isSubmittingPayment ?? this.isSubmittingPayment,
      paymentSuccessMessage:
          clearMessages ? null : (paymentSuccessMessage ?? this.paymentSuccessMessage),
    );
  }
}

class CommissionController extends Notifier<CommissionState> {
  CommissionRepository get _repository => ref.read(commissionRepositoryProvider);

  @override
  CommissionState build() {
    Future.microtask(() => loadCommissionData());
    return CommissionState.initial();
  }

  /// Loads commission summary and records from repository.
  Future<void> loadCommissionData({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(status: CommissionViewStatus.loading, clearMessages: true);
    }

    final recordsResult = await _repository.getCommissionRecords(
      period: state.selectedPeriod,
    );

    switch (recordsResult) {
      case DealSuccess(:final data):
        final summary = CommissionSummary.fromRecords(data, period: state.selectedPeriod);
        final filtered = _applyFilters(data, state.selectedStatus, state.searchQuery);

        state = state.copyWith(
          status: data.isEmpty ? CommissionViewStatus.empty : CommissionViewStatus.loaded,
          summary: summary,
          allRecords: data,
          filteredRecords: filtered,
          errorMessage: null,
        );

      case DealError(:final message):
        state = state.copyWith(
          status: CommissionViewStatus.error,
          errorMessage: message,
        );

      case DealUnauthorized(:final message):
        state = state.copyWith(
          status: CommissionViewStatus.error,
          errorMessage: message,
        );

      case DealContractPending(:final contractNotice):
        state = state.copyWith(
          status: CommissionViewStatus.empty,
          errorMessage: contractNotice,
        );
    }
  }

  /// Filters records by commission status.
  void setStatusFilter(CommissionStatus? status) {
    final filtered = _applyFilters(state.allRecords, status, state.searchQuery);
    state = state.copyWith(
      selectedStatus: status,
      clearSelectedStatus: status == null,
      filteredRecords: filtered,
    );
  }

  /// Filters by time period.
  Future<void> setPeriodFilter(String period) async {
    state = state.copyWith(selectedPeriod: period);
    await loadCommissionData();
  }

  /// Searches records by deal reference, counterparty, or commodity.
  void setSearchQuery(String query) {
    final filtered = _applyFilters(state.allRecords, state.selectedStatus, query);
    state = state.copyWith(
      searchQuery: query,
      filteredRecords: filtered,
    );
  }

  List<CommissionRecord> _applyFilters(
    List<CommissionRecord> records,
    CommissionStatus? status,
    String query,
  ) {
    var list = records;
    if (status != null) {
      list = list.where((r) => r.status == status).toList();
    }
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((r) {
        return r.dealReference.toLowerCase().contains(q) ||
            (r.bookingReference?.toLowerCase().contains(q) ?? false) ||
            r.commodityName.toLowerCase().contains(q) ||
            r.buyerCompanyName.toLowerCase().contains(q) ||
            r.sellerCompanyName.toLowerCase().contains(q) ||
            (r.invoiceNumber?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return list;
  }

  /// Submits a new payment reference.
  Future<bool> logCommissionPayment(LogPaymentDto dto) async {
    state = state.copyWith(isSubmittingPayment: true, clearMessages: true);

    final result = await _repository.logCommissionPayment(dto);

    switch (result) {
      case DealSuccess(:final data):
        await loadCommissionData(isRefresh: true);
        state = state.copyWith(
          isSubmittingPayment: false,
          paymentSuccessMessage:
              'Payment of ₹${data.amount.toStringAsFixed(2)} (Ref: ${data.referenceNumber}) recorded successfully.',
        );
        return true;

      case DealError(:final message):
        state = state.copyWith(
          isSubmittingPayment: false,
          errorMessage: message,
        );
        return false;

      default:
        state = state.copyWith(
          isSubmittingPayment: false,
          errorMessage: 'Failed to record commission payment.',
        );
        return false;
    }
  }

  /// Records an auditable commission rate adjustment.
  Future<bool> adjustCommission({
    required String dealId,
    required double newRatePerMT,
    required String reason,
  }) async {
    final result = await _repository.recordCommissionAdjustment(
      dealId: dealId,
      newRatePerMT: newRatePerMT,
      reason: reason,
    );

    switch (result) {
      case DealSuccess():
        await loadCommissionData(isRefresh: true);
        return true;
      case DealError(:final message):
        state = state.copyWith(errorMessage: message);
        return false;
      default:
        state = state.copyWith(errorMessage: 'Failed to adjust commission.');
        return false;
    }
  }
}
