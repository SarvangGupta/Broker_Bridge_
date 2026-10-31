import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../deals/presentation/controllers/deals_controller.dart';
import 'widgets/glass_ball_navigation_bar.dart';

/// Bottom navigation shell wrapping the 5 core broker modules with
/// the premium glass-ball bottom navigation.
class NavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({super.key, required this.navigationShell});

  static final List<GlobalKey<NavigatorState>> _branchKeys = [
    dashboardNavigatorKey, // 0: Home
    workNavigatorKey,      // 1: Work Desk
    directoryNavigatorKey, // 2: Directory (Centre)
    dealsNavigatorKey,     // 3: Deals (Right of Directory)
    moreNavigatorKey,      // 4: More
  ];

  void _onTap(WidgetRef ref, int index) {
    // Deals tab keeps its state alive; refetch so recorded negotiations show.
    if (index == 3) ref.read(dealsProvider.notifier).loadDeals();
    if (index != navigationShell.currentIndex) {
      final currentIdx = navigationShell.currentIndex;
      if (currentIdx >= 0 && currentIdx < _branchKeys.length) {
        final currentBranchKey = _branchKeys[currentIdx];
        if (currentBranchKey.currentState?.canPop() == true) {
          currentBranchKey.currentState?.popUntil((route) => route.isFirst);
        }
      }
      if (rootNavigatorKey.currentState?.canPop() == true) {
        rootNavigatorKey.currentState?.pop();
      }
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: GlassBallNavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => _onTap(ref, i),
      ),
    );
  }
}
