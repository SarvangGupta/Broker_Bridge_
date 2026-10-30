import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/directory_repository.dart';
import '../../domain/directory_contact.dart';
import '../../domain/directory_state.dart';

/// Provider for DirectoryRepository.
final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  return DirectoryRepository();
});

/// Controller managing counterparty directory state, filtering, search, and soft archival.
class DirectoryController extends Notifier<DirectoryState> {
  DirectoryRepository get _repository => ref.read(directoryRepositoryProvider);

  static const Duration searchDebounce = Duration(milliseconds: 350);

  /// Incremented by every first-page load; a response for an older request
  /// (filters changed meanwhile) is dropped instead of mixing two lists.
  int _generation = 0;
  Timer? _searchTimer;

  @override
  DirectoryState build() {
    ref.onDispose(() => _searchTimer?.cancel());
    // Schedule initial load
    Future.microtask(() => loadContacts());
    return const DirectoryState(status: DirectoryStatus.loading);
  }

  /// Load the first page for the current tab / status / search.
  Future<void> loadContacts({bool isRefresh = false}) async {
    final generation = ++_generation;
    if (isRefresh) {
      state = state.copyWith(isRefreshing: true);
    } else {
      state = state.copyWith(status: DirectoryStatus.loading);
    }

    final result = await _repository.getContacts(
      role: state.activeTab,
      status: state.statusFilter,
      search: state.searchQuery,
      limit: DirectoryRepository.directoryPageSize,
    );
    // The directory may have been closed while loading (e.g. refresh after
    // saving a contact from the form); never write state after disposal.
    if (!ref.mounted || generation != _generation) return;

    switch (result) {
      case DirectorySuccess<DirectoryListPayload>(:final data):
        state = state.copyWith(
          status: DirectoryStatus.loaded,
          allContacts: _dedupe(data.contacts),
          stats: data.stats,
          isRefreshing: false,
          errorMessage: null,
          contractNotice: null,
          hasMore: data.hasMore,
          nextCursor: data.nextCursor,
          isLoadingMore: false,
          loadMoreError: null,
        );

      case DirectoryUnavailable<DirectoryListPayload>(:final contractNotice):
        state = state.copyWith(
          status: DirectoryStatus.unavailable,
          allContacts: const [],
          stats: const DirectorySummaryStats(),
          isRefreshing: false,
          contractNotice: contractNotice,
          hasMore: false,
          nextCursor: null,
          isLoadingMore: false,
        );

      case DirectoryError<DirectoryListPayload>(:final message):
        state = state.copyWith(
          status: DirectoryStatus.error,
          isRefreshing: false,
          errorMessage: message,
          isLoadingMore: false,
        );

      case DirectoryUnauthorized<DirectoryListPayload>(:final message):
        state = state.copyWith(
          status: DirectoryStatus.error,
          isRefreshing: false,
          errorMessage: message,
          isLoadingMore: false,
        );
    }
  }

  /// Append the next page. No-op while a page is loading or at the end.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (!state.hasMore || cursor == null || state.isLoadingMore) return;
    if (state.status != DirectoryStatus.loaded) return;

    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, loadMoreError: null);

    final result = await _repository.getContacts(
      role: state.activeTab,
      status: state.statusFilter,
      search: state.searchQuery,
      limit: DirectoryRepository.directoryPageSize,
      cursor: cursor,
    );
    if (!ref.mounted || generation != _generation) return;

    switch (result) {
      case DirectorySuccess<DirectoryListPayload>(:final data):
        state = state.copyWith(
          allContacts: _dedupe([...state.allContacts, ...data.contacts]),
          hasMore: data.hasMore,
          nextCursor: data.nextCursor,
          isLoadingMore: false,
        );
      case DirectoryUnauthorized<DirectoryListPayload>(:final message):
        state = state.copyWith(isLoadingMore: false, loadMoreError: message);
      case DirectoryError<DirectoryListPayload>(:final message):
        state = state.copyWith(isLoadingMore: false, loadMoreError: message);
      case DirectoryUnavailable<DirectoryListPayload>(:final contractNotice):
        state = state.copyWith(isLoadingMore: false, loadMoreError: contractNotice);
    }
  }

  /// Keeps the first occurrence of each contact id (pages never overlap, but
  /// a contact re-added locally by [upsertContact] must not show twice).
  static List<DirectoryContact> _dedupe(List<DirectoryContact> contacts) {
    final seen = <String>{};
    return [
      for (final c in contacts)
        if (seen.add(c.id)) c,
    ];
  }

  /// Change active tab ('all', 'buyer', 'seller').
  void setActiveTab(String tab) {
    if (state.activeTab == tab) return;
    state = state.copyWith(activeTab: tab);
    _reloadForFilters();
  }

  /// Update live search query; the server-side reload is debounced.
  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, _reloadForFilters);
  }

  /// Clear active search.
  void clearSearch() {
    _searchTimer?.cancel();
    if (state.searchQuery.isEmpty) return;
    state = state.copyWith(searchQuery: '');
    _reloadForFilters();
  }

  /// Change status filter ('all', 'active', 'inactive').
  void setStatusFilter(String filter) {
    if (state.statusFilter == filter) return;
    state = state.copyWith(statusFilter: filter);
    _reloadForFilters();
  }

  /// Filters are applied by the query, so a changed filter needs a fresh
  /// first page (loaded pages only cover the previous filter).
  void _reloadForFilters() {
    if (!ref.mounted) return;
    if (state.status == DirectoryStatus.unavailable) return;
    loadContacts(isRefresh: state.status == DirectoryStatus.loaded);
  }

  /// Last error from a contact action (removal, status toggle, link, restore).
  String? lastActionError;

  /// Safely remove a contact from the broker's directory (soft removal) with full result feedback.
  /// Preserves shared master records, GST details, bank details, and existing deals/transactions.
  Future<DirectoryDataResult<bool>> removeContactDetailed(String contactId) async {
    lastActionError = null;
    final result = await _repository.removeContact(contactId);
    if (!ref.mounted) return result;

    if (result is DirectorySuccess<bool>) {
      // Remove from local state immediately
      DirectoryContact? removed;
      final updatedList = state.allContacts.where((c) {
        if (c.id == contactId) {
          removed = c;
          return false;
        }
        return true;
      }).toList();

      state = state.copyWith(
        allContacts: updatedList,
        stats: _statsAfterToggle(state.stats, removed, false),
      );
      // Refresh directory from authoritative source
      await loadContacts(isRefresh: true);
      return result;
    } else if (result is DirectoryError) {
      lastActionError = (result as DirectoryError).message;
    } else if (result is DirectoryUnauthorized) {
      lastActionError = 'Your broker session has expired. Please sign in again.';
    } else if (result is DirectoryUnavailable) {
      lastActionError = (result as DirectoryUnavailable).contractNotice;
    }

    return result;
  }

  /// Safely remove a contact from the broker's directory (soft removal).
  /// Preserves shared master records, GST details, bank details, and existing deals/transactions.
  Future<bool> removeContact(String contactId) async {
    final result = await removeContactDetailed(contactId);
    return result is DirectorySuccess<bool>;
  }

  /// Restore a previously removed counterparty (Case B).
  Future<bool> restoreContact(String contactId) async {
    final result = await _repository.restoreContact(contactId);
    if (!ref.mounted) return result is DirectorySuccess<String>;

    if (result is DirectorySuccess<String>) {
      loadContacts(isRefresh: true);
      return true;
    }

    return false;
  }

  /// Link an existing shared counterparty to this broker desk (Case C).
  Future<bool> linkSharedCounterparty({
    required String companyId,
    String? userId,
    String? notes,
  }) async {
    final result = await _repository.linkSharedCounterparty(
      companyId: companyId,
      userId: userId,
      notes: notes,
    );
    if (!ref.mounted) return result is DirectorySuccess<String>;

    if (result is DirectorySuccess<String>) {
      loadContacts(isRefresh: true);
      return true;
    }

    return false;
  }

  /// Toggle contact status (Active / Inactive soft archival) and update locally.
  Future<bool> toggleContactStatus(String contactId) async {
    final result = await _repository.toggleContactStatus(contactId);
    if (!ref.mounted) return result is DirectorySuccess<bool>;

    if (result is DirectorySuccess<bool>) {
      final newStatus = result.data;
      DirectoryContact? before;
      final updatedList = state.allContacts.map((c) {
        if (c.id == contactId) {
          before = c;
          return c.copyWith(status: newStatus);
        }
        return c;
      }).toList();

      state = state.copyWith(
        allContacts: updatedList,
        stats: _statsAfterToggle(state.stats, before, newStatus),
      );
      return true;
    }

    return false;
  }

  /// Stats cover every contact, not just loaded pages, so adjust the active
  /// buyer/seller count by the one contact that changed.
  static DirectorySummaryStats _statsAfterToggle(
    DirectorySummaryStats stats,
    DirectoryContact? before,
    bool newStatus,
  ) {
    if (before == null || before.status == newStatus) return stats;
    final delta = newStatus ? 1 : -1;
    final isSeller = before.role == ContactRole.seller;
    return DirectorySummaryStats(
      totalContacts: stats.totalContacts,
      buyersCount: (stats.buyersCount + (isSeller ? 0 : delta)).clamp(0, stats.totalContacts),
      sellersCount: (stats.sellersCount + (isSeller ? delta : 0)).clamp(0, stats.totalContacts),
      activeMandatesCount: stats.activeMandatesCount,
    );
  }

  /// Insert or update contact in local state after successful form submission.
  void upsertContact(DirectoryContact contact) {
    final existingIndex = state.allContacts.indexWhere((c) => c.id == contact.id);
    List<DirectoryContact> updatedList;

    if (existingIndex >= 0) {
      updatedList = List.of(state.allContacts)..[existingIndex] = contact;
    } else {
      updatedList = [contact, ...state.allContacts];
    }

    state = state.copyWith(
      status: DirectoryStatus.loaded,
      allContacts: updatedList,
      stats: DirectorySummaryStats.fromContacts(updatedList),
    );
  }
}

/// Provider for DirectoryController.
final directoryControllerProvider =
    NotifierProvider<DirectoryController, DirectoryState>(() {
  return DirectoryController();
});
