import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/access_denied_screen.dart';
import '../../features/authentication/presentation/controllers/auth_notifier.dart';
export '../../features/authentication/presentation/controllers/auth_notifier.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/splash_screen.dart';
import '../../features/brokers/domain/seller_broker_model.dart';
import '../../features/brokers/presentation/broker_profile_screen.dart';
import '../../features/brokers/presentation/my_brokers_screen.dart';
import '../../features/commodities/domain/commodity_model.dart';
import '../../features/commodities/presentation/commodity_details_screen.dart';
import '../../features/commodities/presentation/my_commodities_screen.dart';
import '../../features/commodities/presentation/post_commodity_screen.dart';
import '../../features/deals/domain/seller_deal_model.dart';
import '../../features/deals/presentation/deal_details_screen.dart';
import '../../features/deals/presentation/seller_deals_screen.dart';
import '../../features/home/presentation/navigation_shell.dart';
import '../../features/home/presentation/seller_home_screen.dart';
import '../../features/invoices/domain/seller_invoice_model.dart';
import '../../features/invoices/presentation/invoice_details_screen.dart';
import '../../features/negotiation/presentation/broker_communication_screen.dart';
import '../../features/notifications/presentation/seller_notifications_screen.dart';
import '../../features/help/presentation/seller_help_support_screen.dart';
import '../../features/profile/presentation/seller_profile_screen.dart';
import '../../features/profile/presentation/seller_settings_screen.dart';
import '../../features/ratings/presentation/rate_broker_screen.dart';
import '../../features/reports/presentation/sales_history_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'sellerRoot',
);

/// Central GoRouter routing configuration for RMSeller Enterprise mobile client.
/// Enforces route guarding based on authoritative server role and session state.
class AppRouter {
  const AppRouter._();

  /// Shared AuthNotifier listening to authentication and role authorization state.
  static final AuthNotifier authNotifier = AuthNotifier();

  /// Reset auth state cleanly (for testing and session termination).
  static void resetForTesting({AuthStatus status = AuthStatus.initial}) {
    authNotifier.setStatus(status);
  }

  /// Centralized route guard logic enforcing authentication and seller role boundary.
  static String? redirectLogic(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final status = authNotifier.status;

    final isSplash = path == '/';
    final isLogin = path == '/login';
    final isAccessDenied = path == '/access-denied';

    switch (status) {
      case AuthStatus.initial:
        if (!isSplash) return '/';
        return null;

      case AuthStatus.unauthenticated:
        if (!isLogin && !isAccessDenied) {
          return '/login';
        }
        return null;

      case AuthStatus.accessDenied:
        if (!isAccessDenied) {
          return '/access-denied';
        }
        return null;

      case AuthStatus.authenticated:
        if (isSplash || isLogin) {
          return '/home';
        }
        return null;
    }
  }

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: redirectLogic,
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
            email: extra['email'] as String? ?? authNotifier.deniedEmail ?? '',
            role:
                extra['role'] as String? ??
                authNotifier.deniedRole ??
                'unauthorized',
            message: extra['message'] as String? ?? authNotifier.deniedMessage,
          );
        },
      ),

      // Post New Commodity Lot Flow (Protected)
      GoRoute(
        path: '/commodities/new',
        name: 'post_commodity',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final commodityId = state.uri.queryParameters['commodityId'];
          final brokerId = state.uri.queryParameters['brokerId'];
          return PostCommodityScreen(
            initialCommodityId: commodityId,
            initialBrokerId: brokerId,
          );
        },
      ),
      GoRoute(
        path: '/commodities/:id',
        name: 'commodity_details',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final commodity = state.extra as SellerCommodity?;
          return CommodityDetailsScreen(
            commodityId: id,
            initialCommodity: commodity,
          );
        },
      ),

      // Broker Profile Route (Protected)
      GoRoute(
        path: '/brokers/:id',
        name: 'broker_profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final broker = state.extra as SellerBrokerModel?;
          return BrokerProfileScreen(brokerId: id, initialBroker: broker);
        },
      ),

      // Rate Broker Desk Route (Protected)
      GoRoute(
        path: '/brokers/:id/rate',
        name: 'rate_broker',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final queryParams = state.uri.queryParameters;
          final brokerName =
              extra['brokerName'] as String? ??
              queryParams['brokerName'] ??
              'Authorized Broker Desk';
          final dealId = extra['dealId'] as String? ?? queryParams['dealId'];
          final dealReference =
              extra['dealReference'] as String? ?? queryParams['dealReference'];
          return RateBrokerScreen(
            brokerId: id,
            brokerName: brokerName,
            dealId: dealId,
            dealReference: dealReference,
          );
        },
      ),

      // Deal Contract Details (Protected)
      GoRoute(
        path: '/deals/:id',
        name: 'deal_details',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final deal = state.extra as SellerDealModel?;
          return DealDetailsScreen(dealId: id, initialDeal: deal);
        },
      ),

      // Invoice Details & Document Viewer (Protected)
      GoRoute(
        path: '/invoices/:id',
        name: 'invoice_details',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final invoice = state.extra as SellerInvoice?;
          return InvoiceDetailsScreen(invoiceId: id, initialInvoice: invoice);
        },
      ),

      // Search (Protected)
      GoRoute(
        path: '/search',
        name: 'search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyBrokersScreen(),
      ),

      // Notifications Center (Protected)
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SellerNotificationsScreen(),
      ),

      // Commodity-Specific Broker Communication & Commission Desk (Protected)
      GoRoute(
        path: '/commodities/:id/negotiate',
        name: 'commodity_negotiate',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final extra = state.extra;
          if (extra is SellerCommodity) {
            return BrokerCommunicationScreen(
              requestId: extra.id,
              brokerId: extra.assignedBrokerId ?? 'BRK-SYSTEM',
              brokerName: extra.assignedBrokerName ?? 'Designated Broker',
              commodityContext:
                  '${extra.name} • ${extra.quantityTotal} ${extra.unit}',
              commodity: extra,
            );
          }
          final queryParams = state.uri.queryParameters;
          return BrokerCommunicationScreen(
            requestId: id,
            brokerId: queryParams['brokerId'] ?? 'BRK-SYSTEM',
            brokerName: queryParams['brokerName'] ?? 'Designated Broker',
            commodityContext:
                queryParams['commodityContext'] ?? 'Commodity Lot $id',
          );
        },
      ),

      // Direct Broker Communication & Commission Desk (Protected)
      GoRoute(
        path: '/communication/broker/:brokerId',
        name: 'broker_communication',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final brokerId = state.pathParameters['brokerId'] ?? '';
          final extra = state.extra;
          if (extra is SellerBrokerModel) {
            return BrokerCommunicationScreen(
              requestId: 'REQ-COMM-$brokerId',
              brokerId: extra.id,
              brokerName: extra.name,
              brokerPhone: extra.phone,
              brokerLocation: extra.location,
              trustScore: extra.trustScore,
              commodityContext: extra.specialtyCommodities.isNotEmpty
                  ? 'Specialties: ${extra.specialtyCommodities.join(", ")}'
                  : 'Commission Desk',
            );
          }
          final queryParams = state.uri.queryParameters;
          return BrokerCommunicationScreen(
            requestId: queryParams['requestId'] ?? 'REQ-COMM-$brokerId',
            brokerId: brokerId,
            brokerName: queryParams['brokerName'] ?? 'Broker $brokerId',
            brokerPhone: queryParams['brokerPhone'],
            brokerLocation: queryParams['brokerLocation'],
            commodityContext:
                queryParams['commodityContext'] ?? 'Direct Negotiation Desk',
          );
        },
      ),

      // Application Settings Route (Protected)
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SellerSettingsScreen(),
      ),

      // Help & Support Route (Protected)
      GoRoute(
        path: '/help',
        name: 'help_support',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SellerHelpSupportScreen(),
      ),

      // Direct Profile Edit Route (Protected)
      GoRoute(
        path: '/profile/edit',
        name: 'edit_profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const SellerProfileScreen(isInitialEdit: true),
      ),

      // Core Stateful Navigation Shell with 6 branches
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const SellerHomeScreen(),
              ),
            ],
          ),
          // Branch 1: My Commodities
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/commodities',
                name: 'commodities',
                builder: (context, state) => const MyCommoditiesScreen(),
              ),
            ],
          ),
          // Branch 2: My Brokers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/brokers',
                name: 'brokers',
                builder: (context, state) => const MyBrokersScreen(),
              ),
            ],
          ),
          // Branch 3: Deals & Documents
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/deals',
                name: 'deals',
                builder: (context, state) => const SellerDealsScreen(),
              ),
            ],
          ),
          // Branch 4: Sales History & Reports
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                name: 'reports',
                builder: (context, state) => const SalesHistoryScreen(),
              ),
            ],
          ),
          // Branch 5: My Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const SellerProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
