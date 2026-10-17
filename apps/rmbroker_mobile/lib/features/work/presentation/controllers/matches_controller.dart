import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/work_repository.dart';
import '../../domain/match_model.dart';
import '../../domain/offer_model.dart';
import '../../domain/requirement_model.dart';

@immutable
class MatchesState {
  final RequirementItem? selectedRequirement;
  final List<SupplyMatchItem> allMatches;
  final MatchClassification? scoreFilter;
  final bool isLoading;
  final String? notice;

  const MatchesState({
    this.selectedRequirement,
    this.allMatches = const [],
    this.scoreFilter,
    this.isLoading = false,
    this.notice,
  });

  /// Filtered list of matches based on score filter.
  List<SupplyMatchItem> get filteredMatches {
    if (scoreFilter == null) return allMatches;
    return allMatches.where((m) => m.classification == scoreFilter).toList();
  }

  int get strongMatchCount =>
      allMatches.where((m) => m.classification == MatchClassification.strongMatch).length;
  int get goodMatchCount =>
      allMatches.where((m) => m.classification == MatchClassification.goodMatch).length;
  int get partialMatchCount =>
      allMatches.where((m) => m.classification == MatchClassification.partialMatch).length;

  MatchesState copyWith({
    RequirementItem? Function()? selectedRequirement,
    List<SupplyMatchItem>? allMatches,
    MatchClassification? Function()? scoreFilter,
    bool? isLoading,
    String? Function()? notice,
  }) {
    return MatchesState(
      selectedRequirement: selectedRequirement != null
          ? selectedRequirement()
          : this.selectedRequirement,
      allMatches: allMatches ?? this.allMatches,
      scoreFilter: scoreFilter != null ? scoreFilter() : this.scoreFilter,
      isLoading: isLoading ?? this.isLoading,
      notice: notice != null ? notice() : this.notice,
    );
  }
}

class MatchesNotifier extends Notifier<MatchesState> {
  late final WorkRepository _repository;

  @override
  MatchesState build() {
    _repository = WorkRepository();
    return const MatchesState();
  }

  /// Sets the active target requirement and computes deterministic match scores.
  void selectRequirement(RequirementItem? req, List<OfferItem> availableOffers) {
    if (req == null) {
      state = state.copyWith(
        selectedRequirement: () => null,
        allMatches: [],
        notice: () => null,
      );
      return;
    }

    if (!req.canBeMatched) {
      state = state.copyWith(
        selectedRequirement: () => req,
        allMatches: [],
        notice: () =>
            'Requirement ${req.ref} is in "${req.status.displayLabel}" status and is not eligible for active matching.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, selectedRequirement: () => req);

    final computed = _repository.computeMatches(
      requirement: req,
      availableOffers: availableOffers,
    );

    state = state.copyWith(
      isLoading: false,
      allMatches: computed,
      notice: () => computed.isEmpty
          ? 'No active seller supply lots match the commodity and grade specifications for ${req.ref}.'
          : null,
    );
  }

  void setScoreFilter(MatchClassification? filter) {
    state = state.copyWith(scoreFilter: () => filter);
  }
}

final matchesProvider =
    NotifierProvider<MatchesNotifier, MatchesState>(MatchesNotifier.new);
