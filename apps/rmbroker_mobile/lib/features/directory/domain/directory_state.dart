import 'package:flutter/foundation.dart';
import 'directory_contact.dart';

/// Overall lifecycle status of the Directory screen.
enum DirectoryStatus {
  initial,
  loading,
  loaded,
  unavailable,
  error,
}

/// Immutable state container for the Counterparty Directory.
@immutable
class DirectoryState {
  final DirectoryStatus status;
  final List<DirectoryContact> allContacts;
  final DirectorySummaryStats stats;
  final String activeTab; // 'all' | 'buyer' | 'seller'
  final String searchQuery;
  final String statusFilter; // 'all' | 'active' | 'inactive'
  final String? contractNotice;
  final String? errorMessage;
  final bool isRefreshing;

  /// Pagination: [allContacts] holds the pages loaded so far for the current
  /// tab/status/search; [nextCursor] continues the list while [hasMore].
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;

  /// Set when loading a further page failed; the loaded pages stay visible.
  final String? loadMoreError;

  const DirectoryState({
    this.status = DirectoryStatus.initial,
    this.allContacts = const [],
    this.stats = const DirectorySummaryStats(),
    this.activeTab = 'all',
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.contractNotice,
    this.errorMessage,
    this.isRefreshing = false,
    this.hasMore = false,
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  /// Loaded contacts matching the active tab, status and search. The list is
  /// already fetched with these filters; filtering again keeps the view right
  /// while a reload for a just-changed filter is in flight.
  List<DirectoryContact> get filteredContacts {
    return allContacts
        .filter(
          (c) => c.matchesFilters(
            role: activeTab,
            status: statusFilter,
            search: searchQuery,
          ),
        )
        .toList();
  }

  static const Object _keep = Object();

  DirectoryState copyWith({
    DirectoryStatus? status,
    List<DirectoryContact>? allContacts,
    DirectorySummaryStats? stats,
    String? activeTab,
    String? searchQuery,
    String? statusFilter,
    String? contractNotice,
    String? errorMessage,
    bool? isRefreshing,
    bool? hasMore,
    Object? nextCursor = _keep,
    bool? isLoadingMore,
    Object? loadMoreError = _keep,
  }) {
    return DirectoryState(
      status: status ?? this.status,
      allContacts: allContacts ?? this.allContacts,
      stats: stats ?? this.stats,
      activeTab: activeTab ?? this.activeTab,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      contractNotice: contractNotice ?? this.contractNotice,
      errorMessage: errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: identical(nextCursor, _keep) ? this.nextCursor : nextCursor as String?,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: identical(loadMoreError, _keep) ? this.loadMoreError : loadMoreError as String?,
    );
  }
}

/// Helper extension on List to make filter syntax clean
extension ContactListFiltering on List<DirectoryContact> {
  Iterable<DirectoryContact> filter(bool Function(DirectoryContact) predicate) {
    return where(predicate);
  }
}

/// Lifecycle status for 360-degree contact details.
enum ContactDetailsStatus {
  initial,
  loading,
  loaded,
  error,
  togglingStatus,
}

/// Immutable state container for the Contact 360-Degree profile.
@immutable
class ContactDetailsState {
  final ContactDetailsStatus status;
  final ContactDetailsPayload? payload;
  final String? errorMessage;

  const ContactDetailsState({
    this.status = ContactDetailsStatus.initial,
    this.payload,
    this.errorMessage,
  });

  ContactDetailsState copyWith({
    ContactDetailsStatus? status,
    ContactDetailsPayload? payload,
    String? errorMessage,
  }) {
    return ContactDetailsState(
      status: status ?? this.status,
      payload: payload ?? this.payload,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
