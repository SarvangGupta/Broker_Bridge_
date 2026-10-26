import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../domain/dashboard_state.dart';
import 'controllers/dashboard_controller.dart';
import '../../../core/config/app_config.dart';
import 'widgets/broker_welcome_banner.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/home_add_sheet.dart';
import 'widgets/home_market_section.dart';
import 'widgets/home_shortcuts_row.dart';

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
                const SizedBox(height: 12),
              ] else ...[
                // Summary · Actions · Recent Activity (full views open on tap)
                HomeShortcutsRow(state: state),
                const SizedBox(height: 14),
              ],

              // Buyer Requirements / Seller Offers (Work Desk data)
              const HomeMarketSection(),
              const SizedBox(height: 12),

              // Statutory fiduciary notice, kept at the end of Home.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.shieldAlert, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppConfig.fiduciaryNoticeEn,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Clear of the "+" FAB above the bottom navigation.
              const SizedBox(height: 96),
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
