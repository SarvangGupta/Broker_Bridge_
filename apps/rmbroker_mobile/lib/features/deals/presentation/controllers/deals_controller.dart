import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/deal_repository.dart';
import '../../domain/deal_model.dart';

final dealRepositoryProvider = Provider<DealRepository>((ref) {
  return DealRepository();
});

class DealsState {
  final bool isLoading;
  final String? errorMessage;
  final String? contractNotice;
  final List<DealItem> deals;
  final DealStatus? statusFilter;
  final String? presetFilter;
  final String searchQuery;

  const DealsState({
    this.isLoading = false,
    this.errorMessage,
    this.contractNotice,
    this.deals = const [],
    this.statusFilter,
    this.presetFilter,
    this.searchQuery = '',
  });

  DealsState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? contractNotice,
    List<DealItem>? deals,
    DealStatus? statusFilter,
    bool clearStatusFilter = false,
    String? presetFilter,
    bool clearPresetFilter = false,
    String? searchQuery,
  }) {
    return DealsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      contractNotice: contractNotice,
      deals: deals ?? this.deals,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      presetFilter: clearPresetFilter ? null : (presetFilter ?? this.presetFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<DealItem> get filteredDeals {
    return deals.where((deal) {
      if (presetFilter != null) {
        switch (presetFilter) {
          case 'active':
            if (deal.status == DealStatus.cancelled || deal.status == DealStatus.completed) {
              return false;
            }
            break;
          case 'signoff':
            const signoffStatuses = [
              DealStatus.draft,
              DealStatus.awaitingBuyerConfirmation,
              DealStatus.awaitingSellerConfirmation,
              DealStatus.readyToFinalize,
            ];
            if (!signoffStatuses.contains(deal.status)) return false;
            break;
          case 'dispatch_due':
            if (deal.status != DealStatus.finalized && deal.status != DealStatus.inFulfillment) {
              return false;
            }
            break;
          case 'disputed':
            if (deal.status != DealStatus.disputed) return false;
            break;
        }
      } else if (statusFilter != null && deal.status != statusFilter) {
        return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        final matchRef = deal.ref.toLowerCase().contains(q);
        final matchComm = deal.commodityName.toLowerCase().contains(q);
        final matchBuyer = deal.buyerCompanyName.toLowerCase().contains(q);
        final matchSeller = deal.sellerCompanyName.toLowerCase().contains(q);
        return matchRef || matchComm || matchBuyer || matchSeller;
      }
      return true;
    }).toList();
  }

  int get totalCount => deals.length;
  int get activeCount =>
      deals.where((d) => d.status != DealStatus.cancelled && d.status != DealStatus.completed).length;
  int get signoffCount => deals.where((d) =>
      d.status == DealStatus.draft ||
      d.status == DealStatus.awaitingBuyerConfirmation ||
      d.status == DealStatus.awaitingSellerConfirmation ||
      d.status == DealStatus.readyToFinalize).length;
  int get dispatchDueCount => deals.where((d) =>
      d.status == DealStatus.finalized || d.status == DealStatus.inFulfillment).length;
  int get disputedCount => deals.where((d) => d.status == DealStatus.disputed).length;
  int get finalizedCount =>
      deals.where((d) => d.status == DealStatus.finalized || d.status == DealStatus.inFulfillment).length;
  int get completedCount => deals.where((d) => d.status == DealStatus.completed).length;
  int get cancelledCount => deals.where((d) => d.status == DealStatus.cancelled).length;

  double get totalValuation =>
      deals.fold(0.0, (sum, d) => sum + d.totalValuation);

  double get totalVolumeMT =>
      deals.fold(0.0, (sum, d) => sum + d.agreedQuantity);
}

class DealsNotifier extends Notifier<DealsState> {
  DealRepository get _repository => ref.read(dealRepositoryProvider);

  @override
  DealsState build() {
    Future.microtask(() => loadDeals());
    return const DealsState(isLoading: true);
  }

  Future<void> loadDeals() async {
    state = state.copyWith(isLoading: true, errorMessage: null, contractNotice: null);

    final result = await _repository.getDeals();

    switch (result) {
      case DealSuccess<List<DealItem>>(:final data):
        state = state.copyWith(
          isLoading: false,
          deals: data,
          errorMessage: null,
          contractNotice: null,
        );
      case DealContractPending<List<DealItem>>(:final contractNotice):
        state = state.copyWith(
          isLoading: false,
          contractNotice: contractNotice,
        );
      case DealError<List<DealItem>>(:final message):
        state = state.copyWith(
          isLoading: false,
          errorMessage: message,
        );
      case DealUnauthorized<List<DealItem>>(:final message):
        state = state.copyWith(
          isLoading: false,
          errorMessage: message,
        );
    }
  }

  void setPresetFilter(String? preset) {
    if (preset == null) {
      state = state.copyWith(clearPresetFilter: true);
    } else {
      state = state.copyWith(presetFilter: preset, clearStatusFilter: true);
    }
  }

  void setStatusFilter(DealStatus? filter) {
    if (filter == null) {
      state = state.copyWith(clearStatusFilter: true, clearPresetFilter: true);
    } else {
      state = state.copyWith(statusFilter: filter, clearPresetFilter: true);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<DealItem?> createDeal(CreateDealDto dto) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _repository.createDealFromAllocation(dto);

    switch (result) {
      case DealSuccess<DealItem>(:final data):
        state = state.copyWith(
          isLoading: false,
          deals: [data, ...state.deals],
        );
        return data;
      case DealError<DealItem>(:final message):
        state = state.copyWith(isLoading: false, errorMessage: message);
        return null;
      case DealContractPending<DealItem>(:final contractNotice):
        state = state.copyWith(isLoading: false, contractNotice: contractNotice);
        return null;
      case DealUnauthorized<DealItem>(:final message):
        state = state.copyWith(isLoading: false, errorMessage: message);
        return null;
    }
  }

  Future<bool> cancelDeal(String dealId, String reason) async {
    final result = await _repository.cancelDeal(dealId, reason);

    if (result is DealSuccess<bool> && result.data) {
      await loadDeals();
      return true;
    }
    return false;
  }
}

final dealsProvider =
    NotifierProvider<DealsNotifier, DealsState>(DealsNotifier.new);
