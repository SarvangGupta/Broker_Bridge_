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
  });

  /// Real-time client-filtered contacts based on active tab, status, and search query.
  List<DirectoryContact> get filteredContacts {
    return allContacts.filter((c) {
      // 1. Role tab filter
      if (activeTab == 'buyer' && c.role != ContactRole.buyer) return false;
      if (activeTab == 'seller' && c.role != ContactRole.seller) return false;

      // 2. Status filter
      if (statusFilter == 'active' && !c.status) return false;
      if (statusFilter == 'inactive' && c.status) return false;

      // 3. Search query filter
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        final digits = q.replaceAll(RegExp(r'\D'), '');

        final matchesName = c.name.toLowerCase().contains(q);
        final matchesComp = c.companyName.toLowerCase().contains(q);
        final matchesEmail = c.email?.toLowerCase().contains(q) ?? false;
        final matchesCity = c.city?.toLowerCase().contains(q) ?? false;
        final matchesState = c.state?.toLowerCase().contains(q) ?? false;
        final matchesPhone = digits.length >= 3 &&
            c.mobile.replaceAll(RegExp(r'\D'), '').contains(digits);

        return matchesName ||
            matchesComp ||
            matchesEmail ||
            matchesCity ||
            matchesState ||
            matchesPhone;
      }

      return true;
    }).toList();
  }

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
