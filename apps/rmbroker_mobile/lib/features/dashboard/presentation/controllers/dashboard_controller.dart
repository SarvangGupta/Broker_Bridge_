import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rmbroker_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:rmbroker_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:rmbroker_mobile/features/dashboard/domain/dashboard_state.dart';

/// Provider for DashboardRepository
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

/// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Provider for DashboardController
final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );

/// Controller managing dashboard operational lifecycle and state.
class DashboardController extends Notifier<DashboardState> {
  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  DashboardState build() {
    // Schedule asynchronous initial load after build frame
    Future.microtask(() => loadDashboard());
    return DashboardState.initial();
  }

  /// Initial load or refresh of dashboard data.
  Future<void> loadDashboard({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.toLoading();
    }

    // 1. Resolve authenticated broker identity
    final BrokerUser? broker = await _repository.getAuthenticatedBroker();

    // 2. Fetch authoritative dashboard metrics
    final DashboardDataResult result = await _repository.fetchDashboardData();

    switch (result) {
      case DashboardDataSuccess(:final metrics, :final recentActivities):
        final isEmpty =
            (metrics.activeDealsCount ?? 0) == 0 &&
            (metrics.openRequirementsCount ?? 0) == 0 &&
            (metrics.availableOffersCount ?? 0) == 0;

        state = state.copyWith(
          status: isEmpty ? DashboardStatus.empty : DashboardStatus.loaded,
          metrics: metrics,
          kpiCards: metrics.toKpiCards(),
          quickActions: BrokerQuickAction.defaultActions(),
          recentActivities: recentActivities,
          broker: broker,
          errorMessage: null,
          contractNotice: metrics.dataSourceNotice,
          lastRefreshed: DateTime.now(),
        );

      case DashboardDataUnavailable(:final contractNotice):
        final unavailableMetrics = BrokerDashboardMetrics.unavailable(
          reason: contractNotice,
        );
        state = state.copyWith(
          status: DashboardStatus.unavailable,
          metrics: unavailableMetrics,
          kpiCards: unavailableMetrics.toKpiCards(),
          quickActions: BrokerQuickAction.defaultActions(),
          broker: broker,
          errorMessage: null,
          contractNotice: contractNotice,
          lastRefreshed: DateTime.now(),
        );

      case DashboardDataError(:final message):
        state = state.copyWith(
          status: DashboardStatus.error,
          errorMessage: message,
          broker: broker,
          lastRefreshed: DateTime.now(),
        );

      case DashboardDataUnauthorized(:final message):
        await _authRepository.signOut();
        state = state.copyWith(
          status: DashboardStatus.error,
          errorMessage: message,
          broker: null,
        );
    }
  }

  /// Retry fetching dashboard data after a failure.
  Future<void> retry() => loadDashboard(isRefresh: false);

  /// User pull-to-refresh.
  Future<void> refresh() => loadDashboard(isRefresh: true);

  /// Sign out current broker session.
  Future<void> signOut() async {
    await _authRepository.signOut();
  }
}
