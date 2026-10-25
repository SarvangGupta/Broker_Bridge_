import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../../deals/presentation/controllers/deals_controller.dart';

/// Bottom navigation shell wrapping the 5 core broker modules.
class NavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({super.key, required this.navigationShell});

  static final List<GlobalKey<NavigatorState>> _branchKeys = [
    dashboardNavigatorKey,
    workNavigatorKey,
    dealsNavigatorKey,
    directoryNavigatorKey,
    moreNavigatorKey,
  ];

  void _onTap(WidgetRef ref, int index) {
    // Deals tab keeps its state alive; refetch so recorded negotiations show.
    if (index == 2) ref.read(dealsProvider.notifier).loadDeals();
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
    final settings = ref.watch(appSettingsProvider);
    final isIconOnly = settings.iconOnlyMode;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => _onTap(ref, i),
          labelBehavior: isIconOnly
              ? NavigationDestinationLabelBehavior.alwaysHide
              : NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(LucideIcons.home),
              selectedIcon: Icon(LucideIcons.home, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.layers),
              selectedIcon: Icon(LucideIcons.layers, color: AppColors.primary),
              label: 'Work Desk',
            ),
            NavigationDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(
                Icons.handshake_outlined,
                color: AppColors.primary,
              ),
              label: 'Deals',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.users),
              selectedIcon: Icon(LucideIcons.users, color: AppColors.primary),
              label: 'Directory',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.moreHorizontal),
              selectedIcon: Icon(
                LucideIcons.moreHorizontal,
                color: AppColors.primary,
              ),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
