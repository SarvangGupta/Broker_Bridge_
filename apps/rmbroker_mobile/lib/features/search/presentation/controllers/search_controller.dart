import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rmbroker_mobile/features/search/data/search_repository.dart';
import 'package:rmbroker_mobile/features/search/domain/search_result.dart';
import 'package:rmbroker_mobile/features/search/domain/search_state.dart';

/// Provider for Global Search Controller.
final searchControllerProvider =
    NotifierProvider<BrokerSearchController, SearchState>(() {
      return BrokerSearchController();
    });

/// Riverpod 3 Controller managing global search state, debouncing, and race-condition prevention.
class BrokerSearchController extends Notifier<SearchState> {
  Timer? _debounceTimer;
  int _sequenceCounter = 0;
  CancelToken? _activeCancelToken;

  @override
  SearchState build() {
    // Load recent searches on initialization
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _activeCancelToken?.cancel();
    });

    _loadRecentSearches();
    return SearchState.initial();
  }

  SearchRepository get _repository => ref.read(searchRepositoryProvider);

  /// Loads stored recent searches from secure storage.
  Future<void> _loadRecentSearches() async {
    try {
      final recent = await _repository.getRecentSearches();
      state = state.copyWith(recentSearches: recent);
    } catch (_) {}
  }

  /// Handles real-time query text modifications with debouncing.
  void onQueryChanged(String newQuery) {
    _debounceTimer?.cancel();

    final trimmed = newQuery.trim();

    if (trimmed.isEmpty) {
      _activeCancelToken?.cancel();
      state = state.copyWith(
        query: newQuery,
        results: GlobalSearchResults.empty(),
        counts: const SearchCounts(),
        isLoading: false,
        isDebouncing: false,
        hasSearched: false,
        clearError: true,
      );
      return;
    }

    if (trimmed.length < 2) {
      state = state.copyWith(
        query: newQuery,
        results: GlobalSearchResults.empty(),
        counts: const SearchCounts(),
        isLoading: false,
        isDebouncing: false,
        hasSearched: false,
        clearError: true,
      );
      return;
    }

    // Set debouncing indicator
    state = state.copyWith(query: newQuery, isDebouncing: true, clearError: true);

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      executeSearch(addToRecent: false);
    });
  }

  /// Sets the active entity filter tab (All, Contacts, Materials, Requirements, Offers, Deals).
  void setFilter(SearchEntityType filter) {
    if (state.activeFilter == filter) return;

    state = state.copyWith(activeFilter: filter);

    if (state.query.trim().length >= 2) {
      executeSearch(addToRecent: false);
    }
  }

  /// Executes global search query against repository.
  Future<void> executeSearch({bool addToRecent = true}) async {
    final queryToSearch = state.query.trim();
    if (queryToSearch.length < 2) return;

    _debounceTimer?.cancel();
    _activeCancelToken?.cancel();
    _activeCancelToken = CancelToken();

    final currentSeq = ++_sequenceCounter;

    state = state.copyWith(
      isLoading: true,
      isDebouncing: false,
      hasSearched: true,
      clearError: true,
      activeRequestSequence: currentSeq,
      isContractPending: false,
      contractNotice: null,
    );

    try {
      final results = await _repository.searchGlobal(
        query: queryToSearch,
        filterType: state.activeFilter,
        cancelToken: _activeCancelToken,
      );

      // Verify this response belongs to the latest in-flight request
      if (currentSeq != _sequenceCounter) return;

      final counts = SearchCounts.fromResults(results);

      List<String> updatedRecent = state.recentSearches;
      if (addToRecent) {
        updatedRecent = await _repository.addRecentSearch(queryToSearch);
      }

      state = state.copyWith(
        results: results,
        counts: counts,
        isLoading: false,
        recentSearches: updatedRecent,
        clearError: true,
      );
    } on SearchUnavailableException catch (unavail) {
      if (currentSeq != _sequenceCounter) return;
      state = state.copyWith(
        isLoading: false,
        isContractPending: true,
        contractNotice: unavail.message,
      );
    } on DioException catch (dioErr) {
      if (CancelToken.isCancel(dioErr)) {
        // Ignored as superseded by newer request
        return;
      }
      if (currentSeq != _sequenceCounter) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error connecting to search service. Please check connection.',
      );
    } catch (err) {
      if (currentSeq != _sequenceCounter) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to complete search. Please retry.',
      );
    }
  }

  /// Selects a recent search item and triggers an immediate search.
  void selectRecentSearch(String query) {
    state = state.copyWith(query: query);
    executeSearch(addToRecent: true);
  }

  /// Clears the search field and resets results.
  void clearQuery() {
    _debounceTimer?.cancel();
    _activeCancelToken?.cancel();
    state = state.copyWith(
      query: '',
      results: GlobalSearchResults.empty(),
      counts: const SearchCounts(),
      isLoading: false,
      isDebouncing: false,
      hasSearched: false,
      clearError: true,
      isContractPending: false,
      contractNotice: null,
    );
  }

  /// Removes an item from recent searches.
  Future<void> removeRecentSearch(String query) async {
    final updated = await _repository.removeRecentSearch(query);
    state = state.copyWith(recentSearches: updated);
  }

  /// Clears all recent searches.
  Future<void> clearRecentSearches() async {
    await _repository.clearRecentSearches();
    state = state.copyWith(recentSearches: const []);
  }
}
