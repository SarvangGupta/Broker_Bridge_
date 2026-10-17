import 'package:flutter/foundation.dart';
import 'search_result.dart';

/// Immutable state container for RMBroker global search workstation.
@immutable
class SearchState {
  final String query;
  final SearchEntityType activeFilter;
  final GlobalSearchResults results;
  final SearchCounts counts;
  final bool isLoading;
  final bool isDebouncing;
  final bool hasSearched;
  final String? errorMessage;
  final String? contractNotice;
  final bool isContractPending;
  final List<String> recentSearches;
  final int activeRequestSequence;

  const SearchState({
    this.query = '',
    this.activeFilter = SearchEntityType.all,
    this.results = const GlobalSearchResults(),
    this.counts = const SearchCounts(),
    this.isLoading = false,
    this.isDebouncing = false,
    this.hasSearched = false,
    this.errorMessage,
    this.contractNotice,
    this.isContractPending = false,
    this.recentSearches = const [],
    this.activeRequestSequence = 0,
  });

  factory SearchState.initial() => const SearchState();

  bool get isEmpty => query.trim().isEmpty;
  bool get isQueryTooShort => query.trim().isNotEmpty && query.trim().length < 2;
  bool get hasResults => results.totalCount > 0;
  bool get hasNoResults => hasSearched && !isLoading && !isDebouncing && results.totalCount == 0 && errorMessage == null;

  SearchState copyWith({
    String? query,
    SearchEntityType? activeFilter,
    GlobalSearchResults? results,
    SearchCounts? counts,
    bool? isLoading,
    bool? isDebouncing,
    bool? hasSearched,
    String? errorMessage,
    bool clearError = false,
    String? contractNotice,
    bool? isContractPending,
    List<String>? recentSearches,
    int? activeRequestSequence,
  }) {
    return SearchState(
      query: query ?? this.query,
      activeFilter: activeFilter ?? this.activeFilter,
      results: results ?? this.results,
      counts: counts ?? this.counts,
      isLoading: isLoading ?? this.isLoading,
      isDebouncing: isDebouncing ?? this.isDebouncing,
      hasSearched: hasSearched ?? this.hasSearched,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      contractNotice: contractNotice ?? this.contractNotice,
      isContractPending: isContractPending ?? this.isContractPending,
      recentSearches: recentSearches ?? this.recentSearches,
      activeRequestSequence:
          activeRequestSequence ?? this.activeRequestSequence,
    );
  }
}
