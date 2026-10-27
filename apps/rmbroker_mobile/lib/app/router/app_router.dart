import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../../core/widgets/module_placeholder_screen.dart';
import '../../features/chat/presentation/chat_inbox_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/authentication/presentation/access_denied_screen.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/splash_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/dashboard_section_screens.dart';
import '../../features/dashboard/presentation/navigation_shell.dart';
import '../../features/commission/presentation/screens/earnings_dashboard_screen.dart';
import '../../features/invoices/presentation/screens/invoice_detail_screen.dart';
import '../../features/invoices/presentation/screens/invoice_list_screen.dart';
import '../../features/deals/presentation/deals_screen.dart';
import '../../features/deals/presentation/screens/deal_detail_screen.dart';
import '../../features/directory/presentation/directory_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/more/presentation/more_section_screens.dart';
import '../../features/notifications/presentation/screens/notification_center_screen.dart';
import '../../features/search/domain/search_result.dart';
import '../../features/search/presentation/global_search_screen.dart';
import '../../features/broadcast/presentation/broadcast_detail_screen.dart';
import '../../features/broadcast/presentation/broadcast_history_screen.dart';
import '../../features/broadcast/presentation/market_price_broadcast_screen.dart';
import '../../features/profile/presentation/broker_profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/tasks/presentation/screens/task_detail_screen.dart';
import '../../features/tasks/presentation/screens/task_list_screen.dart';
import '../../features/work/presentation/screens/requirement_detail_screen.dart';
import '../../features/work/presentation/work_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final GlobalKey<NavigatorState> dashboardNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'dashboardNav');
final GlobalKey<NavigatorState> workNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'workNav',
);
final GlobalKey<NavigatorState> dealsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'dealsNav',
);
final GlobalKey<NavigatorState> directoryNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'directoryNav');
final GlobalKey<NavigatorState> moreNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'moreNav',
);

/// Central GoRouter configuration for RMBroker.
class AppRouter {
  const AppRouter._();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Broker Desk'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/work'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.compass,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Unknown location: ${state.uri.path}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/work'),
                icon: const Icon(LucideIcons.layers, size: 16),
                label: const Text('Return to Work Desk'),
              ),
            ],
          ),
        ),
      );
    },
    routes: [
      GoRoute(
        path: '/buyer/requirements',
        redirect: (context, state) => '/work',
      ),
      GoRoute(
        path: '/buyer/requirements/:id',
        redirect: (context, state) => '/requirements/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/access-denied',
        name: 'access_denied',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AccessDeniedScreen(
            email: extra['email'] as String? ?? '',
            role: extra['role'] as String? ?? 'unauthorized',
            message: extra['message'] as String?,
          );
        },
      ),

      // Deal Detail Screen
      GoRoute(
        path: '/deals/:id',
        name: 'deal_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return DealDetailScreen(dealId: id);
        },
      ),

      // Requirement Detail Screen
      GoRoute(
        path: '/requirements/:id',
        name: 'requirement_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return RequirementDetailScreen(requirementId: id);
        },
      ),

      // Global Search Entry Point
      GoRoute(
        path: '/search',
        name: 'search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final query = state.uri.queryParameters['q'];
          final entity = state.uri.queryParameters['entity'];
          return GlobalSearchScreen(
            initialQuery: query,
            initialFilter: entity != null
                ? SearchEntityType.fromString(entity)
                : null,
          );
        },
      ),

      // Roadmap Placeholder Routes (clearly communicates non-operational status)
      GoRoute(
        path: '/orders',
        name: 'orders',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ModulePlaceholderScreen(
          title: 'Logistics & Dispatch Tracking',
          moduleCode: 'RB-LOG-01',
          description: 'Real-time vehicle dispatches, e-way bills, and delivery acknowledgements are scheduled for upcoming micro-sprints per the RMBroker product roadmap.',
          icon: LucideIcons.truck,
        ),
      ),
      GoRoute(
        path: '/commission',
        name: 'commission',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EarningsDashboardScreen(),
      ),
      GoRoute(
        path: '/invoices',
        name: 'invoices',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InvoiceListScreen(),
      ),
      GoRoute(
        path: '/invoices/:id',
        name: 'invoice_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return InvoiceDetailScreen(invoiceId: id);
        },
      ),
      GoRoute(
        path: '/disputes',
        name: 'disputes',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ModulePlaceholderScreen(
          title: 'Arbitration & Dispute Resolution',
          moduleCode: 'RB-DIS-01',
          description: 'Broker-mediated dispute claims, quality deduction arbitration, and settlement records are scheduled for upcoming micro-sprints per the RMBroker product roadmap.',
          icon: LucideIcons.alertTriangle,
        ),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      // Buyer <-> Broker chat (BROKERBRIDGE-CHAT-E2E-01). Brokers reply only;
      // conversations are opened by buyers.
      GoRoute(
        path: '/chats',
        name: 'chat_inbox',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ChatInboxScreen(
          emptyText: 'No buyer conversations yet. Buyers can message you from your profile.',
        ),
      ),
      GoRoute(
        path: '/chats/:id',
        name: 'chat_conversation',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['id'],
          emptyHint: 'Reply to the buyer about their requirement, pricing or dispatch. '
              'Seller identities stay protected.',
        ),
      ),
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TaskListScreen(),
      ),
      GoRoute(
        path: '/tasks/:id',
        name: 'task_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return TaskDetailScreen(taskId: id);
        },
      ),

      // Application Settings Route (Protected)
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),

      // Broker Profile Route (Protected)
      GoRoute(
        path: '/profile',
        name: 'profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BrokerProfileScreen(),
      ),

      // Market Price Broadcast Route (Protected)
      GoRoute(
        path: '/broadcast/market-price',
        name: 'market_price_broadcast',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MarketPriceBroadcastScreen(),
      ),

      // Broadcast Price History Routes (Protected)
      GoRoute(
        path: '/broadcast/history',
        name: 'broadcast_history',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BroadcastHistoryScreen(),
      ),
      GoRoute(
        path: '/broadcast/history/:id',
        name: 'broadcast_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BroadcastDetailScreen(broadcastId: id);
        },
      ),

      // Core Broker Shell with Persistent Bottom Navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
                // Home shortcut destinations stay in the Home branch.
                routes: [
                  GoRoute(
                    path: 'summary',
                    name: 'dashboard_summary',
                    builder: (context, state) => const DashboardSummaryScreen(),
                  ),
                  GoRoute(
                    path: 'actions',
                    name: 'dashboard_actions',
                    builder: (context, state) => const DashboardActionsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: workNavigatorKey,
            routes: [
              GoRoute(
                path: '/work',
                name: 'work',
                builder: (context, state) {
                  final tabStr = state.uri.queryParameters['tab'];
                  final tab = int.tryParse(tabStr ?? '0') ?? 0;
                  final status = state.uri.queryParameters['status'];
                  final reqId =
                      state.uri.queryParameters['requirementId'] ??
                      state.uri.queryParameters['reqId'];
                  final offerId =
                      state.uri.queryParameters['offerId'] ??
                      state.uri.queryParameters['availabilityId'];
                  return WorkScreen(
                    initialTabIndex: tab,
                    initialStatusFilter: status,
                    initialRequirementId: reqId,
                    initialOfferId: offerId,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: dealsNavigatorKey,
            routes: [
              GoRoute(
                path: '/deals',
                name: 'deals',
                builder: (context, state) {
                  final filter = state.uri.queryParameters['filter'];
                  return DealsScreen(initialFilter: filter);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: directoryNavigatorKey,
            routes: [
              GoRoute(
                path: '/directory',
                name: 'directory',
                builder: (context, state) => const DirectoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: moreNavigatorKey,
            routes: [
              GoRoute(
                path: '/more',
                name: 'more',
                builder: (context, state) => const MoreScreen(),
                // Section pages stay in the More branch (bottom bar visible, More
                // selected); their items open the existing full-screen routes.
                routes: [
                  GoRoute(
                    path: 'tools',
                    name: 'more_tools',
                    builder: (context, state) => const ToolsMenuScreen(),
                  ),
                  GoRoute(
                    path: 'finance',
                    name: 'more_finance',
                    builder: (context, state) => const FinanceMenuScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: 'more_settings',
                    builder: (context, state) => const SettingsMenuScreen(),
                    routes: [
                      GoRoute(
                        path: ':group',
                        name: 'more_settings_group',
                        builder: (context, state) {
                          final group = PreferenceGroupScreen.fromSlug(state.pathParameters['group']);
                          return group == null
                              ? const SettingsMenuScreen()
                              : PreferenceGroupScreen(group: group);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
