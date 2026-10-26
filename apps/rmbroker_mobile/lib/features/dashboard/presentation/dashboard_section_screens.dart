import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../domain/dashboard_state.dart';
import 'controllers/dashboard_controller.dart';
import 'widgets/dashboard_kpi_grid.dart';
import 'widgets/quick_actions_section.dart';

/// Home > Summary: the full desk metrics grid (moved off the Home screen).
class DashboardSummaryScreen extends ConsumerWidget {
  const DashboardSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    return _DashboardSectionScaffold(
      title: 'Summary',
      state: state,
      onRefresh: controller.refresh,
      onRetry: controller.retry,
      child: DashboardKpiGrid(cards: state.kpiCards, onRefresh: () => controller.refresh()),
    );
  }
}

/// Home > Actions: all quick actions (moved off the Home screen).
class DashboardActionsScreen extends ConsumerWidget {
  const DashboardActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    return _DashboardSectionScaffold(
      title: 'Actions',
      state: state,
      onRefresh: controller.refresh,
      onRetry: controller.retry,
      // Actions are static desk shortcuts: shown even when metrics failed.
      showChildOnError: true,
      child: QuickActionsSection(actions: state.quickActions),
    );
  }
}

class _DashboardSectionScaffold extends StatelessWidget {
  final String title;
  final DashboardState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final bool showChildOnError;
  final Widget child;

  const _DashboardSectionScaffold({
    required this.title,
    required this.state,
    required this.onRefresh,
    required this.onRetry,
    this.showChildOnError = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final loading = state.status == DashboardStatus.loading && state.metrics == null;
    final error = state.status == DashboardStatus.error;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: AppLoadingIndicator(message: 'Synchronizing Broker Desk Metrics...')),
              )
            else if (error) ...[
              Column(
                children: [
                  const Icon(LucideIcons.alertCircle, size: 32, color: AppColors.error),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage ?? 'Unable to synchronize desk data.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 12),
                  AppButton(label: 'Retry Connection', onPressed: onRetry),
                ],
              ),
              if (showChildOnError) ...[const SizedBox(height: 20), child],
            ] else
              child,
          ],
        ),
      ),
    );
  }
}
