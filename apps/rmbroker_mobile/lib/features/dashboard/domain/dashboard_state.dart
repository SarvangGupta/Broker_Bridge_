import '../../authentication/domain/broker_user.dart';
import 'dashboard_models.dart';

/// Lifecycle statuses for the dashboard screen.
enum DashboardStatus {
  initial,
  loading,
  loaded,
  empty,
  error,
  unavailable,
}

/// Immutable state container for the RMBroker dashboard.
class DashboardState {
  final DashboardStatus status;
  final BrokerDashboardMetrics? metrics;
  final List<BrokerKpiCard> kpiCards;
  final List<BrokerQuickAction> quickActions;
  final List<BrokerActivityItem> recentActivities;
  final String? errorMessage;
  final String? contractNotice;
  final BrokerUser? broker;
  final DateTime? lastRefreshed;

  const DashboardState({
    required this.status,
    this.metrics,
    this.kpiCards = const [],
    this.quickActions = const [],
    this.recentActivities = const [],
    this.errorMessage,
    this.contractNotice,
    this.broker,
    this.lastRefreshed,
  });

  /// Initial factory state.
  factory DashboardState.initial() {
    return DashboardState(
      status: DashboardStatus.initial,
      kpiCards: BrokerDashboardMetrics.unavailable().toKpiCards(),
      quickActions: BrokerQuickAction.defaultActions(),
    );
  }

  /// Create a loading copy while preserving existing cards.
  DashboardState toLoading() {
    return copyWith(status: DashboardStatus.loading);
  }

  DashboardState copyWith({
    DashboardStatus? status,
    BrokerDashboardMetrics? metrics,
    List<BrokerKpiCard>? kpiCards,
    List<BrokerQuickAction>? quickActions,
    List<BrokerActivityItem>? recentActivities,
    String? errorMessage,
    String? contractNotice,
    BrokerUser? broker,
    DateTime? lastRefreshed,
  }) {
    return DashboardState(
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      kpiCards: kpiCards ?? this.kpiCards,
      quickActions: quickActions ?? this.quickActions,
      recentActivities: recentActivities ?? this.recentActivities,
      errorMessage: errorMessage ?? this.errorMessage,
      contractNotice: contractNotice ?? this.contractNotice,
      broker: broker ?? this.broker,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }
}
