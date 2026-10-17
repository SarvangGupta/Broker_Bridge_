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
  final String searchQuery;

  const DealsState({
    this.isLoading = false,
    this.errorMessage,
    this.contractNotice,
    this.deals = const [],
    this.statusFilter,
    this.searchQuery = '',
  });

  DealsState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? contractNotice,
    List<DealItem>? deals,
    DealStatus? statusFilter,
    bool clearStatusFilter = false,
    String? searchQuery,
  }) {
    return DealsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      contractNotice: contractNotice,
      deals: deals ?? this.deals,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<DealItem> get filteredDeals {
    return deals.where((deal) {
      if (statusFilter != null && deal.status != statusFilter) {
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
  int get activeCount => deals.where((d) => d.status.isOperational).length;
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

  void setStatusFilter(DealStatus? filter) {
    if (filter == null) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: filter);
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
