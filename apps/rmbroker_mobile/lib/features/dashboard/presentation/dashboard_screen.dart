import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../search/presentation/widgets/quick_communication_sheet.dart';
import '../domain/dashboard_state.dart';
import 'controllers/dashboard_controller.dart';
import 'widgets/broker_welcome_banner.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_kpi_grid.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/recent_activity_section.dart';

/// Operational command center overview for the broker desk.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showQuickDialSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppColors.surfaceLight,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Broker Communication Desk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Direct broker phone and WhatsApp coordination line with buyers and sellers.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.phoneForwarded, color: AppColors.primary),
                  ),
                  title: const Text(
                    'Speed Dial Counterparties',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Quick Call or WhatsApp authorized contacts',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    QuickCommunicationSheet.show(context);
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.users, color: AppColors.primary),
                  ),
                  title: const Text(
                    'Open Counterparty Directory',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Call or WhatsApp verified buyers & sellers',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.go('/directory');
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.messageSquare,
                      color: AppColors.success,
                    ),
                  ),
                  title: const Text(
                    'Jaipur Mandi Support Line',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Technical desk arbitration support',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Support Desk: +91 141 274 0000 (Jaipur Mandi Exchange)',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

              // Global Search Quick Entry Bar
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/search'),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(LucideIcons.search, size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search buyers, sellers, commodities, deals...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textDisabled,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(LucideIcons.mic, size: 18, color: AppColors.textSecondaryLight),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
                DashboardKpiGrid(cards: state.kpiCards),
                const SizedBox(height: 20),

                // Quick Actions
                QuickActionsSection(actions: state.quickActions),
                const SizedBox(height: 20),

                // Recent Activities
                RecentActivitySection(
                  activities: state.recentActivities,
                  isAuthoritative: state.metrics?.isAuthoritative ?? false,
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickDialSheet(context),
        backgroundColor: AppColors.primary,
        tooltip: 'Broker Communication Desk',
        child: const Icon(LucideIcons.phoneCall, color: Colors.white),
      ),
    );
  }
}
