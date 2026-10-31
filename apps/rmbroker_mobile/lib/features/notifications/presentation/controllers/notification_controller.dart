import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/notification_repository.dart';
import '../../domain/alert_kind.dart';
import '../../domain/notification_category.dart';
import '../../domain/notification_model.dart';

/// State of the Notification Center and Activity History.
class NotificationState {
  final List<BrokerNotification> allNotifications;
  final List<BrokerNotification> filteredNotifications;
  final NotificationCategory selectedCategory;
  final bool unreadOnly;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final int unreadCount;
  final Map<NotificationCategory, int> categoryCounts;

  /// Alerts chip filter (null = all kinds).
  final AlertKind? kindFilter;

  /// Notification count per [AlertKind].
  Map<AlertKind, int> get kindCounts {
    final counts = {for (final k in AlertKind.values) k: 0};
    for (final n in allNotifications) {
      final k = AlertKind.of(n);
      counts[k] = counts[k]! + 1;
    }
    return counts;
  }

  const NotificationState({
    this.allNotifications = const [],
    this.filteredNotifications = const [],
    this.selectedCategory = NotificationCategory.all,
    this.unreadOnly = false,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.unreadCount = 0,
    this.categoryCounts = const {},
    this.kindFilter,
  });

  factory NotificationState.initial() {
    return const NotificationState(
      isLoading: true,
      selectedCategory: NotificationCategory.all,
      unreadOnly: false,
    );
  }

  NotificationState copyWith({
    List<BrokerNotification>? allNotifications,
    List<BrokerNotification>? filteredNotifications,
    NotificationCategory? selectedCategory,
    bool? unreadOnly,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    int? unreadCount,
    Map<NotificationCategory, int>? categoryCounts,
    AlertKind? Function()? kindFilter,
  }) {
    return NotificationState(
      allNotifications: allNotifications ?? this.allNotifications,
      filteredNotifications: filteredNotifications ?? this.filteredNotifications,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      unreadCount: unreadCount ?? this.unreadCount,
      categoryCounts: categoryCounts ?? this.categoryCounts,
      kindFilter: kindFilter != null ? kindFilter() : this.kindFilter,
    );
  }
}

/// Global provider for NotificationRepository.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final repo = NotificationRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Riverpod Notifier managing notifications and desk activity history.
class NotificationController extends Notifier<NotificationState> {
  NotificationRepository get _repository => ref.read(notificationRepositoryProvider);

  @override
  NotificationState build() {
    Future.microtask(() => loadNotifications());
    return NotificationState.initial();
  }

  /// Loads all notifications from repository and recalculates counters.
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repository.resolveRelated(await _repository.fetchNotifications());
      final unread = items.where((n) => !n.isRead).length;

      final catCounts = <NotificationCategory, int>{};
      for (final cat in NotificationCategory.values) {
        if (cat == NotificationCategory.all) {
          catCounts[cat] = items.length;
        } else {
          catCounts[cat] = items.where((n) => n.category == cat).length;
        }
      }

      final filtered = _applyFilter(
        items,
        category: state.selectedCategory,
        unreadOnly: state.unreadOnly,
        searchQuery: state.searchQuery,
      );

      state = state.copyWith(
        allNotifications: items,
        filteredNotifications: filtered,
        unreadCount: unread,
        categoryCounts: catCounts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Alerts could not be loaded. Please check your connection and try again.',
      );
    }
  }

  /// Sets the active category filter.
  void selectCategory(NotificationCategory category) {
    if (state.selectedCategory == category) return;

    final filtered = _applyFilter(
      state.allNotifications,
      category: category,
      unreadOnly: state.unreadOnly,
      searchQuery: state.searchQuery,
    );

    state = state.copyWith(
      selectedCategory: category,
      filteredNotifications: filtered,
    );
  }

  /// Alerts chips are single-select: All, Unread, or one record kind.
  void selectAlertsFilter({AlertKind? kind, bool unreadOnly = false}) {
    state = state.copyWith(kindFilter: () => kind, unreadOnly: unreadOnly);
    state = state.copyWith(
      filteredNotifications: _applyFilter(
        state.allNotifications,
        category: state.selectedCategory,
        unreadOnly: unreadOnly,
        searchQuery: state.searchQuery,
      ),
    );
  }

  /// Toggles the "Unread only" filter.
  void toggleUnreadOnly() {
    final nextUnreadOnly = !state.unreadOnly;
    final filtered = _applyFilter(
      state.allNotifications,
      category: state.selectedCategory,
      unreadOnly: nextUnreadOnly,
      searchQuery: state.searchQuery,
    );

    state = state.copyWith(
      unreadOnly: nextUnreadOnly,
      filteredNotifications: filtered,
    );
  }

  /// Updates the search filter.
  void setSearchQuery(String query) {
    final filtered = _applyFilter(
      state.allNotifications,
      category: state.selectedCategory,
      unreadOnly: state.unreadOnly,
      searchQuery: query,
    );

    state = state.copyWith(
      searchQuery: query,
      filteredNotifications: filtered,
    );
  }

  /// Marks an individual notification as read.
  Future<void> markAsRead(String notificationId) async {
    final index = state.allNotifications.indexWhere((n) => n.id == notificationId);
    if (index < 0) return;

    final existing = state.allNotifications[index];
    if (existing.isRead) return; // already read

    // Optimistic update
    final updatedList = List<BrokerNotification>.from(state.allNotifications);
    final updatedItem = existing.copyWith(isRead: true, readAt: DateTime.now());
    updatedList[index] = updatedItem;

    final newUnreadCount = (state.unreadCount - 1).clamp(0, 999);

    final filtered = _applyFilter(
      updatedList,
      category: state.selectedCategory,
      unreadOnly: state.unreadOnly,
      searchQuery: state.searchQuery,
    );

    state = state.copyWith(
      allNotifications: updatedList,
      filteredNotifications: filtered,
      unreadCount: newUnreadCount,
    );

    try {
      await _repository.markAsRead(notificationId);
    } catch (_) {
      // Non-fatal, local state already reflects intended state
    }
  }

  /// Marks all unread notifications as read.
  Future<void> markAllAsRead() async {
    if (state.unreadCount == 0) return;

    final now = DateTime.now();
    final updatedList = state.allNotifications.map((n) {
      if (!n.isRead) {
        return n.copyWith(isRead: true, readAt: now);
      }
      return n;
    }).toList();

    final filtered = _applyFilter(
      updatedList,
      category: state.selectedCategory,
      unreadOnly: state.unreadOnly,
      searchQuery: state.searchQuery,
    );

    state = state.copyWith(
      allNotifications: updatedList,
      filteredNotifications: filtered,
      unreadCount: 0,
      successMessage: 'All notifications marked as read',
    );

    try {
      await _repository.markAllAsRead();
    } catch (_) {}
  }

  /// Refreshes notification feed from authoritative sources.
  Future<void> refresh() async {
    await loadNotifications();
  }

  List<BrokerNotification> _applyFilter(
    List<BrokerNotification> list, {
    required NotificationCategory category,
    required bool unreadOnly,
    required String searchQuery,
  }) {
    var result = List<BrokerNotification>.from(list);

    // 1. Category filter
    if (category != NotificationCategory.all) {
      result = result.where((n) => n.category == category).toList();
    }

    // 1b. Alerts chip (record kind)
    final kind = state.kindFilter;
    if (kind != null) {
      result = result.where((n) => AlertKind.of(n) == kind).toList();
    }

    // 2. Unread filter
    if (unreadOnly) {
      result = result.where((n) => !n.isRead).toList();
    }

    // 3. Search query filter (text plus the record metadata shown on the card)
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((n) {
        final commodity = n.commodityLabel ?? '';
        final party = n.counterpartyName ?? '';
        final place = n.resolvedLocation ?? '';
        return n.title.toLowerCase().contains(q) ||
            n.message.toLowerCase().contains(q) ||
            n.contextReason.toLowerCase().contains(q) ||
            (n.actionLabel?.toLowerCase().contains(q) ?? false) ||
            (n.detailLine?.toLowerCase().contains(q) ?? false) ||
            commodity.toLowerCase().contains(q) ||
            party.toLowerCase().contains(q) ||
            place.toLowerCase().contains(q);
      }).toList();
    }

    // Always sort newest-first
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}

/// Global NotifierProvider for NotificationController.
final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(
  NotificationController.new,
);

/// Provider exposing total unread notification count across the app.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationControllerProvider.select((s) => s.unreadCount));
});
