import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/access_denied_screen.dart';
import '../../features/authentication/presentation/controllers/auth_notifier.dart';
export '../../features/authentication/presentation/controllers/auth_notifier.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/splash_screen.dart';
import '../../features/deals/presentation/buyer_deals_screen.dart';
import '../../features/deals/presentation/final_deal_review_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/more_screen.dart';
import '../../features/home/presentation/navigation_shell.dart';
import '../../features/notifications/presentation/buyer_notifications_screen.dart';
import '../../features/nutrition/presentation/nutrition_guide_screen.dart';
import '../../features/offers/domain/buyer_offer_model.dart';
import '../../features/offers/presentation/buyer_offers_screen.dart';
import '../../features/offers/presentation/offer_details_screen.dart';
import '../../features/profile/presentation/buyer_profile_screen.dart';
import '../../features/profile/presentation/display_settings_screen.dart';
import '../../features/profile/presentation/language_settings_screen.dart';
import '../../features/profile/presentation/profile_settings_screen.dart';
import '../../features/requirements/domain/requirement_model.dart';
import '../../features/requirements/presentation/post_requirement_screen.dart';
import '../../features/requirements/presentation/requirement_details_screen.dart';
import '../../features/requirements/presentation/requirements_screen.dart';
import '../../features/search/domain/broker_model.dart';
import '../../features/search/presentation/broker_profile_screen.dart';
import '../../features/search/presentation/brokers_screen.dart';
import '../../features/search/presentation/buyer_search_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'buyerRoot',
);

/// Central GoRouter routing configuration for RMBuyer Enterprise mobile client.
/// Enforces route guarding based on authoritative server role and session state.
class AppRouter {
  const AppRouter._();

  /// Shared AuthNotifier listening to authentication and role authorization state.
  static final AuthNotifier authNotifier = AuthNotifier();

  /// Reset auth state cleanly (for testing and session termination).
  static void resetForTesting({AuthStatus status = AuthStatus.initial}) {
    authNotifier.setStatus(status);
  }

  /// Centralized route guard logic enforcing authentication and buyer role boundary.
  static String? redirectLogic(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final status = authNotifier.status;

    final isSplash = path == '/';
    final isLogin = path == '/login';
    final isAccessDenied = path == '/access-denied';

    switch (status) {
      case AuthStatus.initial:
        // Prevent protected screens from flashing before authorization is resolved
        if (!isSplash) return '/';
        return null;

      case AuthStatus.unauthenticated:
        // Unauthenticated or expired: redirect any protected screen to login
        if (!isLogin && !isAccessDenied) {
          return '/login';
        }
        return null;

      case AuthStatus.accessDenied:
        // Authenticated user with unauthorized role: redirect to access-denied screen
        if (!isAccessDenied) {
          return '/access-denied';
        }
        return null;

      case AuthStatus.authenticated:
        // Authorized buyer/admin: redirect away from splash or login directly to home
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

      // Global Search (Protected)
      GoRoute(
        path: '/search',
        name: 'search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final query = state.uri.queryParameters['q'];
          return BuyerSearchScreen(initialQuery: query);
        },
      ),

      // Notifications Center (Protected)
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BuyerNotificationsScreen(),
      ),

      // Post New Requirement Flow (Protected)
      GoRoute(
        path: '/requirements/new',
        name: 'post_requirement',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final commodity = state.uri.queryParameters['commodity'];
          final brokerId = state.uri.queryParameters['brokerId'];
          final brokerName = state.uri.queryParameters['brokerName'];
          final extra = state.extra as Map<String, dynamic>?;
          return PostRequirementScreen(
            initialCommodity: commodity ?? extra?['commodity'] as String?,
            initialBrokerId: brokerId ?? extra?['brokerId'] as String?,
            initialBrokerName: brokerName ?? extra?['brokerName'] as String?,
            blankCommercialTerms: extra?['blankCommercialTerms'] == true,
          );
        },
      ),
      GoRoute(
        path: '/requirements/:id',
        name: 'requirement_details',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final requirement = state.extra as BuyerRequirement?;
          return RequirementDetailsScreen(
            requirementId: id,
            initialRequirement: requirement,
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
          final broker = state.extra as BrokerModel?;
          return BrokerProfileScreen(brokerId: id, initialBroker: broker);
        },
      ),
      // Broker Offers & Negotiation (Protected)
      GoRoute(
        path: '/offers',
        name: 'offers',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final reqId = state.uri.queryParameters['requirementId'];
          return BuyerOffersScreen(initialRequirementId: reqId);
        },
      ),
      GoRoute(
        path: '/offers/:id',
        name: 'offer_details',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final offer = state.extra as BuyerOffer?;
          return OfferDetailsScreen(offerId: id, initialOffer: offer);
        },
      ),

      // Final Deal Review & Explicit Confirmation (Protected)
      GoRoute(
        path: '/deals/:id',
        name: 'deal_details',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return FinalDealReviewScreen(dealId: id);
        },
      ),
      GoRoute(
        path: '/deals/:id/confirm',
        name: 'deal_confirm',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return FinalDealReviewScreen(dealId: id);
        },
      ),

      // Profile & Settings hub and its pages (Protected)
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ProfileSettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            name: 'edit_profile',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const BuyerProfileScreen(),
          ),
          GoRoute(
            path: 'language',
            name: 'language_settings',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const LanguageSettingsScreen(),
          ),
          GoRoute(
            path: 'display',
            name: 'display_settings',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const DisplaySettingsScreen(),
          ),
        ],
      ),

      // Core Stateful Buyer Shell with Persistent Bottom Navigation (Protected)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/requirements',
                name: 'requirements',
                builder: (context, state) => const RequirementsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/brokers',
                name: 'brokers',
                builder: (context, state) => const BrokersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/deals',
                name: 'deals',
                builder: (context, state) => const BuyerDealsScreen(),
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

      // Secondary destinations reached from the More tab (Protected)
      GoRoute(
        path: '/nutrition',
        name: 'nutrition',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NutritionGuideScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ProfileSettingsScreen(),
      ),
    ],
  );
}
