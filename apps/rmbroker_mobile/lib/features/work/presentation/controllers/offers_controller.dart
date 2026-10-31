import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/work_repository.dart';
import '../../domain/offer_model.dart';
import 'requirements_controller.dart';

@immutable
class OffersState {
  final bool isLoading;
  final List<OfferItem> offers;
  final String searchQuery;
  final OfferStatus? statusFilter;
  final bool isContractPending;
  final String? contractNotice;
  final String? errorMessage;

  const OffersState({
    this.isLoading = false,
    this.offers = const [],
    this.searchQuery = '',
    this.statusFilter,
    this.isContractPending = false,
    this.contractNotice,
    this.errorMessage,
  });

  /// Filtered list of offers according to active search query and status filter.
  List<OfferItem> get filteredOffers {
    return offers.where((offer) {
      if (statusFilter != null && offer.status != statusFilter) {
        return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matchesRef = offer.ref.toLowerCase().contains(q);
        final matchesLot = offer.lotNumber.toLowerCase().contains(q);
        final matchesCommodity = offer.commodityName.toLowerCase().contains(q);
        final matchesSeller = offer.sellerCompanyName.toLowerCase().contains(q);
        final matchesMandi = offer.districtName.toLowerCase().contains(q);
        if (!matchesRef && !matchesLot && !matchesCommodity && !matchesSeller && !matchesMandi) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  int get totalCount => offers.length;
  int get activeCount => offers.where((o) => o.status == OfferStatus.open).length;
  int get partiallyAvailableCount =>
      offers.where((o) => o.status == OfferStatus.partiallyAvailable).length;
  int get expiredCount => offers.where((o) => o.status == OfferStatus.expired).length;

  OffersState copyWith({
    bool? isLoading,
    List<OfferItem>? offers,
    String? searchQuery,
    OfferStatus? Function()? statusFilter,
    bool? isContractPending,
    String? Function()? contractNotice,
    String? Function()? errorMessage,
  }) {
    return OffersState(
      isLoading: isLoading ?? this.isLoading,
      offers: offers ?? this.offers,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      isContractPending: isContractPending ?? this.isContractPending,
      contractNotice: contractNotice != null ? contractNotice() : this.contractNotice,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class OffersNotifier extends Notifier<OffersState> {
  WorkRepository get _repository => ref.read(workRepositoryProvider);

  @override
  OffersState build() {
    Future.microtask(() => loadOffers());
    return const OffersState(isLoading: true);
  }

  Future<void> loadOffers() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);

    final result = await _repository.getOffers();

    switch (result) {
      case WorkSuccess(:final data):
        state = state.copyWith(
          isLoading: false,
          offers: data,
          isContractPending: false,
          contractNotice: () => null,
          errorMessage: () => null,
        );
      case WorkContractPending(:final contractNotice):
        state = state.copyWith(
          isLoading: false,
          isContractPending: true,
          contractNotice: () => contractNotice,
          errorMessage: () => null,
        );
      case WorkError(:final message):
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => message,
        );
      case WorkUnauthorized(:final message):
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => message,
        );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(OfferStatus? filter) {
    state = state.copyWith(statusFilter: () => filter);
  }

  /// Why the last create failed, for the form to show.
  String? lastCreateError;

  Future<bool> createOffer(CreateOfferDto dto) async {
    lastCreateError = null;
    final res = await _repository.createOffer(dto);
    if (res is WorkSuccess) {
      // The record is saved; a slow list refresh must not hold the form open.
      unawaited(loadOffers());
      return true;
    }
    lastCreateError = switch (res) {
      WorkError(:final message) => message,
      WorkUnauthorized(:final message) => message,
      _ => null,
    };
    return false;
  }
}

final offersProvider =
    NotifierProvider<OffersNotifier, OffersState>(OffersNotifier.new);
