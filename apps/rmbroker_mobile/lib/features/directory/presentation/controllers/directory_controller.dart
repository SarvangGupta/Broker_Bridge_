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

  @override
  DirectoryState build() {
    // Schedule initial load
    Future.microtask(() => loadContacts());
    return const DirectoryState(status: DirectoryStatus.loading);
  }

  /// Load directory contacts from authoritative backend.
  Future<void> loadContacts({bool isRefresh = false}) async {
    if (isRefresh) {
      state = state.copyWith(isRefreshing: true);
    } else {
      state = state.copyWith(status: DirectoryStatus.loading);
    }

    final result = await _repository.getContacts();

    switch (result) {
      case DirectorySuccess<DirectoryListPayload>(:final data):
        state = state.copyWith(
          status: DirectoryStatus.loaded,
          allContacts: data.contacts,
          stats: data.stats,
          isRefreshing: false,
          errorMessage: null,
          contractNotice: null,
        );

      case DirectoryUnavailable<DirectoryListPayload>(:final contractNotice):
        state = state.copyWith(
          status: DirectoryStatus.unavailable,
          allContacts: const [],
          stats: const DirectorySummaryStats(),
          isRefreshing: false,
          contractNotice: contractNotice,
        );

      case DirectoryError<DirectoryListPayload>(:final message):
        state = state.copyWith(
          status: DirectoryStatus.error,
          isRefreshing: false,
          errorMessage: message,
        );

      case DirectoryUnauthorized<DirectoryListPayload>(:final message):
        state = state.copyWith(
          status: DirectoryStatus.error,
          isRefreshing: false,
          errorMessage: message,
        );
    }
  }

  /// Change active tab ('all', 'buyer', 'seller').
  void setActiveTab(String tab) {
    if (state.activeTab == tab) return;
    state = state.copyWith(activeTab: tab);
  }

  /// Update live search query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear active search.
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  /// Change status filter ('all', 'active', 'inactive').
  void setStatusFilter(String filter) {
    if (state.statusFilter == filter) return;
    state = state.copyWith(statusFilter: filter);
  }

  /// Toggle contact status (Active / Inactive soft archival) and update locally.
  Future<bool> toggleContactStatus(String contactId) async {
    final result = await _repository.toggleContactStatus(contactId);

    if (result is DirectorySuccess<bool>) {
      final newStatus = result.data;
      final updatedList = state.allContacts.map((c) {
        if (c.id == contactId) {
          return c.copyWith(status: newStatus);
        }
        return c;
      }).toList();

      state = state.copyWith(
        allContacts: updatedList,
        stats: DirectorySummaryStats.fromContacts(updatedList),
      );
      return true;
    }

    return false;
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
