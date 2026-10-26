import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../domain/dashboard_state.dart';
import 'controllers/dashboard_controller.dart';
import 'widgets/broker_welcome_banner.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_kpi_grid.dart';
import 'widgets/home_add_sheet.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/recent_activity_section.dart';

/// Operational command center overview for the broker desk.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: DashboardHeader(
        broker: state.broker,
        onSignOut: () => controller.signOut(),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome & Broker Profile Banner
              BrokerWelcomeBanner(
                broker: state.broker,
                contractNotice: state.contractNotice,
                isAuthoritative: state.metrics?.isAuthoritative ?? false,
                lastRefreshed: state.lastRefreshed,
              ),
              const SizedBox(height: 12),

              // Dynamic Body based on DashboardState
              if (state.status == DashboardStatus.loading &&
                  state.metrics == null) ...[
                const SizedBox(height: 40),
                const Center(
                  child: AppLoadingIndicator(
                    message: 'Synchronizing Broker Desk Metrics...',
                  ),
                ),
                const SizedBox(height: 40),
              ] else if (state.status == DashboardStatus.error) ...[
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 36,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to Synchronize Desk Data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.errorMessage ??
                            'Network connection or server error occurred while retrieving authoritative metrics.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppButton(
                        label: 'Retry Connection',
                        icon: const Icon(
                          LucideIcons.refreshCw,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: () => controller.retry(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Render fallback quick actions even in error state
                QuickActionsSection(actions: state.quickActions),
              ] else ...[
                // Summary KPI Grid
                DashboardKpiGrid(
                  cards: state.kpiCards,
                  onRefresh: () => controller.refresh(),
                ),
                const SizedBox(height: 18),

                // Quick Actions
                QuickActionsSection(actions: state.quickActions),
                const SizedBox(height: 20),

                // Recent Activities
                RecentActivitySection(
                  activities: state.recentActivities,
                  isAuthoritative: state.metrics?.isAuthoritative ?? false,
                ),
              ],

              const SizedBox(height: 72),
            ],
          ),
        ),
      ),
      // "+" opens Add Requirement / Add Offer (Broker Desk moved to the header).
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('home_add_fab'),
        // Own hero tag: tab branches stay alive, and the default tag would
        // clash with other tabs' FABs when a full-screen route is pushed.
        heroTag: 'home_add_fab',
        onPressed: () => HomeAddSheet.show(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Add Requirement or Offer',
        child: const Icon(LucideIcons.plus, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
