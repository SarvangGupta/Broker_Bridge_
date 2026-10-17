import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/deal_repository.dart';
import '../../domain/deal_model.dart';
import 'deals_controller.dart';

class DealDetailState {
  final bool isLoading;
  final bool isLoadingHistory;
  final bool isSubmitting;
  final String? errorMessage;
  final String? contractNotice;
  final String? actionFeedback;
  final String? finalizedBookingRef;
  final DealDetailItem? detail;
  final List<DealVersionItem> versionHistory;

  const DealDetailState({
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.contractNotice,
    this.actionFeedback,
    this.finalizedBookingRef,
    this.detail,
    this.versionHistory = const [],
  });

  DealDetailState copyWith({
    bool? isLoading,
    bool? isLoadingHistory,
    bool? isSubmitting,
    String? errorMessage,
    String? contractNotice,
    String? actionFeedback,
    String? finalizedBookingRef,
    DealDetailItem? detail,
    List<DealVersionItem>? versionHistory,
  }) {
    return DealDetailState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      contractNotice: contractNotice,
      actionFeedback: actionFeedback,
      finalizedBookingRef: finalizedBookingRef ?? this.finalizedBookingRef,
      detail: detail ?? this.detail,
      versionHistory: versionHistory ?? this.versionHistory,
    );
  }
}

class DealDetailNotifier extends Notifier<DealDetailState> {
  final String dealId;

  DealDetailNotifier(this.dealId);

  DealRepository get _repository => ref.read(dealRepositoryProvider);

  @override
  DealDetailState build() {
    Future.microtask(() {
      loadDetail();
      loadVersionHistory();
    });
    return const DealDetailState(isLoading: true);
  }

  Future<void> loadDetail() async {
    state = state.copyWith(isLoading: true, errorMessage: null, contractNotice: null);

    final result = await _repository.getDealDetail(dealId);

    switch (result) {
      case DealSuccess<DealDetailItem>(:final data):
        state = state.copyWith(isLoading: false, detail: data);
      case DealContractPending<DealDetailItem>(:final contractNotice):
        state = state.copyWith(isLoading: false, contractNotice: contractNotice);
      case DealError<DealDetailItem>(:final message):
        state = state.copyWith(isLoading: false, errorMessage: message);
      case DealUnauthorized<DealDetailItem>(:final message):
        state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  Future<void> loadVersionHistory() async {
    state = state.copyWith(isLoadingHistory: true);
    final result = await _repository.getDealVersionHistory(dealId);
    if (result is DealSuccess<List<DealVersionItem>>) {
      state = state.copyWith(isLoadingHistory: false, versionHistory: result.data);
    } else {
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  Future<bool> proposeTermsAmendment(UpdateDealTermsDto dto) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    final result = await _repository.updateDealTerms(dto);

    switch (result) {
      case DealSuccess<DealDetailItem>(:final data):
        state = state.copyWith(
          isSubmitting: false,
          detail: data,
          actionFeedback:
              'Terms revised to v${dto.expectedVersion + 1}. Counterparty confirmations have been reset.',
        );
        await loadVersionHistory();
        return true;
      case DealError<DealDetailItem>(:final message):
        state = state.copyWith(isSubmitting: false, errorMessage: message);
        return false;
      case DealUnauthorized<DealDetailItem>(:final message):
        state = state.copyWith(isSubmitting: false, errorMessage: message);
        return false;
      case DealContractPending<DealDetailItem>(:final contractNotice):
        state = state.copyWith(isSubmitting: false, contractNotice: contractNotice);
        return false;
    }
  }

  Future<bool> recordPartyConfirmation(String party, {String? notes}) async {
    final currentVer = state.detail?.confirmations.latestVersionNumber ??
        state.detail?.deal.latestVersionNumber ??
        1;

    state = state.copyWith(isSubmitting: true, errorMessage: null);
    final result = await _repository.recordPartyConfirmation(
      PartyConfirmationDto(
        dealId: dealId,
        versionNumber: currentVer,
        party: party,
        verificationNotes: notes,
      ),
    );

    if (result is DealSuccess<DealConfirmationState>) {
      state = state.copyWith(
        isSubmitting: false,
        actionFeedback: 'Formal $party confirmation recorded against v$currentVer.',
      );
      await loadDetail();
      await loadVersionHistory();
      return true;
    } else if (result is DealError<DealConfirmationState>) {
      state = state.copyWith(isSubmitting: false, errorMessage: result.message);
      return false;
    }
    state = state.copyWith(isSubmitting: false);
    return false;
  }

  Future<String?> finalizeDeal(int expectedVersion) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    final result = await _repository.finalizeDeal(dealId, expectedVersion);

    if (result is DealSuccess<String>) {
      final bookingRef = result.data;
      state = state.copyWith(
        isSubmitting: false,
        finalizedBookingRef: bookingRef,
        actionFeedback: 'Deal successfully finalized! Booking reference: $bookingRef',
      );
      await loadDetail();
      await loadVersionHistory();
      return bookingRef;
    } else if (result is DealError<String>) {
      state = state.copyWith(isSubmitting: false, errorMessage: result.message);
      return null;
    }
    state = state.copyWith(isSubmitting: false);
    return null;
  }

  Future<bool> cancelDeal(String reason) async {
    state = state.copyWith(isSubmitting: true);
    final result = await _repository.cancelDeal(dealId, reason);

    if (result is DealSuccess<bool> && result.data) {
      await loadDetail();
      await loadVersionHistory();
      return true;
    } else if (result is DealError<bool>) {
      state = state.copyWith(isSubmitting: false, errorMessage: result.message);
      return false;
    }
    state = state.copyWith(isSubmitting: false);
    return false;
  }
}

final dealDetailProvider =
    NotifierProvider.family<DealDetailNotifier, DealDetailState, String>(
  (dealId) => DealDetailNotifier(dealId),
);
