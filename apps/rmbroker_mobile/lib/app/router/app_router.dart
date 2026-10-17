import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/widgets/module_placeholder_screen.dart';
import '../../features/authentication/presentation/access_denied_screen.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/splash_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/navigation_shell.dart';
import '../../features/deals/presentation/deals_screen.dart';
import '../../features/deals/presentation/screens/deal_detail_screen.dart';
import '../../features/directory/presentation/directory_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/search/domain/search_result.dart';
import '../../features/search/presentation/global_search_screen.dart';
import '../../features/work/presentation/work_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Central GoRouter configuration for RMBroker.
class AppRouter {
  const AppRouter._();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
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
            initialFilter: entity != null ? SearchEntityType.fromString(entity) : null,
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
          description:
              'Real-time vehicle dispatches, e-way bills, and delivery acknowledgements are scheduled for upcoming micro-sprints per the RMBroker product roadmap.',
          icon: LucideIcons.truck,
        ),
      ),
      GoRoute(
        path: '/commission',
        name: 'commission',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ModulePlaceholderScreen(
          title: 'Brokerage & Commission Ledger',
          moduleCode: 'RB-FIN-01',
          description:
              'Volume-based brokerage settlement calculations, GST invoices, and payout ledgers are scheduled for upcoming micro-sprints per the RMBroker product roadmap.',
          icon: LucideIcons.indianRupee,
        ),
      ),
      GoRoute(
        path: '/disputes',
        name: 'disputes',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ModulePlaceholderScreen(
          title: 'Arbitration & Dispute Resolution',
          moduleCode: 'RB-DIS-01',
          description:
              'Broker-mediated dispute claims, quality deduction arbitration, and settlement records are scheduled for upcoming micro-sprints per the RMBroker product roadmap.',
          icon: LucideIcons.alertTriangle,
        ),
      ),

      // Core Broker Shell with Persistent Bottom Navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/work',
                name: 'work',
                builder: (context, state) {
                  final tabStr = state.uri.queryParameters['tab'];
                  final tab = int.tryParse(tabStr ?? '0') ?? 0;
                  return WorkScreen(initialTabIndex: tab);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/deals',
                name: 'deals',
                builder: (context, state) => const DealsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/directory',
                name: 'directory',
                builder: (context, state) => const DirectoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                name: 'more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
