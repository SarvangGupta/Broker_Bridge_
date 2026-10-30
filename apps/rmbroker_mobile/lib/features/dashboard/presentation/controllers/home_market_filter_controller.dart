import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/market_filter_criteria.dart';

@immutable
class HomeMarketFilterState {
  final MarketFilterCriteria requirementsFilter;
  final MarketFilterCriteria offersFilter;
  final bool isOffersTab;

  const HomeMarketFilterState({
    this.requirementsFilter = const MarketFilterCriteria.empty(),
    this.offersFilter = const MarketFilterCriteria.empty(),
    this.isOffersTab = false,
  });

  MarketFilterCriteria get currentFilter =>
      isOffersTab ? offersFilter : requirementsFilter;

  int get currentActiveFilterCount => currentFilter.activeFilterCount;
  bool get hasActiveFilters => currentFilter.hasActiveFilters;

  int get requirementsActiveFilterCount => requirementsFilter.activeFilterCount;
  int get offersActiveFilterCount => offersFilter.activeFilterCount;

  HomeMarketFilterState copyWith({
    MarketFilterCriteria? requirementsFilter,
    MarketFilterCriteria? offersFilter,
    bool? isOffersTab,
  }) {
    return HomeMarketFilterState(
      requirementsFilter: requirementsFilter ?? this.requirementsFilter,
      offersFilter: offersFilter ?? this.offersFilter,
      isOffersTab: isOffersTab ?? this.isOffersTab,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeMarketFilterState &&
          runtimeType == other.runtimeType &&
          requirementsFilter == other.requirementsFilter &&
          offersFilter == other.offersFilter &&
          isOffersTab == other.isOffersTab;

  @override
  int get hashCode => Object.hash(requirementsFilter, offersFilter, isOffersTab);
}

class HomeMarketFilterNotifier extends Notifier<HomeMarketFilterState> {
  @override
  HomeMarketFilterState build() {
    return const HomeMarketFilterState();
  }

  void setTab(bool isOffers) {
    state = state.copyWith(isOffersTab: isOffers);
  }

  void setRequirementsFilter(MarketFilterCriteria filter) {
    state = state.copyWith(requirementsFilter: filter);
  }

  void setOffersFilter(MarketFilterCriteria filter) {
    state = state.copyWith(offersFilter: filter);
  }

  void resetRequirementsFilter() {
    state = state.copyWith(
      requirementsFilter: const MarketFilterCriteria.empty(),
    );
  }

  void resetOffersFilter() {
    state = state.copyWith(
      offersFilter: const MarketFilterCriteria.empty(),
    );
  }

  void resetCurrentTabFilter() {
    if (state.isOffersTab) {
      resetOffersFilter();
    } else {
      resetRequirementsFilter();
    }
  }

  void resetAll() {
    state = const HomeMarketFilterState();
  }
}

final homeMarketFilterProvider =
    NotifierProvider<HomeMarketFilterNotifier, HomeMarketFilterState>(
  HomeMarketFilterNotifier.new,
);

