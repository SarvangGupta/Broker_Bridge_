import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/deal_repository.dart';
import '../../domain/allocation_model.dart';
import 'deals_controller.dart';

class AllocationsState {
  final bool isLoading;
  final String? errorMessage;
  final String? contractNotice;
  final List<AllocationItem> allocations;

  const AllocationsState({
    this.isLoading = false,
    this.errorMessage,
    this.contractNotice,
    this.allocations = const [],
  });

  AllocationsState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? contractNotice,
    List<AllocationItem>? allocations,
  }) {
    return AllocationsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      contractNotice: contractNotice,
      allocations: allocations ?? this.allocations,
    );
  }

  double get totalAllocatedQuantity =>
      allocations.fold(0.0, (sum, a) => sum + a.allocatedQuantity);
}

class AllocationsNotifier extends Notifier<AllocationsState> {
  final String requirementId;

  AllocationsNotifier(this.requirementId);

  DealRepository get _repository => ref.read(dealRepositoryProvider);

  @override
  AllocationsState build() {
    if (requirementId.isNotEmpty) {
      Future.microtask(() => loadAllocations());
    }
    return const AllocationsState(isLoading: true);
  }

  Future<void> loadAllocations() async {
    if (requirementId.isEmpty) return;
    state = state.copyWith(isLoading: true, errorMessage: null, contractNotice: null);

    final result = await _repository.getAllocationsForRequirement(requirementId);

    switch (result) {
      case DealSuccess<List<AllocationItem>>(:final data):
        state = state.copyWith(isLoading: false, allocations: data);
      case DealContractPending<List<AllocationItem>>(:final contractNotice):
        state = state.copyWith(isLoading: false, contractNotice: contractNotice);
      case DealError<List<AllocationItem>>(:final message):
        state = state.copyWith(isLoading: false, errorMessage: message);
      case DealUnauthorized<List<AllocationItem>>(:final message):
        state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  Future<AllocationItem?> proposeAllocation(CreateAllocationDto dto) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _repository.proposeAllocation(dto);

    switch (result) {
      case DealSuccess<AllocationItem>(:final data):
        state = state.copyWith(
          isLoading: false,
          allocations: [data, ...state.allocations],
        );
        return data;
      case DealError<AllocationItem>(:final message):
        state = state.copyWith(isLoading: false, errorMessage: message);
        return null;
      case DealContractPending<AllocationItem>(:final contractNotice):
        state = state.copyWith(isLoading: false, contractNotice: contractNotice);
        return null;
      case DealUnauthorized<AllocationItem>(:final message):
        state = state.copyWith(isLoading: false, errorMessage: message);
        return null;
    }
  }

  Future<bool> confirmAllocation(String allocationId) async {
    state = state.copyWith(isLoading: true);
    final result = await _repository.confirmAllocation(allocationId);

    if (result is DealSuccess<bool> && result.data) {
      await loadAllocations();
      return true;
    } else if (result is DealError<bool>) {
      state = state.copyWith(isLoading: false, errorMessage: result.message);
      return false;
    }
    state = state.copyWith(isLoading: false);
    return false;
  }
}

final allocationsProvider =
    NotifierProvider.family<AllocationsNotifier, AllocationsState, String>(
  (requirementId) => AllocationsNotifier(requirementId),
);
