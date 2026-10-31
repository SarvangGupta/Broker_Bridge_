import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/work_repository.dart';
import '../../domain/requirement_model.dart';

@immutable
class RequirementsState {
  final bool isLoading;
  final List<RequirementItem> requirements;
  final String searchQuery;
  final RequirementStatus? statusFilter;
  final bool isContractPending;
  final String? contractNotice;
  final String? errorMessage;

  const RequirementsState({
    this.isLoading = false,
    this.requirements = const [],
    this.searchQuery = '',
    this.statusFilter,
    this.isContractPending = false,
    this.contractNotice,
    this.errorMessage,
  });

  /// Filtered list of requirements according to active search query and status filter.
  List<RequirementItem> get filteredRequirements {
    return requirements.where((req) {
      if (statusFilter != null && req.status != statusFilter) {
        return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matchesRef = req.ref.toLowerCase().contains(q);
        final matchesCommodity = req.commodityName.toLowerCase().contains(q);
        final matchesBuyer = req.buyerCompanyName.toLowerCase().contains(q);
        final matchesTerms = req.deliveryTerms.toLowerCase().contains(q);
        if (!matchesRef && !matchesCommodity && !matchesBuyer && !matchesTerms) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  int get totalCount => requirements.length;
  int get openCount => requirements.where((r) => r.status == RequirementStatus.open).length;
  int get matchingCount => requirements.where((r) => r.status == RequirementStatus.matching).length;
  int get partiallyAllocatedCount =>
      requirements.where((r) => r.status == RequirementStatus.partiallyAllocated).length;
  int get expiredCount => requirements.where((r) => r.status == RequirementStatus.expired).length;

  RequirementsState copyWith({
    bool? isLoading,
    List<RequirementItem>? requirements,
    String? searchQuery,
    RequirementStatus? Function()? statusFilter,
    bool? isContractPending,
    String? Function()? contractNotice,
    String? Function()? errorMessage,
  }) {
    return RequirementsState(
      isLoading: isLoading ?? this.isLoading,
      requirements: requirements ?? this.requirements,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      isContractPending: isContractPending ?? this.isContractPending,
      contractNotice: contractNotice != null ? contractNotice() : this.contractNotice,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

final workRepositoryProvider = Provider<WorkRepository>((ref) {
  return WorkRepository();
});

class RequirementsNotifier extends Notifier<RequirementsState> {
  WorkRepository get _repository => ref.read(workRepositoryProvider);

  @override
  RequirementsState build() {
    // Schedule asynchronous data load on init
    Future.microtask(() => loadRequirements());
    return const RequirementsState(isLoading: true);
  }

  Future<void> loadRequirements() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);

    final result = await _repository.getRequirements();

    switch (result) {
      case WorkSuccess(:final data):
        state = state.copyWith(
          isLoading: false,
          requirements: data,
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

  void setStatusFilter(RequirementStatus? filter) {
    state = state.copyWith(statusFilter: () => filter);
  }

  /// Why the last create failed, for the form to show.
  String? lastCreateError;

  Future<bool> createRequirement(CreateRequirementDto dto) async {
    lastCreateError = null;
    final res = await _repository.createRequirement(dto);
    if (res is WorkSuccess) {
      // The record is saved; a slow list refresh must not hold the form open.
      unawaited(loadRequirements());
      return true;
    }
    lastCreateError = switch (res) {
      WorkError(:final message) => message,
      WorkUnauthorized(:final message) => message,
      _ => null,
    };
    return false;
  }

  Future<bool> cancelRequirement(String id, String reason) async {
    final res = await _repository.cancelRequirement(id, reason);
    if (res is WorkSuccess) {
      await loadRequirements();
      return true;
    }
    return false;
  }
}

final requirementsProvider =
    NotifierProvider<RequirementsNotifier, RequirementsState>(RequirementsNotifier.new);
