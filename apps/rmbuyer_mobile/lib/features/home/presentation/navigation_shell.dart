import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Navigation shell hosting the persistent bottom navigation bar for RMBuyer.
class NavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        backgroundColor: AppColors.surfaceLight,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.home),
            label: context.tr(Tr.navHome),
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.clipboardList),
            label: context.tr(Tr.navRequirements),
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.handshake),
            label: context.tr(Tr.navDeals),
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.leaf),
            label: context.tr(Tr.navNutrition),
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.user),
            label: context.tr(Tr.navProfile),
          ),
        ],
      ),
    );
  }
}
